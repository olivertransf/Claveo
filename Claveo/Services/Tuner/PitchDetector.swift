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
    @Published var cents: Double = 0.0 // Actual cents deviation from target note (unclamped)
    @Published var targetFrequency: Double = 0.0 // Target frequency of the detected note
    @Published var isDetecting = false
    
    private var pitchEngine: PitchEngine?
    
    // Stabilization buffers
    private var frequencyBuffer: [Double] = []
    private var noteBuffer: [String] = []
    private let bufferSize = 5 // Reduced for faster response
    private let minConsistentReadings = 2 // Reduced for faster response
    private var lastStableNote: String = "--"
    private var lastStableFrequency: Double = 0.0
    private var lastStableCents: Double = 0.0
    
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
        
        // Skip audio initialization in preview mode or simulator (causes crashes)
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
        
        // Simulator detection - simulate pitch detection for testing
        #if targetEnvironment(simulator)
        isDetecting = true
        // Simulate a note for testing in simulator
        frequency = 440.0
        note = "A4"
        cents = 0.0
        
        // Simulate some variation for testing
        Task {
            var testFrequency = 440.0
            while isDetecting {
                // Simulate slight frequency variation
                testFrequency += Double.random(in: -2...2)
                testFrequency = max(200, min(800, testFrequency))
                let (note, cents, targetFreq) = calculateNote(from: testFrequency)
                self.frequency = testFrequency
                self.note = note
                self.cents = cents
                self.targetFrequency = targetFreq
                try? await Task.sleep(nanoseconds: 100_000_000) // Update every 100ms
            }
        }
        return
        #endif
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
        
        // Initialize Tuna PitchEngine with YIN algorithm
        // Larger buffer size (8192) improves accuracy for lower frequencies (piano)
        // Trade-off: slightly higher latency but much better accuracy
        pitchEngine = PitchEngine(
            bufferSize: 8192,
            estimationStrategy: .yin,
            callback: { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    switch result {
                    case .success(let pitch):
                        var rawFrequency = Double(pitch.frequency)
                        
                        // Validate frequency range (piano range: ~27.5 Hz to ~4186 Hz)
                        // Allow slightly wider range to catch edge cases
                        guard rawFrequency >= 20.0 && rawFrequency <= 5000.0 else {
                            // Invalid frequency - likely noise or error, clear buffers
                            self.frequencyBuffer.removeAll()
                            self.noteBuffer.removeAll()
                            return
                        }
                        
                        // Filter out overtones/harmonics
                        // If the frequency is likely a harmonic (2x, 3x, 4x) of a lower note, use the lower note
                        rawFrequency = self.filterOvertone(rawFrequency)
                        
                        // Add to frequency buffer for stabilization
                        self.frequencyBuffer.append(rawFrequency)
                        if self.frequencyBuffer.count > self.bufferSize {
                            self.frequencyBuffer.removeFirst()
                        }
                        
                        // Calculate stabilized frequency using median (more robust than mean)
                        let stabilizedFrequency = self.calculateStabilizedFrequency()
                        
                        // Update note from stabilized frequency
                        let (note, cents, targetFreq) = self.calculateNote(from: stabilizedFrequency)
                        self.targetFrequency = targetFreq
                        
                        // Add note to buffer for consistency checking
                        self.noteBuffer.append(note)
                        if self.noteBuffer.count > self.bufferSize {
                            self.noteBuffer.removeFirst()
                        }
                        
                        // Only update display if we have enough consistent readings
                        if self.frequencyBuffer.count >= self.minConsistentReadings {
                            // Check if we have consistent note readings
                            let mostCommonNote = self.getMostCommonNote()
                            let noteCount = self.noteBuffer.filter { $0 == mostCommonNote }.count
                            
                            // If we have enough consistent readings of the same note, update display
                            if noteCount >= self.minConsistentReadings && mostCommonNote != "--" {
                                self.frequency = stabilizedFrequency
                                self.note = mostCommonNote
                                self.cents = cents
                                self.targetFrequency = targetFreq
                                self.lastStableNote = mostCommonNote
                                self.lastStableFrequency = stabilizedFrequency
                                self.lastStableCents = cents
                            } else if self.lastStableFrequency > 0 {
                                // Keep showing last stable reading if current is inconsistent
                                self.frequency = self.lastStableFrequency
                                self.note = self.lastStableNote
                                self.cents = self.lastStableCents
                                // Recalculate target frequency for last stable note
                                let (_, _, lastTargetFreq) = self.calculateNote(from: self.lastStableFrequency)
                                self.targetFrequency = lastTargetFreq
                            }
                        } else {
                            // Not enough readings yet, but show what we have
                            self.frequency = stabilizedFrequency
                            self.note = note
                            self.cents = cents
                            self.targetFrequency = targetFreq
                        }
                    case .failure(let error):
                        #if DEBUG
                        print("Pitch detection error: \(error)")
                        #endif
                        // Don't reset frequency on errors, keep last known value
                        if case PitchEngine.Error.levelBelowThreshold = error {
                            // Signal too weak - clear buffers after a delay
                            Task {
                                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                                // If still no signal, clear buffers
                                if self.frequencyBuffer.isEmpty || self.frequencyBuffer.last == 0 {
                                    self.frequencyBuffer.removeAll()
                                    self.noteBuffer.removeAll()
                                    self.frequency = 0
                                    self.note = "--"
                                    self.cents = 0
                                }
                            }
                        } else {
                            // Clear buffers on other errors
                            self.frequencyBuffer.removeAll()
                            self.noteBuffer.removeAll()
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
        Task.detached(priority: .userInitiated) {
            // Call start() on background thread (this internally calls AVCaptureSession.startRunning())
            engine?.start()
            // Update UI state on main thread after starting
            await MainActor.run { [weak self] in
                self?.isDetecting = true
            }
        }
    }
    
    func stopDetection() {
        // Stop pitch engine on background thread to avoid blocking main thread
        let engine = pitchEngine
        Task.detached(priority: .userInitiated) {
            // Call stop() on background thread (this internally calls AVCaptureSession.stopRunning())
            engine?.stop()
            
            // Update UI state on main thread after stopping
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.pitchEngine = nil
                self.isDetecting = false
                self.frequency = 0.0
                self.note = "--"
                self.cents = 0.0
                self.frequencyBuffer.removeAll()
                self.noteBuffer.removeAll()
                self.lastStableNote = "--"
                self.lastStableFrequency = 0.0
                self.lastStableCents = 0.0
            }
            
            // Deactivate audio session when stopping
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
        }
    }
    
    // Filter out overtones - if frequency is likely a harmonic, return the fundamental
    private func filterOvertone(_ frequency: Double) -> Double {
        // Check if this frequency is close to 2x (octave) of a lower note
        // Piano fundamental range is roughly 27.5 Hz (A0) to 4186 Hz (C8)
        
        // Check for octave (2x) - most common overtone
        let halfFreq = frequency / 2.0
        if halfFreq >= 27.0 && halfFreq <= 4200.0 {
            // Calculate what notes these frequencies correspond to
            let (note1, cents1, _) = calculateNote(from: frequency)
            let (note2, cents2, _) = calculateNote(from: halfFreq)
            
            // If half frequency gives a valid note
            if note2 != "--" {
                // Extract note names (without octave)
                let note1Name = extractNoteName(note1)
                let note2Name = extractNoteName(note2)
                
                // If same note name (octave relationship) and lower frequency is closer to in-tune
                if note1Name == note2Name && abs(cents2) < abs(cents1) + 20 {
                    // Prefer the lower frequency (fundamental)
                    return halfFreq
                }
            }
        }
        
        // Return original frequency if no clear overtone detected
        return frequency
    }
    
    // Extract note name without octave (e.g., "C4" -> "C", "C#5" -> "C#")
    private func extractNoteName(_ noteWithOctave: String) -> String {
        // Find the first digit and remove everything from there
        if let firstDigitIndex = noteWithOctave.firstIndex(where: { $0.isNumber }) {
            return String(noteWithOctave[..<firstDigitIndex])
        }
        return noteWithOctave
    }
    
    // Calculate stabilized frequency using median (more robust to outliers)
    private func calculateStabilizedFrequency() -> Double {
        guard !frequencyBuffer.isEmpty else { return 0.0 }
        
        let sorted = frequencyBuffer.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            // Even number of samples - average the two middle values
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            // Odd number of samples - use the middle value
            return sorted[count / 2]
        }
    }
    
    // Get the most common note from the buffer
    private func getMostCommonNote() -> String {
        guard !noteBuffer.isEmpty else { return "--" }
        
        // Count occurrences of each note
        var noteCounts: [String: Int] = [:]
        for note in noteBuffer {
            noteCounts[note, default: 0] += 1
        }
        
        // Find the note with the highest count
        let mostCommon = noteCounts.max(by: { $0.value < $1.value })
        return mostCommon?.key ?? "--"
    }
    
    // Calculate note and cents from frequency
    private func calculateNote(from frequency: Double) -> (note: String, cents: Double, targetFrequency: Double) {
        // Guard against invalid frequencies
        guard frequency > 0 && frequency < 5000 else {
            return ("--", 0, 0)
        }
        
        // Calculate the semitones from A4
        // Formula: frequency = A4 * 2^(semitones/12)
        // Solving for semitones: semitones = 12 * log2(frequency / A4)
        let semitonesFromA4 = 12.0 * log2(frequency / a4ReferenceFrequency)
        
        // Round to nearest semitone to find the closest note
        let roundedSemitones = round(semitonesFromA4)
        
        // Calculate which octave and note this corresponds to
        // In scientific pitch notation:
        // - A4 is at semitone 0 from A4
        // - C4 is 9 semitones below A4 (semitone -9)
        // - B4 is 2 semitones above A4 (semitone 2)
        // - C5 is 3 semitones above A4 (semitone 3)
        // 
        // Octave 4 spans from C4 (semitone -9) to B4 (semitone 2)
        // General formula: octave = 4 + floor((semitones + 9) / 12)
        let octave = 4 + Int(floor((roundedSemitones + 9.0) / 12.0))
        
        // Calculate note index (0-11, where 0 = C, 9 = A)
        // A4 is at index 9, so: noteIndex = (9 + roundedSemitones) mod 12
        // Handle negative modulo correctly
        var noteIndex = (Int(roundedSemitones) + 9) % 12
        if noteIndex < 0 {
            noteIndex += 12
        }
        noteIndex = noteIndex % 12 // Ensure it's in range 0-11
        
        let closestNote = noteNames[noteIndex]
        let closestFrequency = noteFrequency(closestNote, octave: octave)
        
        // Calculate cents deviation from the target note
        // Cents = 1200 * log2(actual_frequency / target_frequency)
        let cents = 1200.0 * log2(frequency / closestFrequency)
        
        // Format note with octave
        let note = "\(closestNote)\(octave)"
        
        return (note, cents, closestFrequency)
    }
    
    // Recalculate note from current frequency (useful when reference frequency changes)
    func recalculateNote() {
        guard frequency > 0 else { return }
        let (note, cents, targetFreq) = calculateNote(from: frequency)
        self.note = note
        self.cents = cents
        self.targetFrequency = targetFreq
    }
}
