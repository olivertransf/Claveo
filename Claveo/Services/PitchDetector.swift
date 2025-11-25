//
//  PitchDetector.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import AVFoundation
import Foundation
import Accelerate
import Combine

@MainActor
class PitchDetector: NSObject, ObservableObject {
    @Published var frequency: Double = 0.0
    @Published var note: String = "--"
    @Published var cents: Double = 0.0 // -50 to +50 cents from target note
    @Published var isDetecting = false
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    // Autocorrelation setup
    private let bufferSize = 4096
    private let minFrequency: Double = 80.0  // Minimum detectable frequency (Hz)
    private let maxFrequency: Double = 2000.0  // Maximum detectable frequency (Hz)
    
    // A4 reference frequency (default 440 Hz, can be changed in settings)
    var a4ReferenceFrequency: Double {
        UserDefaults.standard.double(forKey: "a4ReferenceFrequency") == 0 ? 440.0 : UserDefaults.standard.double(forKey: "a4ReferenceFrequency")
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
        
        // Request microphone permission
        let granted = await requestMicrophonePermission()
        guard granted else {
            print("Microphone permission denied")
            return
        }
        
        setupAudioEngine()
        isDetecting = true
    }
    
    func stopDetection() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
        isDetecting = false
        frequency = 0.0
        note = "--"
        cents = 0.0
        frequencyHistory.removeAll()
    }
    
    private func requestMicrophonePermission() async -> Bool {
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
    
    private func setupAudioEngine() {
        // Stop and reset any existing engine
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        // Setup audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
            isDetecting = false
            return
        }
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            isDetecting = false
            return
        }
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            isDetecting = false
            return
        }
        
        // Prepare the engine
        audioEngine.prepare()
        
        // Get the actual hardware input format
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let sampleRate = inputFormat.sampleRate
        
        guard sampleRate > 0 && inputFormat.channelCount > 0 else {
            print("Invalid input format")
            isDetecting = false
            return
        }
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.processAudioBuffer(buffer, sampleRate: sampleRate)
            }
        }
        
        // Start engine
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
            isDetecting = false
        }
    }
    
    private var frequencyHistory: [Double] = []
    private let historySize = 10
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        
        guard frameLength >= bufferSize / 2 else { return }
        
        // Convert to mono if needed and copy samples
        var samples = [Float](repeating: 0, count: frameLength)
        
        if buffer.format.channelCount == 1 {
            // Mono - copy directly
            for i in 0..<frameLength {
                samples[i] = channelData[0][i]
            }
        } else {
            // Stereo or multi-channel - average channels
            for i in 0..<frameLength {
                var sum: Float = 0
                for channel in 0..<Int(buffer.format.channelCount) {
                    sum += channelData[channel][i]
                }
                samples[i] = sum / Float(buffer.format.channelCount)
            }
        }
        
        // Apply high-pass filter to remove DC offset and low-frequency noise
        let filteredSamples = highPassFilter(samples, sampleRate: sampleRate)
        
        // Detect pitch using autocorrelation
        let detectedFrequency = detectPitchAutocorrelation(filteredSamples, sampleRate: sampleRate)
        
        if detectedFrequency > 0 && detectedFrequency >= minFrequency && detectedFrequency <= maxFrequency {
            // Smooth frequency using moving average
            frequencyHistory.append(detectedFrequency)
            if frequencyHistory.count > historySize {
                frequencyHistory.removeFirst()
            }
            
            let smoothedFrequency = frequencyHistory.reduce(0, +) / Double(frequencyHistory.count)
            self.frequency = smoothedFrequency
            updateNote(from: smoothedFrequency)
        } else {
            // If no valid frequency, gradually clear history
            if frequencyHistory.count > 0 {
                frequencyHistory.removeFirst()
                if frequencyHistory.isEmpty {
                    self.frequency = 0
                    self.note = "--"
                    self.cents = 0
                } else {
                    let smoothedFrequency = frequencyHistory.reduce(0, +) / Double(frequencyHistory.count)
                    self.frequency = smoothedFrequency
                    updateNote(from: smoothedFrequency)
                }
            } else {
                self.frequency = 0
                self.note = "--"
                self.cents = 0
            }
        }
    }
    
    // Simple high-pass filter to remove DC offset
    private func highPassFilter(_ samples: [Float], sampleRate: Double) -> [Float] {
        let cutoff: Double = 50.0 // Hz
        let rc = 1.0 / (2.0 * Double.pi * cutoff)
        let dt = 1.0 / sampleRate
        let alpha = rc / (rc + dt)
        
        var filtered = [Float](repeating: 0, count: samples.count)
        var prevInput: Float = 0
        var prevOutput: Float = 0
        
        let alphaFloat = Float(alpha)
        for i in 0..<samples.count {
            let input = samples[i]
            let output = alphaFloat * (prevOutput + input - prevInput)
            filtered[i] = output
            prevInput = input
            prevOutput = output
        }
        
        return filtered
    }
    
    // Autocorrelation-based pitch detection (more reliable than FFT)
    private func detectPitchAutocorrelation(_ samples: [Float], sampleRate: Double) -> Double {
        let sampleCount = samples.count
        
        // Calculate min and max lag based on frequency range
        let minLag = Int(sampleRate / maxFrequency)
        let maxLag = Int(sampleRate / minFrequency)
        
        guard maxLag < sampleCount / 2 else { return 0 }
        
        // Normalize samples
        var normalizedSamples = samples
        let mean = normalizedSamples.reduce(0, +) / Float(sampleCount)
        for i in 0..<sampleCount {
            normalizedSamples[i] -= mean
        }
        
        // Calculate RMS for signal strength check
        var rms: Float = 0
        vDSP_rmsqv(normalizedSamples, 1, &rms, vDSP_Length(sampleCount))
        
        // Threshold for minimum signal strength
        let threshold: Float = 0.01
        guard rms > threshold else { return 0 }
        
        // Autocorrelation
        var maxCorrelation: Float = 0
        var bestLag = 0
        
        for lag in minLag..<maxLag {
            var correlation: Float = 0
            
            // Calculate correlation at this lag
            for i in 0..<(sampleCount - lag) {
                correlation += normalizedSamples[i] * normalizedSamples[i + lag]
            }
            
            // Normalize by number of samples
            correlation /= Float(sampleCount - lag)
            
            // Check if this is a better peak
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestLag = lag
            }
        }
        
        // Check if we found a strong enough correlation
        let minCorrelation: Float = 0.3
        guard maxCorrelation > minCorrelation else { return 0 }
        
        // Refine the lag using parabolic interpolation
        if bestLag > minLag && bestLag < maxLag - 1 {
            var correlations: [Float] = [0, 0, 0]
            
            for offset in -1...1 {
                let lag = bestLag + offset
                var correlation: Float = 0
                for i in 0..<(sampleCount - lag) {
                    correlation += normalizedSamples[i] * normalizedSamples[i + lag]
                }
                correlation /= Float(sampleCount - lag)
                correlations[offset + 1] = correlation
            }
            
            // Parabolic interpolation
            let y1 = correlations[0]
            let y2 = correlations[1]
            let y3 = correlations[2]
            
            let denom = 2 * (2 * y2 - y1 - y3)
            if abs(denom) > 0.0001 {
                let offset = (y3 - y1) / denom
                let refinedLag = Double(bestLag) + Double(offset)
                return sampleRate / refinedLag
            }
        }
        
        // Fallback to basic calculation
        return sampleRate / Double(bestLag)
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
            self.cents = max(-50, min(50, cents))
        }
        
        // Format note with octave
        self.note = "\(closestNote)\(closestOctave)"
    }
}
