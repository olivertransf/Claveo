//
//  PitchDetector.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import Foundation
import Combine
import AVFoundation

// Using Tuna library for pitch detection
// Add package: https://github.com/alladinian/Tuna
import Tuna

@MainActor
class PitchDetector: NSObject, ObservableObject {
    @Published var frequency: Double = 0.0
    @Published var note: String = "--"
    @Published var cents: Double = 0.0 // -50 to +50 cents from target note
    @Published var isDetecting = false
    
    private var pitchEngine: PitchEngine?
    
    // A4 reference frequency (default 440 Hz, can be changed in settings)
    var a4ReferenceFrequency: Double {
        SettingsManager.shared.settings.a4ReferenceFrequency
    }
    
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    // Calculate note frequency based on A4 reference
    private func noteFrequency(_ noteName: String, octave: Int) -> Double {
        let noteIndex = noteNames.firstIndex(of: noteName) ?? 0
        let semitonesFromA4 = (octave - 4) * 12 + (noteIndex - 9) // A4 is index 9
        return a4ReferenceFrequency * pow(2.0, Double(semitonesFromA4) / 12.0)
    }
    
    func startDetection() async {
        guard !isDetecting else { return }
        
        // Skip audio initialization in preview mode (causes crashes)
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1" {
            // Running in preview/playground - simulate detection for UI testing
            isDetecting = true
            // Set some dummy values for preview
            frequency = 440.0
            note = "A4"
            cents = 0.0
            return
        }
        #endif
        
        // Request microphone permission first
        let hasPermission: Bool
        if #available(iOS 17.0, *) {
            hasPermission = AVAudioApplication.shared.recordPermission == .granted
        } else {
            hasPermission = AVAudioSession.sharedInstance().recordPermission == .granted
        }
        
        if !hasPermission {
            // Request permission
            if #available(iOS 17.0, *) {
                let granted = await AVAudioApplication.requestRecordPermission()
                if !granted {
                    #if DEBUG
                    print("Microphone permission denied")
                    #endif
                    return
                }
            } else {
                let granted = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                if !granted {
                    #if DEBUG
                    print("Microphone permission denied")
                    #endif
                    return
                }
            }
        }
        
        // Configure audio session with proper settings for pitch detection
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use .record category with .measurement mode for low-latency audio input
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true, options: [])
            
            // Give the audio session a moment to stabilize
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        } catch {
            #if DEBUG
            print("Failed to setup audio session for pitch detection: \(error)")
            #endif
            return
        }
        
        // Initialize Tuna PitchEngine with YIN algorithm (best for monophonic pitch detection)
        pitchEngine = PitchEngine(
            bufferSize: 4096,
            estimationStrategy: .yin,
            callback: { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    switch result {
                    case .success(let pitch):
                        self.frequency = Double(pitch.frequency)
                        self.updateNote(from: self.frequency)
                    case .failure(let error):
                        #if DEBUG
                        print("Pitch detection error: \(error)")
                        #endif
                        // Don't reset frequency on errors, keep last known value
                        if case PitchEngine.Error.levelBelowThreshold = error {
                            // Signal too weak - this is expected sometimes
                        } else {
                            self.frequency = 0
                            self.note = "--"
                            self.cents = 0
                        }
                    }
                }
            }
        )
        
        // Start pitch engine on background thread to avoid blocking main thread
        // AVCaptureSession.startRunning() should be called from background thread
        let engine = pitchEngine
        await Task.detached(priority: .userInitiated) { [weak self] in
            // Call start() on background thread (this internally calls AVCaptureSession.startRunning())
            engine?.start()
            // Update UI state on main thread after starting
            await MainActor.run {
                self?.isDetecting = true
            }
        }
    }
    
    func stopDetection() {
        // Stop pitch engine on background thread to avoid blocking main thread
        let engine = pitchEngine
        Task.detached(priority: .userInitiated) { [weak self] in
            // Call stop() on background thread (this internally calls AVCaptureSession.stopRunning())
            engine?.stop()
            
            // Update UI state on main thread after stopping
            await MainActor.run {
                guard let self = self else { return }
                self.pitchEngine = nil
                self.isDetecting = false
                self.frequency = 0.0
                self.note = "--"
                self.cents = 0.0
            }
            
            // Deactivate audio session when stopping
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
        }
    }
    
    private func updateNote(from frequency: Double) {
        // Find closest note
        var closestNote = "C"
        var closestOctave = 4
        var minDifference = Double.infinity
        var closestFrequency: Double = 0
        
        // Check multiple octaves
        for octave in 1...7 {
            for noteName in noteNames {
                let noteFreq = noteFrequency(noteName, octave: octave)
                let difference = abs(frequency - noteFreq)
                
                if difference < minDifference {
                    minDifference = difference
                    closestNote = noteName
                    closestOctave = octave
                    closestFrequency = noteFreq
                }
            }
        }
        
        // Calculate cents deviation
        if closestFrequency > 0 {
            let cents = 1200 * log2(frequency / closestFrequency)
            self.cents = max(-20, min(20, cents))
        }
        
        // Format note with octave
        self.note = "\(closestNote)\(closestOctave)"
    }
}
