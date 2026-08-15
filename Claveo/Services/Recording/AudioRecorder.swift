//
//  AudioRecorder.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import ActivityKit
import AVFoundation
import Foundation
import Combine
import UIKit

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorder()

    @Published var isRecording = false
    @Published var recordings: [Recording] = []
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var waveformLevels: [Float] = []
    @Published var permissionError: String?
    @Published var recordingError: String?
    @Published var newlyCreatedRecordingId: UUID?
    @Published private(set) var isLoadingRecordings = false

    private var hasLoadedFromDisk = false
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var currentRecordingURL: URL?
    private var recordingStartedAt: Date?
    private var pendingFinalizationURL: URL?
    private var pendingFinalizationDuration: TimeInterval = 0
    private var pendingStorageLocation: RecordingStorageLocation?
    private var deletionTombstones: [UUID: Recording] = [:]
    private var mutationRevision = 0
    private var reloadGeneration = 0
    private let maxWaveformLevels = 140
    private var waveformPublishTick = 0
    private var sessionObservers: [NSObjectProtocol] = []
    
    override init() {
        super.init()
        loadRecordingsFromCache()
        installSessionObservers()

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshRecordingProgressFromFile()
                await self?.reloadRecordingsFromDisk(force: true)
            }
        }
    }

    /// Loads metadata from iCloud/local after `iCloudManager.warmUpIfNeeded()`.
    func reloadRecordingsFromDisk(force: Bool = false) async {
        if hasLoadedFromDisk && !force {
            return
        }

        reloadGeneration += 1
        let generation = reloadGeneration
        let revisionAtStart = mutationRevision
        let showLoading = recordings.isEmpty
        if showLoading { isLoadingRecordings = true }
        defer {
            if generation == reloadGeneration {
                if showLoading { isLoadingRecordings = false }
                hasLoadedFromDisk = true
            }
        }

        await iCloudManager.shared.warmUpIfNeeded()

        let fileURLs = iCloudManager.shared.knownStorageRoots().values.map {
            $0.appendingPathComponent("recordings.json")
        }

        let loadedResult = await Task.detached(priority: .utility) {
            Self.readRecordingsFiles(at: fileURLs)
        }.value

        guard generation == reloadGeneration else { return }

        let loaded = loadedResult.recordings
        let inMemory = recordings + Array(deletionTombstones.values)
        let previousActive = recordings
        let previousTombstones = deletionTombstones
        let merged = Self.mergeRecordings(inMemory, with: loaded)
        deletionTombstones = Dictionary(
            uniqueKeysWithValues: merged.filter(\.isDeleted).map { ($0.id, $0) }
        )
        let active = merged.filter { !$0.isDeleted }
        recordings = pinStorageLocations(in: active)
        refreshKeepDownloadedFiles()
        let metadataChanged =
            mutationRevision != revisionAtStart
            || recordings != previousActive
            || deletionTombstones != previousTombstones
        if mutationRevision == revisionAtStart, recordings != previousActive {
            mutationRevision += 1
        }
        // Never persist over incomplete cloud reads — that can wipe richer remote metadata.
        if metadataChanged, loadedResult.readSucceeded {
            _ = saveRecordings()
        }
    }

    func refreshRecordings() async {
        await reloadRecordingsFromDisk(force: true)
    }
    
    private func installSessionObservers() {
        let center = NotificationCenter.default

        sessionObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                let userInfo = notification.userInfo
                Task { @MainActor [weak self] in
                    self?.handleAudioSessionInterruption(userInfo: userInfo)
                }
            }
        )

        sessionObservers.append(
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleMediaServicesReset()
                }
            }
        )

        sessionObservers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.maintainRecordingSessionInBackground()
                }
            }
        )
    }

    /// Keeps the recorder alive when the screen locks or the app is backgrounded (requires `audio` background mode).
    private func maintainRecordingSessionInBackground() {
        guard isRecording else { return }
        do {
            try activateRecordingAudioSession()
        } catch {
            #if DEBUG
            print("Failed to keep recording session active in background: \(error)")
            #endif
        }
        refreshRecordingProgressFromFile()
    }

    private func handleAudioSessionInterruption(userInfo: [AnyHashable: Any]?) {
        guard let userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            refreshRecordingProgressFromFile()
            if isRecording {
                RecordingLiveActivityManager.shared.pauseRecordingActivity(elapsed: recordingTime)
            }
        case .ended:
            guard isRecording else { return }
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                do {
                    try activateRecordingAudioSession()
                    if audioRecorder?.isRecording != true {
                        guard audioRecorder?.record() == true else {
                            forceStopRecordingAfterCaptureLoss()
                            return
                        }
                    }
                    refreshRecordingProgressFromFile()
                    RecordingLiveActivityManager.shared.resumeRecordingActivity(elapsed: recordingTime)
                } catch {
                    forceStopRecordingAfterCaptureLoss()
                }
            } else if audioRecorder?.isRecording != true {
                forceStopRecordingAfterCaptureLoss()
            }
        @unknown default:
            break
        }
    }

    private func handleMediaServicesReset() {
        guard isRecording else { return }
        recordingError = String(localized: "Audio was interrupted by the system. Please start a new recording.")
        forceStopRecordingAfterCaptureLoss()
    }

    /// Ends a live recording UI/session when capture is no longer active and cannot be resumed.
    private func forceStopRecordingAfterCaptureLoss() {
        let url = currentRecordingURL
        let elapsed = audioRecorder?.currentTime ?? recordingTime
        pendingFinalizationURL = url
        pendingFinalizationDuration = elapsed

        audioRecorder?.stop()
        isRecording = false
        RecordingLiveActivityManager.shared.endRecordingActivity(finalDuration: elapsed)

        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0.0
        waveformLevels = []
        recordingStartedAt = nil
        recordingTime = 0
    }

    private func activateRecordingAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true, options: [])
    }

    private func refreshRecordingProgressFromFile() {
        guard isRecording, let recorder = audioRecorder else { return }
        recordingTime = recorder.currentTime
    }

    deinit {
        for observer in sessionObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func checkPermissionStatus() -> Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            // Use AVAudioSession API for older iOS versions
            let status = AVAudioSession.sharedInstance().recordPermission
            return status == .granted
        }
    }
    
    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func startRecording() async {
        guard !isRecording else { return }
        
        // Clear any previous errors
        permissionError = nil
        recordingError = nil
        
        // Check current permission status
        let hasPermission = checkPermissionStatus()
        
        if !hasPermission {
            // Request permission if not granted
            let granted = await requestPermission()
            if !granted {
                permissionError = String(localized: "Microphone access is required to record audio. Please enable it in Settings.")
                return
            }
        }
        
        do {
            try activateRecordingAudioSession()
        } catch {
            permissionError = String(localized: "Failed to setup audio session: \(error.localizedDescription)")
            return
        }
        
        let fileName = "recording_\(UUID().uuidString).m4a"
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent(fileName)
        let storageLocation = iCloudManager.shared.activeStorageLocation
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            guard let recorder = audioRecorder else {
                permissionError = String(localized: "Failed to create audio recorder.")
                return
            }
            
            // Prepare the recorder before starting
            guard recorder.prepareToRecord() else {
                permissionError = String(localized: "Failed to prepare recorder. Check microphone availability.")
                audioRecorder = nil
                #if DEBUG
                print("ERROR: prepareToRecord() returned false")
                #endif
                return
            }
            
            // Start recording
            guard recorder.record() else {
                permissionError = String(localized: "Failed to start recording. Please check your microphone settings.")
                audioRecorder?.stop()
                audioRecorder = nil
                #if DEBUG
                print("ERROR: record() returned false")
                print("Recorder isRecording: \(recorder.isRecording)")
                #endif
                return
            }
            
            #if DEBUG
            print("Recording started successfully at: \(fileURL)")
            #endif
            
            // Haptic feedback for recording start
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            isRecording = true
            currentRecordingURL = fileURL
            pendingStorageLocation = storageLocation
            recordingStartedAt = Date()
            recordingTime = 0
            waveformLevels = [] // Reset waveform buffer
            if let recordingStartedAt {
                RecordingLiveActivityManager.shared.startRecordingActivity(startedAt: recordingStartedAt)
            }
            
            let recorderRef = audioRecorder
            // Single timer on .common so it keeps firing while scrolling (default-mode timers pause in .tracking).
            // Duration comes from recorder.currentTime + file duration on stop, not fixed 0.1s increments.
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                recorderRef?.updateMeters()
                let elapsed = recorderRef?.currentTime ?? 0
                let averageDB = recorderRef?.averagePower(forChannel: 0)
                let peakDB = recorderRef?.peakPower(forChannel: 0)
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.recordingTime = elapsed
                    guard let averageDB, let peakDB else { return }
                    let normalizedLevel = Self.normalizedMeterLevel(averageDB: averageDB, peakDB: peakDB)
                    self.audioLevel = max(0, min(1, normalizedLevel))
                    self.waveformPublishTick += 1
                    guard self.waveformPublishTick.isMultiple(of: 2) else { return }
                    self.waveformLevels.append(self.audioLevel)
                    if self.waveformLevels.count > self.maxWaveformLevels {
                        self.waveformLevels.removeFirst()
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            levelTimer = timer
        } catch {
            permissionError = String(localized: "Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Haptic feedback for recording stop
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        let url = currentRecordingURL
        let elapsedBeforeStop = audioRecorder?.currentTime ?? recordingTime
        pendingFinalizationURL = url
        pendingFinalizationDuration = elapsedBeforeStop

        audioRecorder?.stop()
        isRecording = false
        RecordingLiveActivityManager.shared.endRecordingActivity(finalDuration: elapsedBeforeStop)

        levelTimer?.invalidate()
        levelTimer = nil

        audioLevel = 0.0
        waveformLevels = [] // Clear waveform buffer

        recordingStartedAt = nil
        recordingTime = 0
    }

    private func finalizeRecording(successfully: Bool) {
        let url = pendingFinalizationURL ?? currentRecordingURL
        let elapsed = pendingFinalizationDuration
        defer {
            pendingFinalizationURL = nil
            pendingFinalizationDuration = 0
            pendingStorageLocation = nil
            currentRecordingURL = nil
            audioRecorder = nil
        }

        guard successfully else {
            recordingError = String(localized: "The recording could not be finalized. Attempting recovery…")
            if let url, Self.isNonemptyFile(at: url) {
                importOrphanRecording(at: url, fallbackDuration: elapsed, storageLocation: pendingStorageLocation)
            }
            return
        }
        guard let url, Self.isNonemptyFile(at: url) else {
            recordingError = String(localized: "The recording finished, but its audio file could not be saved.")
            return
        }

        let now = Date()
        let recording = Recording(
            fileName: url.lastPathComponent,
            createdAt: now,
            duration: Self.durationFromAudioFile(at: url) ?? elapsed,
            notes: "",
            lastModified: now,
            storageLocation: pendingStorageLocation
        )
        recordings.append(recording)
        mutationRevision += 1
        newlyCreatedRecordingId = recording.id
        if !saveRecordings() {
            recordingError = String(localized: "The recording was created, but its details could not be saved. The audio file was kept.")
        }
    }

    private func importOrphanRecording(
        at url: URL,
        fallbackDuration: TimeInterval,
        storageLocation: RecordingStorageLocation?
    ) {
        let now = Date()
        let recording = Recording(
            fileName: url.lastPathComponent,
            createdAt: now,
            duration: Self.durationFromAudioFile(at: url) ?? max(fallbackDuration, 0),
            notes: "",
            lastModified: now,
            storageLocation: storageLocation
        )
        recordings.append(recording)
        mutationRevision += 1
        newlyCreatedRecordingId = recording.id
        if !saveRecordings() {
            recordingError = String(localized: "Recovered the audio file, but its details could not be saved.")
        } else {
            recordingError = String(localized: "The recording was recovered and added to your library.")
        }
    }

    /// Prefer encoded file length so metadata matches playback after stop (AAC finalize).
    private static func durationFromAudioFile(at url: URL) -> TimeInterval? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let player = try? AVAudioPlayer(contentsOf: url) {
            let d = player.duration
            if d.isFinite, d > 0 { return d }
        }
        return nil
    }

    private static func isNonemptyFile(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return false
        }
        return size.intValue > 0
    }

    func updateRecording(_ recording: Recording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            let previous = recordings[index]
            var updated = recording
            if let previousBackupName = previous.originalFileName,
               let replacementBackupName = updated.originalFileName,
               replacementBackupName != previousBackupName {
                if let replacementBackupURL = updated.originalFileURL {
                    try? RecordingTrimmer.deleteBackup(at: replacementBackupURL)
                }
                updated.originalFileName = previousBackupName
                updated.originalDuration = previous.originalDuration
            } else if previous.originalFileName != nil && updated.originalFileName == nil,
                      let previousBackupURL = previous.originalFileURL {
                try? RecordingTrimmer.deleteBackup(at: previousBackupURL)
            }
            updated.lastModified = Date()
            recordings[index] = updated
            mutationRevision += 1
            _ = saveRecordings()
        }
    }
    
    func deleteRecording(_ recording: Recording) {
        var deletionErrors: [Error] = []
        for url in [recording.fileURL, recording.originalFileURL].compactMap({ $0 }) {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                deletionErrors.append(error)
            }
        }
        recordings.removeAll { $0.id == recording.id }
        var tombstone = recording
        tombstone.isDeleted = true
        tombstone.lastModified = Date()
        deletionTombstones[recording.id] = tombstone
        mutationRevision += 1
        PracticeService.shared.removeRecordingReferences(to: recording.id)
        if !saveRecordings() || !deletionErrors.isEmpty {
            recordingError = String(localized: "The recording was removed from the list, but some associated files could not be deleted.")
        }
    }
    
    @discardableResult
    func saveRecordings() -> Bool {
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(
                recordings + Array(deletionTombstones.values)
            )
        } catch {
            recordingError = String(localized: "Recording details could not be encoded for saving.")
            return false
        }
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("recordings.json")
        
        // Save to local cache first (UserDefaults) for offline access
        UserDefaults.standard.set(encoded, forKey: "recordings_cache")
        
        // Then save to iCloud (will queue if offline)
        do {
            try iCloudManager.shared.writeFile(data: encoded, to: fileURL)
            return true
        } catch {
            #if DEBUG
            print("Failed to save recordings to iCloud: \(error.localizedDescription)")
            #endif
            do {
                try encoded.write(to: fileURL, options: [.atomic])
                return true
            } catch {
                recordingError = String(localized: "Recording details could not be saved: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    private func loadRecordingsFromCache() {
        guard let cachedData = UserDefaults.standard.data(forKey: "recordings_cache"),
              let decoded = try? JSONDecoder().decode([Recording].self, from: cachedData) else {
            return
        }
        deletionTombstones = Dictionary(
            uniqueKeysWithValues: decoded.filter(\.isDeleted).map { ($0.id, $0) }
        )
        recordings = decoded
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private struct RecordingsReadResult: Sendable {
        let recordings: [Recording]
        /// False when an existing root file could not be read/decoded (partial/not-downloaded iCloud).
        let readSucceeded: Bool
    }

    private nonisolated static func readRecordingsFiles(at fileURLs: [URL]) -> RecordingsReadResult {
        var loaded: [Recording] = []
        var readSucceeded = true

        for fileURL in fileURLs {
            let exists = FileManager.default.fileExists(atPath: fileURL.path)
            if !exists {
                continue
            }

            // Not-yet-downloaded ubiquitous items look present but are incomplete placeholders.
            if let values = try? fileURL.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .isUbiquitousItemKey
            ]),
               values.isUbiquitousItem == true,
               values.ubiquitousItemDownloadingStatus == .notDownloaded {
                try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                readSucceeded = false
                continue
            }

            do {
                let data = try iCloudManager.shared.readFile(from: fileURL)
                let decoded = try JSONDecoder().decode([Recording].self, from: data)
                loaded = mergeRecordings(loaded, with: decoded)
            } catch {
                readSucceeded = false
            }
        }

        if let cachedData = UserDefaults.standard.data(forKey: "recordings_cache"),
           let decoded = try? JSONDecoder().decode([Recording].self, from: cachedData) {
            loaded = mergeRecordings(loaded, with: decoded)
        }

        return RecordingsReadResult(recordings: loaded, readSucceeded: readSucceeded)
    }

    nonisolated static func mergeRecordings(
        _ first: [Recording],
        with second: [Recording]
    ) -> [Recording] {
        var merged: [UUID: Recording] = [:]
        for recording in first + second {
            guard let existing = merged[recording.id] else {
                merged[recording.id] = recording
                continue
            }
            if recording.lastModified > existing.lastModified ||
                (recording.lastModified == existing.lastModified &&
                 conflictResolutionKey(for: recording) > conflictResolutionKey(for: existing)) {
                merged[recording.id] = recording
            }
        }
        return merged.values.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private nonisolated static func conflictResolutionKey(for recording: Recording) -> String {
        [
            recording.storageLocation?.rawValue ?? "",
            recording.fileName,
            recording.name,
            recording.piece ?? "",
            recording.tags.sorted().joined(separator: "\u{1F}"),
            recording.notes,
            String(recording.duration),
            String(recording.measureStart ?? 0),
            String(recording.measureEnd ?? 0),
            recording.originalFileName ?? "",
            String(recording.originalDuration ?? 0),
            recording.isDeleted ? "1" : "0",
            recording.keepDownloaded ? "1" : "0"
        ].joined(separator: "\u{1E}")
    }

    private func refreshKeepDownloadedFiles() {
        for recording in recordings where recording.keepDownloaded && recording.isStoredIniCloud {
            try? iCloudManager.shared.startKeepingDownloaded(at: recording.fileURL)
        }
    }

    private func pinStorageLocations(in values: [Recording]) -> [Recording] {
        values.map { recording in
            guard let location = iCloudManager.shared.storageLocation(
                containing: recording.fileName,
                preferred: recording.storageLocation
            ), location != recording.storageLocation else {
                return recording
            }
            var pinned = recording
            pinned.storageLocation = location
            return pinned
        }
    }

    private nonisolated static func normalizedMeterLevel(averageDB: Float, peakDB: Float) -> Float {
        let average = max(-80, min(0, averageDB))
        let peak = max(-80, min(0, peakDB))
        let meterDB = max(average, peak - 8)

        // Fixed dB range so silence stays near zero instead of scaling to the window peak.
        let silenceDB: Float = -55
        let loudDB: Float = -8
        let normalized = (meterDB - silenceDB) / (loudDB - silenceDB)
        return max(0, min(1, normalized))
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let recorderURL = recorder.url
        let recorderDuration = recorder.currentTime
        Task { @MainActor in
            if isRecording {
                isRecording = false
                RecordingLiveActivityManager.shared.endRecordingActivity(finalDuration: recordingTime, dismissalPolicy: .immediate)
                levelTimer?.invalidate()
                levelTimer = nil
                audioLevel = 0.0
                waveformLevels = []
            }
            if pendingFinalizationURL == nil {
                pendingFinalizationURL = recorderURL
                pendingFinalizationDuration = recorderDuration
            }
            finalizeRecording(successfully: flag)
        }
    }
}

