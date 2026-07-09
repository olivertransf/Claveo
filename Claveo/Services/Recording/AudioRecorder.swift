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
    @Published var newlyCreatedRecordingId: UUID?
    @Published private(set) var isLoadingRecordings = false

    private var hasLoadedFromDisk = false
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var currentRecordingURL: URL?
    private var recordingStartedAt: Date?
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
                await self?.reloadRecordingsFromDisk()
            }
        }
    }

    /// Loads metadata from iCloud/local after `iCloudManager.warmUpIfNeeded()`.
    func reloadRecordingsFromDisk(force: Bool = false) async {
        if hasLoadedFromDisk && !force {
            syncRecordingsFromiCloud()
            return
        }

        let showLoading = recordings.isEmpty
        if showLoading { isLoadingRecordings = true }
        defer {
            if showLoading { isLoadingRecordings = false }
            hasLoadedFromDisk = true
        }

        await iCloudManager.shared.warmUpIfNeeded()

        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("recordings.json")

        let loaded: [Recording]? = await Task.detached(priority: .utility) {
            Self.readRecordingsFile(at: fileURL)
        }.value

        if let loaded {
            recordings = loaded
        }
    }
    
    private func syncRecordingsFromiCloud() {
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("recordings.json")

        do {
            let data = try iCloudManager.shared.readFile(from: fileURL)
            if let decoded = try? JSONDecoder().decode([Recording].self, from: data) {
                var mergedByID = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
                for localRecording in recordings {
                    mergedByID[localRecording.id] = localRecording
                }
                recordings = mergedByID.values.sorted { $0.createdAt > $1.createdAt }
                saveRecordings()
            }
        } catch {
            saveRecordings()
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
                MainActor.assumeIsolated {
                    self?.handleAudioSessionInterruption(userInfo: notification.userInfo)
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
        case .ended:
            guard isRecording else { return }
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                do {
                    try activateRecordingAudioSession()
                    if audioRecorder?.isRecording != true {
                        _ = audioRecorder?.record()
                    }
                    refreshRecordingProgressFromFile()
                } catch {
                    #if DEBUG
                    print("Failed to resume recording after interruption: \(error)")
                    #endif
                }
            }
        @unknown default:
            break
        }
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
        
        // Check current permission status
        let hasPermission = checkPermissionStatus()
        
        if !hasPermission {
            // Request permission if not granted
            let granted = await requestPermission()
            if !granted {
                permissionError = "Microphone access is required to record audio. Please enable it in Settings."
                return
            }
        }
        
        do {
            try activateRecordingAudioSession()
        } catch {
            permissionError = "Failed to setup audio session: \(error.localizedDescription)"
            return
        }
        
        let fileName = "recording_\(UUID().uuidString).m4a"
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
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
                permissionError = "Failed to create audio recorder."
                return
            }
            
            // Prepare the recorder before starting
            guard recorder.prepareToRecord() else {
                permissionError = "Failed to prepare recorder. Check microphone availability."
                #if DEBUG
                print("ERROR: prepareToRecord() returned false")
                #endif
                return
            }
            
            // Start recording
            guard recorder.record() else {
                permissionError = "Failed to start recording. Please check your microphone settings."
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
            permissionError = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Haptic feedback for recording stop
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        let url = currentRecordingURL
        let elapsedBeforeStop = audioRecorder?.currentTime ?? recordingTime

        audioRecorder?.stop()
        isRecording = false
        RecordingLiveActivityManager.shared.endRecordingActivity(finalDuration: elapsedBeforeStop)

        levelTimer?.invalidate()
        levelTimer = nil

        audioLevel = 0.0
        waveformLevels = [] // Clear waveform buffer

        if let url {
            let duration = Self.durationFromAudioFile(at: url) ?? elapsedBeforeStop
            // File is already in iCloud directory, so it will sync automatically
            let recording = Recording(
                fileName: url.lastPathComponent,
                createdAt: Date(),
                duration: duration,
                notes: ""
            )
            recordings.append(recording)
            newlyCreatedRecordingId = recording.id
            saveRecordings()
        }
        
        currentRecordingURL = nil
        recordingStartedAt = nil
        recordingTime = 0
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

    func updateRecording(_ recording: Recording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
            saveRecordings()
        }
    }
    
    func deleteRecording(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.fileURL)
        recordings.removeAll { $0.id == recording.id }
        saveRecordings()
    }
    
    func saveRecordings() {
        guard let encoded = try? JSONEncoder().encode(recordings) else { return }
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("recordings.json")
        
        // Save to local cache first (UserDefaults) for offline access
        UserDefaults.standard.set(encoded, forKey: "recordings_cache")
        
        // Then save to iCloud (will queue if offline)
        do {
            try iCloudManager.shared.writeFile(data: encoded, to: fileURL)
        } catch {
            #if DEBUG
            print("Failed to save recordings to iCloud: \(error.localizedDescription)")
            #endif
            // Fallback to direct write if coordination fails (iOS will queue for sync)
            try? encoded.write(to: fileURL, options: [.atomic])
        }
    }
    
    private func loadRecordingsFromCache() {
        guard let cachedData = UserDefaults.standard.data(forKey: "recordings_cache"),
              let decoded = try? JSONDecoder().decode([Recording].self, from: cachedData) else {
            return
        }
        recordings = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private nonisolated static func readRecordingsFile(at fileURL: URL) -> [Recording]? {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Recording].self, from: data) {
            UserDefaults.standard.set(data, forKey: "recordings_cache")
            return decoded.sorted { $0.createdAt > $1.createdAt }
        }

        if let cachedData = UserDefaults.standard.data(forKey: "recordings_cache"),
           let decoded = try? JSONDecoder().decode([Recording].self, from: cachedData) {
            return decoded.sorted { $0.createdAt > $1.createdAt }
        }

        return nil
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
        if !flag {
            Task { @MainActor in
                if let url = currentRecordingURL {
                    try? FileManager.default.removeItem(at: url)
                }
                isRecording = false
                RecordingLiveActivityManager.shared.endRecordingActivity(finalDuration: recordingTime, dismissalPolicy: .immediate)
                levelTimer?.invalidate()
                audioLevel = 0.0
                waveformLevels = []
            }
        }
    }
}

