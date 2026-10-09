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
    @Published var permissionError: String?
    @Published var recordingError: String?
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var newlyCreatedRecordingId: UUID?
    @Published private(set) var isLoadingRecordings = false
    @Published private(set) var currentInputName = ""
    let meter = RecordingMeter()

    var recordingTime: TimeInterval {
        get { meter.recordingTime }
        set { meter.recordingTime = newValue }
    }

    var audioLevel: Float {
        get { meter.audioLevel }
        set { meter.audioLevel = newValue }
    }

    var waveformLevels: [Float] {
        get { meter.waveformLevels }
        set { meter.waveformLevels = newValue }
    }

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
    private var metadataSaveTask: Task<Void, Never>?
    
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
        let knownAvailability = Dictionary(
            uniqueKeysWithValues: previousActive.map { ($0.id, $0.isLocallyAvailable) }
        )
        recordings = active.map { recording in
            guard let known = knownAvailability[recording.id], known != recording.isLocallyAvailable else {
                return recording
            }
            var kept = recording
            kept.isLocallyAvailable = known
            return kept
        }
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
                let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
                Task { @MainActor [weak self] in
                    self?.handleAudioSessionInterruption(typeValue: typeValue, optionsValue: optionsValue)
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
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                Task { @MainActor [weak self] in
                    self?.handleRouteChange(reasonValue: reasonValue)
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

    private func handleAudioSessionInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard let typeValue,
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
            let optionsValue = optionsValue ?? 0
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

    private func handleRouteChange(reasonValue: UInt?) {
        refreshCurrentInputName()
        guard isRecording else { return }
        applyStereoCaptureIfNeeded()
        if reasonValue == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
            refreshRecordingProgressFromFile()
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
        meter.reset()
        recordingStartedAt = nil
    }

    private func activateRecordingAudioSession() throws {
        let preferences = SettingsManager.shared.settings
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothA2DP]
        if preferences.allowBluetoothHeadsetMic {
            options.insert(.allowBluetoothHFP)
        }

        let wantsStereo = preferences.recordingMicMode == .stereo
        try session.setCategory(
            .playAndRecord,
            mode: wantsStereo ? .default : .measurement,
            options: options
        )
        try session.setPreferredSampleRate(48_000)
        try session.setActive(true, options: [])

        let captureMode = resolvedMicMode(requested: preferences.recordingMicMode, session: session)
        if wantsStereo && captureMode == .natural {
            try session.setCategory(.playAndRecord, mode: .measurement, options: options)
            try session.setActive(true, options: [])
        }

        try? session.setPreferredInputNumberOfChannels(captureMode.channelCount)
        if captureMode == .stereo {
            applyStereoCaptureIfNeeded()
        }
        refreshCurrentInputName()
    }

    private func resolvedMicMode(
        requested: RecordingMicMode,
        session: AVAudioSession
    ) -> RecordingMicMode {
        guard requested == .stereo, sessionSupportsStereo(session) else { return .natural }
        return .stereo
    }

    private func sessionSupportsStereo(_ session: AVAudioSession) -> Bool {
        let inputs = session.availableInputs ?? []
        return inputs.contains { port in
            port.dataSources?.contains { source in
                source.supportedPolarPatterns?.contains(.stereo) == true
            } == true
        }
    }

    private func applyStereoCaptureIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        guard resolvedMicMode(requested: SettingsManager.shared.settings.recordingMicMode, session: session) == .stereo else {
            return
        }
        if let input = session.preferredInput ?? session.availableInputs?.first,
           let dataSource = input.selectedDataSource ?? input.dataSources?.first,
           dataSource.supportedPolarPatterns?.contains(.stereo) == true {
            try? dataSource.setPreferredPolarPattern(.stereo)
            try? input.setPreferredDataSource(dataSource)
        }
        try? session.setPreferredInputOrientation(.portrait)
    }

    private func refreshCurrentInputName() {
        let session = AVAudioSession.sharedInstance()
        if let name = session.currentRoute.inputs.first?.portName, !name.isEmpty {
            currentInputName = name
        } else if currentInputName.isEmpty {
            currentInputName = String(localized: "iPhone Microphone")
        }
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
        AVAudioApplication.shared.recordPermission == .granted
    }
    
    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
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
        
        let capture = SettingsManager.shared.settings
        let session = AVAudioSession.sharedInstance()
        let micMode = resolvedMicMode(requested: capture.recordingMicMode, session: session)
        let fileName = "recording_\(UUID().uuidString).\(capture.recordingQuality.fileExtension)"
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent(fileName)
        let storageLocation = iCloudManager.shared.activeStorageLocation
        
        let settings = capture.recordingQuality.audioSettings(channelCount: micMode.channelCount)
        
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
            
            HapticFeedback.mediumImpact()
            
            isRecording = true
            currentRecordingURL = fileURL
            pendingStorageLocation = storageLocation
            recordingStartedAt = Date()
            meter.reset()
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
        
        HapticFeedback.lightImpact()
        
        let url = currentRecordingURL
        let elapsedBeforeStop = audioRecorder?.currentTime ?? recordingTime
        pendingFinalizationURL = url
        pendingFinalizationDuration = elapsedBeforeStop

        audioRecorder?.stop()
        isRecording = false
        RecordingLiveActivityManager.shared.endRecordingActivity(finalDuration: elapsedBeforeStop)

        levelTimer?.invalidate()
        levelTimer = nil

        meter.reset()
        recordingStartedAt = nil
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

    /// Header-only duration. Avoids decoding the whole file on the main actor.
    private static func durationFromAudioFile(at url: URL) -> TimeInterval? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let sampleRate = file.fileFormat.sampleRate
        guard sampleRate > 0, file.length > 0 else { return nil }
        return Double(file.length) / sampleRate
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
        recordings.removeAll { $0.id == recording.id }
        var tombstone = recording
        tombstone.isDeleted = true
        tombstone.lastModified = Date()
        deletionTombstones[recording.id] = tombstone
        mutationRevision += 1
        let root = iCloudManager.shared.getDocumentsURL()
        var deletionErrors: [Error] = []
        do {
            try LibraryFiles.write([tombstone], collection: .recordings, root: root)
        } catch {
            deletionErrors.append(error)
        }
        for url in [recording.fileURL, recording.originalFileURL].compactMap({ $0 }) {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                deletionErrors.append(error)
            }
        }
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
        UserDefaults.standard.set(encoded, forKey: "recordings_cache")

        let snapshot = recordings + Array(deletionTombstones.values)
        let root = iCloudManager.shared.getDocumentsURL()
        let kept = LibraryFiles.keepingLive(snapshot)
        let expired = LibraryFiles.expired(snapshot)
        let payloads = kept.compactMap { recording -> (id: UUID, data: Data)? in
            guard let data = try? JSONEncoder().encode(recording) else { return nil }
            return (recording.id, data)
        }
        let removingIDs = expired.map(\.id)
        let audioNames = expired.flatMap { [$0.fileName, $0.originalFileName].compactMap { $0 } }
        Task.detached(priority: .utility) {
            do {
                try await LibraryStore.shared.replace(
                    payloads: payloads,
                    removingIDs: removingIDs,
                    audioFileNames: audioNames,
                    collection: .recordings,
                    root: root
                )
            } catch {
                await MainActor.run {
                    AudioRecorder.shared.recordingError = String(localized: "Recording details could not be saved: \(error.localizedDescription)")
                }
            }
        }
        return true
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

        let roots = fileURLs.map { $0.deletingLastPathComponent() }
        let sidecars = LibraryFiles.readPayloads(collection: .recordings, roots: roots).compactMap {
            try? JSONDecoder().decode(Recording.self, from: $0)
        }
        loaded = mergeRecordings(loaded, with: sidecars)
        let cutoff = Date().addingTimeInterval(-LibraryFiles.tombstoneRetention)
        loaded = loaded.filter { !($0.isDeleted && $0.lastModified < cutoff) }

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

    func applyDownloadProgress(_ byFileName: [String: Double]) {
        var mapped: [UUID: Double] = [:]
        for recording in recordings {
            if let progress = byFileName[recording.fileName] ?? byFileName["\(recording.id.uuidString).json"] {
                mapped[recording.id] = progress
            }
        }
        if mapped != downloadProgress {
            downloadProgress = mapped
        }
    }

    /// Checks one recording's audio file when its row is on screen. Work is serialized off the main actor.
    func refreshVisibleRecording(_ id: UUID) async {
        guard let recording = recordings.first(where: { $0.id == id }) else { return }
        let fileName = recording.fileName
        let pinned = recording.storageLocation
        let roots = iCloudManager.shared.knownStorageRoots()
        let defaultRoot = iCloudManager.shared.getDocumentsURL()
        guard let status = await RecordingVisibilityLoader.shared.inspect(
            fileName: fileName,
            pinnedLocation: pinned,
            roots: roots,
            defaultRoot: defaultRoot,
            startDownloadIfMissing: true
        ) else { return }
        guard !Task.isCancelled else { return }
        guard let index = recordings.firstIndex(where: { $0.id == id }) else { return }

        var updated = recordings[index]
        let locationChanged = updated.storageLocation == nil && status.storageLocation != nil
        let availabilityChanged = updated.isLocallyAvailable != status.isLocallyAvailable
        guard locationChanged || availabilityChanged else { return }
        if availabilityChanged {
            updated.isLocallyAvailable = status.isLocallyAvailable
        }
        if locationChanged {
            updated.storageLocation = status.storageLocation
        }
        recordings[index] = updated
        if locationChanged {
            scheduleMetadataSave()
        }
    }

    private func scheduleMetadataSave() {
        metadataSaveTask?.cancel()
        metadataSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            _ = saveRecordings()
        }
    }

    private func refreshKeepDownloadedFiles() {
        let files = recordings.compactMap { recording -> (fileName: String, location: RecordingStorageLocation?)? in
            guard recording.keepDownloaded, recording.isStoredIniCloud else { return nil }
            return (recording.fileName, recording.storageLocation)
        }
        let roots = iCloudManager.shared.knownStorageRoots()
        let defaultRoot = iCloudManager.shared.getDocumentsURL()
        Task.detached(priority: .utility) {
            for file in files {
                let url = iCloudManager.resolvedFileURL(
                    fileName: file.fileName,
                    pinnedLocation: file.location,
                    roots: roots,
                    defaultRoot: defaultRoot
                )
                try? iCloudManager.shared.startKeepingDownloaded(at: url)
            }
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
                meter.reset()
            }
            if pendingFinalizationURL == nil {
                pendingFinalizationURL = recorderURL
                pendingFinalizationDuration = recorderDuration
            }
            finalizeRecording(successfully: flag)
        }
    }
}

