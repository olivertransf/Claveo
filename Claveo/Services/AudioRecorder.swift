//
//  AudioRecorder.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import AVFoundation
import Foundation
import Combine

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordings: [Recording] = []
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var permissionError: String?
    @Published var newlyCreatedRecordingId: UUID?
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var currentRecordingURL: URL?
    
    override init() {
        super.init()
        loadRecordings()
        setupAudioSession()
        
        // Debug: Print storage location
        print("📁 Storage Location: \(iCloudManager.shared.getStorageLocation())")
        print("📁 Storage Path: \(iCloudManager.shared.getStoragePath())")
    }
    
    private func setupAudioSession() {
        // Don't activate session here - do it when recording starts
        // This prevents conflicts with other audio sessions
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
        
        // Setup and activate audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
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
                print("ERROR: prepareToRecord() returned false")
                return
            }
            
            // Start recording
            guard recorder.record() else {
                permissionError = "Failed to start recording. Please check your microphone settings."
                print("ERROR: record() returned false")
                print("Recorder isRecording: \(recorder.isRecording)")
                return
            }
            
            print("Recording started successfully at: \(fileURL)")
            
            isRecording = true
            currentRecordingURL = fileURL
            recordingTime = 0
            
            let recorderRef = audioRecorder
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.recordingTime += 0.1
                }
            }
            
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                recorderRef?.updateMeters()
                if let level = recorderRef?.averagePower(forChannel: 0) {
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        // Convert from dB to 0-1 range
                        let normalizedLevel = pow(10, level / 20)
                        self.audioLevel = max(0, min(1, normalizedLevel))
                    }
                }
            }
        } catch {
            permissionError = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        levelTimer?.invalidate()
        levelTimer = nil
        
        audioLevel = 0.0
        
        if let url = currentRecordingURL {
            let duration = recordingTime
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
        recordingTime = 0
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
        
        do {
            try iCloudManager.shared.writeFile(data: encoded, to: fileURL)
        } catch {
            print("Failed to save recordings: \(error.localizedDescription)")
            // Fallback to direct write if coordination fails
            try? encoded.write(to: fileURL, options: [.atomic])
        }
    }
    
    private func loadRecordings() {
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("recordings.json")
        
        do {
            let data = try iCloudManager.shared.readFile(from: fileURL)
            if let decoded = try? JSONDecoder().decode([Recording].self, from: data) {
                recordings = decoded.sorted { $0.createdAt > $1.createdAt }
            }
        } catch {
            // Fallback to direct read if coordination fails
            if let data = try? Data(contentsOf: fileURL),
               let decoded = try? JSONDecoder().decode([Recording].self, from: data) {
                recordings = decoded.sorted { $0.createdAt > $1.createdAt }
            }
        }
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
                recordingTimer?.invalidate()
                levelTimer?.invalidate()
                audioLevel = 0.0
            }
        }
    }
}

