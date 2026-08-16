//
//  PitchDetector.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation
import Combine
import AVFoundation
import QuartzCore

// Using Tuna library for pitch detection
// Add package: https://github.com/alladinian/Tuna
import Tuna

struct TunerLifecycleGate {
    private(set) var wantsActive = false
    private var generation: UInt = 0

    mutating func requestStart() -> UInt? {
        guard !wantsActive else { return nil }
        wantsActive = true
        generation &+= 1
        return generation
    }

    mutating func requestStop() -> UInt? {
        guard wantsActive else { return nil }
        wantsActive = false
        generation &+= 1
        return generation
    }

    func isCurrent(_ token: UInt, expectingActive: Bool) -> Bool {
        generation == token && wantsActive == expectingActive
    }
}

enum PitchDetectorError: LocalizedError, Identifiable, Equatable {
    case permissionDenied
    case audioSession(String)

    var id: String {
        switch self {
        case .permissionDenied:
            "permissionDenied"
        case .audioSession(let message):
            "audioSession:\(message)"
        }
    }

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            String(localized: "Microphone access is turned off.")
        case .audioSession:
            String(localized: "The tuner couldn’t start the audio session.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            String(localized: "Allow microphone access in Settings, then return to the tuner.")
        case .audioSession:
            String(localized: "Check that another app isn’t using audio, then try again.")
        }
    }
}

@MainActor
class PitchDetector: NSObject, ObservableObject {
    @Published var frequency: Double = 0.0
    @Published var note: String = "--"
    @Published var cents: Double = 0.0 // Actual cents deviation from target note (unclamped)
    @Published var targetFrequency: Double = 0.0 // Target frequency of the detected note
    @Published var isDetecting = false
    @Published var lifecycleError: PitchDetectorError?
    
    private var pitchEngine: PitchEngine?
    private var lifecycle = TunerLifecycleGate()
    private var engineOperation: Task<Void, Never>?
    private var ownsAudioSession = false

    private static var usesSimulatedInput: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
        #endif
    }
    
    // Stabilization buffers
    private var frequencyBuffer: [Double] = []
    private var noteBuffer: [String] = []
    private let bufferSize = 5 // Reduced for faster response
    private let minConsistentReadings = 2 // Reduced for faster response
    private var lastStableNote: String = "--"
    private var lastStableFrequency: Double = 0.0
    private var lastStableCents: Double = 0.0
    private var lastPitchPublishTime: TimeInterval = 0
    
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
        guard let lifecycleToken = lifecycle.requestStart() else { return }
        lifecycleError = nil
        
        if Self.usesSimulatedInput {
            setSimulatedDetection(token: lifecycleToken)
            return
        }
        
        let permissionGranted: Bool
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                permissionGranted = true
            case .denied:
                permissionGranted = false
            case .undetermined:
                permissionGranted = await AVAudioApplication.requestRecordPermission()
            @unknown default:
                permissionGranted = false
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                permissionGranted = true
            case .denied:
                permissionGranted = false
            case .undetermined:
                permissionGranted = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                permissionGranted = false
            }
        }

        guard lifecycle.isCurrent(lifecycleToken, expectingActive: true) else { return }
        guard permissionGranted else {
            failStart(with: .permissionDenied, token: lifecycleToken)
            return
        }

        AudioSessionCoordinator.prepareForTuner()
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true, options: [])
            ownsAudioSession = true
            try await Task.sleep(for: .milliseconds(50))
        } catch is CancellationError {
            stopDetection()
            return
        } catch {
            failStart(with: .audioSession(error.localizedDescription), token: lifecycleToken)
            return
        }

        guard lifecycle.isCurrent(lifecycleToken, expectingActive: true) else { return }
        
        // Initialize Tuna PitchEngine with YIN algorithm
        // Larger buffer size (8192) improves accuracy for lower frequencies (piano)
        // Trade-off: slightly higher latency but much better accuracy
        let engine = PitchEngine(
            bufferSize: 8192,
            estimationStrategy: .yin,
            callback: { [weak self] result in
                Task { @MainActor in
                    guard
                        let self,
                        self.lifecycle.isCurrent(lifecycleToken, expectingActive: true)
                    else { return }
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
                                self.publishPitch(
                                    frequency: stabilizedFrequency,
                                    note: mostCommonNote,
                                    cents: cents,
                                    targetFrequency: targetFreq
                                )
                                self.lastStableNote = mostCommonNote
                                self.lastStableFrequency = stabilizedFrequency
                                self.lastStableCents = cents
                            } else if self.lastStableFrequency > 0 {
                                self.publishPitch(
                                    frequency: self.lastStableFrequency,
                                    note: self.lastStableNote,
                                    cents: self.lastStableCents,
                                    targetFrequency: self.calculateNote(from: self.lastStableFrequency).2
                                )
                            }
                        } else {
                            self.publishPitch(
                                frequency: stabilizedFrequency,
                                note: note,
                                cents: cents,
                                targetFrequency: targetFreq
                            )
                        }
                    case .failure(let error):
                        #if DEBUG
                        print("Pitch detection error: \(error)")
                        #endif
                        // Don't reset frequency on errors, keep last known value
                        if case PitchEngine.Error.levelBelowThreshold = error {
                            // Signal too weak - clear buffers after a delay
                            Task { @MainActor [weak self] in
                                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                                guard
                                    let self,
                                    self.lifecycle.isCurrent(lifecycleToken, expectingActive: true)
                                else { return }
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
        pitchEngine = engine
        
        let previousOperation = engineOperation
        let startOperation = Task.detached(priority: .userInitiated) {
            await previousOperation?.value
            engine.start()
        }
        engineOperation = startOperation
        await startOperation.value

        if Task.isCancelled || !lifecycle.isCurrent(lifecycleToken, expectingActive: true) {
            stopDetection()
            return
        }
        isDetecting = true
    }
    
    func stopDetection() {
        guard let lifecycleToken = lifecycle.requestStop() else { return }
        let engine = pitchEngine
        pitchEngine = nil
        resetDetectionState()

        let previousOperation = engineOperation
        let stopOperation = Task.detached(priority: .userInitiated) {
            await previousOperation?.value
            engine?.stop()
        }
        engineOperation = stopOperation

        Task { @MainActor [weak self] in
            await stopOperation.value
            guard
                let self,
                self.lifecycle.isCurrent(lifecycleToken, expectingActive: false)
            else { return }
            self.deactivateAudioSession()
        }
    }

    private func setSimulatedDetection(token: UInt) {
        guard lifecycle.isCurrent(token, expectingActive: true) else { return }
        isDetecting = true
        frequency = 440
        note = "A4"
        cents = 0
        targetFrequency = 440
    }

    private func failStart(with error: PitchDetectorError, token: UInt) {
        guard lifecycle.isCurrent(token, expectingActive: true) else { return }
        lifecycleError = error
        stopDetection()
    }

    private func deactivateAudioSession() {
        guard ownsAudioSession else { return }
        ownsAudioSession = false
        // Never force-deactivate while other Claveo playback may still own the session;
        // notify them so they can restore `.playback` if needed.
        AudioSessionCoordinator.tunerDidReleaseSession()
    }

    private func publishPitch(
        frequency: Double,
        note: String,
        cents: Double,
        targetFrequency: Double
    ) {
        let now = CACurrentMediaTime()
        let noteChanged = note != self.note
        guard noteChanged
            || abs(frequency - self.frequency) > 0.4
            || abs(cents - self.cents) > 1
            || now - lastPitchPublishTime >= 0.07
        else { return }
        lastPitchPublishTime = now
        if self.frequency != frequency { self.frequency = frequency }
        if self.note != note { self.note = note }
        if self.cents != cents { self.cents = cents }
        if self.targetFrequency != targetFrequency { self.targetFrequency = targetFrequency }
    }

    private func resetDetectionState() {
        isDetecting = false
        frequency = 0
        note = "--"
        cents = 0
        targetFrequency = 0
        frequencyBuffer.removeAll()
        noteBuffer.removeAll()
        lastStableNote = "--"
        lastStableFrequency = 0
        lastStableCents = 0
        lastPitchPublishTime = 0
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
                
                // Only drop an octave when the lower note is clearly more in tune.
                // An exact octave has the same cents deviation, so a tolerant
                // comparison here would halve every reading.
                if note1Name == note2Name && abs(cents2) + 15 < abs(cents1) {
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

        // Ties resolve to the most recent reading; dictionary order is unstable
        // and would otherwise make the displayed note flicker.
        var best = noteBuffer[noteBuffer.count - 1]
        var bestCount = noteCounts[best] ?? 0
        for note in noteBuffer.reversed() where (noteCounts[note] ?? 0) > bestCount {
            best = note
            bestCount = noteCounts[note] ?? 0
        }
        return best
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
