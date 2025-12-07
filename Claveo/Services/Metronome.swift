//
//  Metronome.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import AVFoundation
import Foundation
import Combine
import UIKit
import QuartzCore

enum MetronomeSound: String, CaseIterable {
    case click = "Click"
    case woodBlock = "Wood Block"
    case bell = "Bell"
    case beep = "Beep"
    case tick = "Tick"
}

@MainActor
class Metronome: ObservableObject {
    @Published var isPlaying = false
    @Published var tempo: Int = 120 {
        didSet {
            updateInterval()
            // Restart timer if playing to apply new tempo immediately
            if isPlaying {
                restartTimer()
            }
        }
    }
    @Published var timeSignature: TimeSignature = .fourFour
    @Published var beatPattern: [Bool] = [true, false, false, false] {
        didSet {
            // Ensure at least one beat is accented
            if !beatPattern.contains(true) {
                beatPattern[0] = true
            }
        }
    }
    @Published var currentBeat: Int = 0
    @Published var soundType: MetronomeSound = .click {
        didSet {
            // Recreate audio players when sound changes
            if isPlaying {
                setupAudioPlayer()
            }
        }
    }
    @Published var hapticEnabled: Bool = true
    
    private var timer: Timer?
    private var interval: TimeInterval = 0.5
    private var nextBeatTime: TimeInterval = 0
    private var startTime: TimeInterval = 0
    private var beatCount: Int = 0
    private var lastBeatTime: TimeInterval = 0
    private var isPlayingBeat: Bool = false
    private var scheduledBeatCount: Int = 0 // Track how many beats we've pre-scheduled
    private let beatsToScheduleAhead = 4 // Pre-schedule 4 beats ahead
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let hapticGeneratorLight = UIImpactFeedbackGenerator(style: .light)
    
    init() {
        let settings = SettingsManager.shared.settings
        
        // Load default tempo
        if settings.defaultMetronomeTempo > 0 {
            tempo = settings.defaultMetronomeTempo
        }
        
        // Load saved preferences
        if let sound = MetronomeSound(rawValue: settings.metronomeSound) {
            soundType = sound
        }
        hapticEnabled = settings.metronomeHapticEnabled
        
        updateInterval()
        updateBeatPattern()
        
        // Prepare haptic generators
        hapticGenerator.prepare()
        hapticGeneratorLight.prepare()
    }
    
    // Use AVAudioEngine for precise, sample-accurate timing
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var accentBuffer: AVAudioPCMBuffer?
    private var normalBuffer: AVAudioPCMBuffer?
    private var accentBufferConverted: AVAudioPCMBuffer? // Pre-converted buffers
    private var normalBufferConverted: AVAudioPCMBuffer? // Pre-converted buffers
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .playback with low latency options for precise timing
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005) // 5ms buffer for low latency
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("Failed to setup audio session: \(error)")
            #endif
        }
    }
    
    private func setupAudioPlayer() {
        // Stop and remove existing engine
        stopAudioEngine()
        
        // Setup AVAudioEngine first to get the output format
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else { return }
        
        // Attach player node to engine
        engine.attach(player)
        
        // Connect to main mixer - use the engine's output format
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        engine.connect(player, to: mainMixer, format: outputFormat)
        
        // Create audio buffers from sound data, converting to match engine format
        let (accentSound, normalSound) = createSounds(for: soundType)
        accentBuffer = createAudioBuffer(from: accentSound, targetFormat: outputFormat)
        normalBuffer = createAudioBuffer(from: normalSound, targetFormat: outputFormat)
        
        // Pre-convert buffers to avoid conversion delay during playback
        accentBufferConverted = accentBuffer
        normalBufferConverted = normalBuffer
        
        // Prepare engine
        engine.prepare()
    }
    
    private func createAudioBuffer(from wavData: Data, targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        // Write WAV data to temporary file and read with AVAudioFile
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("metronome_temp_\(UUID().uuidString).wav")
        
        do {
            try wavData.write(to: tempURL)
            defer {
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
            }
            
            // Read audio file
            let audioFile = try AVAudioFile(forReading: tempURL)
            let sourceFormat = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            
            // Read into source format buffer first
            guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
                return nil
            }
            
            try audioFile.read(into: sourceBuffer)
            
            // If formats match, return source buffer
            if sourceFormat.isEqual(targetFormat) {
                return sourceBuffer
            }
            
            // Convert to target format
            return convertBuffer(sourceBuffer, to: targetFormat)
        } catch {
            #if DEBUG
            print("Failed to create audio buffer: \(error)")
            #endif
            return nil
        }
    }
    
    private func stopAudioEngine() {
        playerNode?.stop()
        playerNode?.reset()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        accentBuffer = nil
        normalBuffer = nil
        accentBufferConverted = nil
        normalBufferConverted = nil
    }
    
    private func createSounds(for type: MetronomeSound) -> (Data, Data) {
        switch type {
        case .click:
            // Precise click: short, consistent, no randomness
            let accent = createPreciseClickSound(frequency: 1000.0, volume: 0.5)
            let normal = createPreciseClickSound(frequency: 1200.0, volume: 0.3)
            return (accent, normal)
            
        case .woodBlock:
            // Wood block: short, sharp attack
            let accent = createPreciseClickSound(frequency: 400.0, volume: 0.6)
            let normal = createPreciseClickSound(frequency: 600.0, volume: 0.35)
            return (accent, normal)
            
        case .bell:
            // Bell: short with harmonics but very brief
            let accent = createShortBellSound(frequency: 600.0, volume: 0.5)
            let normal = createShortBellSound(frequency: 800.0, volume: 0.3)
            return (accent, normal)
            
        case .beep:
            // Simple beep: pure tone, very short
            let accent = createPreciseClickSound(frequency: 880.0, volume: 0.5)
            let normal = createPreciseClickSound(frequency: 1100.0, volume: 0.3)
            return (accent, normal)
            
        case .tick:
            // Tick: very short, high frequency
            let accent = createPreciseClickSound(frequency: 2000.0, volume: 0.4)
            let normal = createPreciseClickSound(frequency: 2400.0, volume: 0.25)
            return (accent, normal)
        }
    }
    
    // Precise click sound - very short, consistent, no randomness for perfect timing
    private func createPreciseClickSound(frequency: Double = 1000.0, volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.01 // Very short (10ms) for precise timing
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else {
            return Data()
        }
        
        // Create precise click with no randomness - deterministic for consistent timing
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            
            // Simple sine wave with one harmonic for clarity
            let fundamental = sin(2.0 * Double.pi * frequency * t)
            let harmonic = 0.3 * sin(2.0 * Double.pi * frequency * 2.0 * t)
            
            // Very fast exponential decay envelope (no attack phase needed)
            let envelope = exp(-t * 100.0) // Very fast decay for sharp click
            
            let sample = (fundamental + harmonic) * envelope * volume
            
            // Clamp to prevent clipping
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }
        
        return convertPCMBufferToWAV(buffer)
    }
    
    // Short bell sound - brief harmonic sound
    private func createShortBellSound(frequency: Double = 600.0, volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.015 // Very short (15ms) for precise timing
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else {
            return Data()
        }
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            
            // Multiple harmonics for bell-like character but very brief
            let fundamental = sin(2.0 * Double.pi * frequency * t)
            let harmonic2 = 0.4 * sin(2.0 * Double.pi * frequency * 2.0 * t)
            let harmonic3 = 0.2 * sin(2.0 * Double.pi * frequency * 3.0 * t)
            
            // Fast exponential decay
            let envelope = exp(-t * 60.0)
            
            let sample = (fundamental + harmonic2 + harmonic3) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }
        
        return convertPCMBufferToWAV(buffer)
    }
    
    private func convertPCMBufferToWAV(_ buffer: AVAudioPCMBuffer) -> Data {
        let format = buffer.format
        let sampleRate = format.sampleRate
        let channels = format.channelCount
        let bitsPerSample: UInt16 = 16
        
        guard let channelData = buffer.floatChannelData else {
            return Data()
        }
        
        let frameCount = Int(buffer.frameLength)
        var audioData = [Int16]()
        
        // Convert float samples to Int16
        for i in 0..<frameCount {
            let sample = channelData[0][i]
            let intSample = Int16(max(-1.0, min(1.0, sample)) * Float(Int16.max))
            audioData.append(intSample)
        }
        
        let dataSize = UInt32(audioData.count * MemoryLayout<Int16>.size)
        let fileSize = 36 + dataSize
        
        var wavData = Data()
        
        // WAV header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        
        let channelsUInt = UInt16(channels)
        let byteRate = UInt32(sampleRate * Double(channelsUInt) * Double(bitsPerSample) / 8.0)
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        
        let blockAlign = UInt16(channelsUInt * bitsPerSample / 8)
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        wavData.append("data".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        
        // Audio data
        audioData.withUnsafeBytes { buffer in
            wavData.append(contentsOf: buffer)
        }
        
        return wavData
    }
    
    
    private func updateInterval() {
        interval = 60.0 / Double(tempo)
    }
    
    func updateBeatPattern() {
        beatPattern = Array(repeating: false, count: timeSignature.beatsPerMeasure)
        beatPattern[0] = true // First beat always accented
    }
    
    func start() {
        guard !isPlaying else { return }
        
        // Setup audio session and player when starting
        setupAudioSession()
        setupAudioPlayer()
        
        // Start audio engine
        guard let engine = audioEngine, let player = playerNode else { return }
        do {
            try engine.start()
            player.play()
        } catch {
            #if DEBUG
            print("Failed to start audio engine: \(error)")
            #endif
            return
        }
        
        isPlaying = true
        currentBeat = -1 // Start at -1 so first beat will be 0
        beatCount = 0
        isPlayingBeat = false // Reset flag
        
        // Initialize timing with precise absolute time
        let now = CACurrentMediaTime()
        startTime = now
        nextBeatTime = now
        lastBeatTime = 0 // Reset last beat time
        
        // Pre-schedule beats ahead of time for sample-accurate timing
        scheduleBeatsAhead()
        
        startTimer()
        // Play first beat immediately
        isPlayingBeat = true
        lastBeatTime = now
        beatCount = 1
        scheduledBeatCount = 1
        nextBeatTime = startTime + interval
        // Reset flag after first beat
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            self?.isPlayingBeat = false
        }
    }
    
    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        currentBeat = 0
        
        // Stop audio engine
        stopAudioEngine()
    }
        
    private func startTimer() {
        timer?.invalidate()
        
        // Use a single Timer for timing - checking frequently enough to catch beats accurately
        // Check at least 20x per beat interval for precision (more frequent = better accuracy)
        // Using only Timer (not CADisplayLink) to avoid double-triggering
        let timerInterval = min(interval / 20.0, 0.025) // Check 20x per beat or every 25ms max
        timer = Timer(timeInterval: timerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying else { return }
                self.checkAndPlayBeat()
            }
        }
        
        guard let timer = timer else { return }
        // Add to common modes for better timing accuracy
        RunLoop.current.add(timer, forMode: .common)
        RunLoop.current.add(timer, forMode: .tracking)
    }
    
    private func scheduleBeatsAhead() {
        guard let player = playerNode, let engine = audioEngine else { return }
        
        let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        let _ = outputFormat.sampleRate
        
        // Schedule beats ahead using sample-accurate timing
        for i in 0..<beatsToScheduleAhead {
            let beatNumber = scheduledBeatCount + i
            let beatTimeInSeconds = startTime + (Double(beatNumber) * interval)
            
            // Convert to host time for precise scheduling
            let beatHostTime = AVAudioTime.hostTime(forSeconds: beatTimeInSeconds)
            
            // Determine if this beat should be accented
            let beatInMeasure = beatNumber % timeSignature.beatsPerMeasure
            let isAccent = beatInMeasure < beatPattern.count && beatPattern[beatInMeasure]
            
            // Get the appropriate buffer
            let buffer = isAccent ? accentBufferConverted : normalBufferConverted
            guard let audioBuffer = buffer else { continue }
            
            // Create AVAudioTime for this beat using the output format
            // This ensures the time is in the correct format for scheduling
            let audioTime = AVAudioTime(hostTime: beatHostTime)
            
            // Schedule buffer at precise audio time
            // The buffer format must match the connection format
            player.scheduleBuffer(audioBuffer, at: audioTime, options: [], completionHandler: nil)
        }
        
        scheduledBeatCount += beatsToScheduleAhead
    }
    
    private func checkAndPlayBeat() {
        // This function now maintains the schedule and updates UI
        guard !isPlayingBeat else { return }
        
        let currentTime = CACurrentMediaTime()
        
        // Check if we need to schedule more beats ahead
        let beatsAhead = scheduledBeatCount - beatCount
        if beatsAhead < 2 {
            // Schedule more beats ahead
            scheduleBeatsAhead()
        }
        
        // Update beat counter for UI when it's time
        if currentTime >= nextBeatTime - 0.001 {
            isPlayingBeat = true
            lastBeatTime = currentTime
            beatCount += 1
            
            // Update currentBeat for UI (wraps around)
            currentBeat = (beatCount - 1) % timeSignature.beatsPerMeasure
            
            // Haptic feedback
            if hapticEnabled {
                let isAccent = currentBeat < beatPattern.count && beatPattern[currentBeat]
                if isAccent {
                    hapticGenerator.impactOccurred(intensity: 1.0)
                } else {
                    hapticGeneratorLight.impactOccurred(intensity: 0.5)
                }
            }
            
            // Calculate next beat time for UI updates
            nextBeatTime = startTime + (Double(beatCount) * interval)
            
            // Reset flag
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) { [weak self] in
                self?.isPlayingBeat = false
            }
        }
    }
    
    private func restartTimer() {
        guard isPlaying else { return }
        let currentTime = CACurrentMediaTime()
        startTime = currentTime
        nextBeatTime = currentTime
        beatCount = 0
        scheduledBeatCount = 0
        lastBeatTime = 0
        isPlayingBeat = false
        
        // Stop and reset player to clear scheduled buffers
        playerNode?.stop()
        playerNode?.reset()
        playerNode?.play()
        
        // Re-schedule beats ahead
        scheduleBeatsAhead()
        
        startTimer()
        beatCount = 1
        scheduledBeatCount = beatsToScheduleAhead
        nextBeatTime = startTime + interval
    }
    
    private func playBeat() {
        // Update beat counter FIRST, then play
        // This wraps around: 0,1,2,3 -> 0,1,2,3...
        currentBeat = (currentBeat + 1) % timeSignature.beatsPerMeasure
        
        // Determine if this beat should be accented
        let isAccent = currentBeat < beatPattern.count && beatPattern[currentBeat]
        
        // Haptic feedback - do this synchronously before audio
        if hapticEnabled {
            if isAccent {
                hapticGenerator.impactOccurred(intensity: 1.0)
            } else {
                hapticGeneratorLight.impactOccurred(intensity: 0.5)
            }
        }
        
        // Play appropriate sound using AVAudioEngine for precise timing
        guard let player = playerNode else { return }
        
        // Use pre-converted buffers to avoid any conversion delay
        let audioBuffer = isAccent ? accentBufferConverted : normalBufferConverted
        guard let buffer = audioBuffer else { return }
        
        // Schedule the buffer to play immediately (sample-accurate timing)
        // Using pre-converted buffers ensures zero conversion delay
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
    
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        // If formats match, return original buffer
        if buffer.format.isEqual(format) {
            return buffer
        }
        
        // Create converter
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            return nil
        }
        
        // Calculate output capacity
        let inputSampleRate = buffer.format.sampleRate
        let outputSampleRate = format.sampleRate
        let ratio = outputSampleRate / inputSampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputCapacity) else {
            return nil
        }
        
        // Convert
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            #if DEBUG
            print("Buffer conversion error: \(error)")
            #endif
            return nil
        }
        
        return outputBuffer
    }
    
    func savePreferences() {
        SettingsManager.shared.setMetronomeSound(soundType)
        SettingsManager.shared.update(\.metronomeHapticEnabled, value: hapticEnabled)
    }
    
    func setTimeSignature(_ signature: TimeSignature) {
        timeSignature = signature
        updateBeatPattern()
        // Reset beat counter if playing to stay in sync
        if isPlaying {
            currentBeat = 0
        }
    }
}

enum TimeSignature: String, CaseIterable {
    case twoTwo = "2/2"
    case threeFour = "3/4"
    case fourFour = "4/4"
    case fiveFour = "5/4"
    case sixEight = "6/8"
    case nineEight = "9/8"
    
    var beatsPerMeasure: Int {
        switch self {
        case .twoTwo: return 2
        case .threeFour: return 3
        case .fourFour: return 4
        case .fiveFour: return 5
        case .sixEight: return 6
        case .nineEight: return 9
        }
    }
}

