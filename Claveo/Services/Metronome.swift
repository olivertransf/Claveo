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
    private var displayLink: CADisplayLink?
    private var interval: TimeInterval = 0.5
    private var nextBeatTime: TimeInterval = 0
    private var startTime: TimeInterval = 0
    
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
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .playback for lower latency and better timing
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("Failed to setup audio session: \(error)")
            #endif
        }
    }
    
    // Use multiple players to avoid latency from reusing the same player
    private var accentPlayers: [AVAudioPlayer] = []
    private var normalPlayers: [AVAudioPlayer] = []
    private var accentPlayerIndex = 0
    private var normalPlayerIndex = 0
    
    private func setupAudioPlayer() {
        let (accentSound, normalSound) = createSounds(for: soundType)
        
        // Create multiple players for each sound to avoid latency
        accentPlayers.removeAll()
        normalPlayers.removeAll()
        
        do {
            // Create 4 players for each sound type for better timing
            for _ in 0..<4 {
                let accent = try AVAudioPlayer(data: accentSound)
                accent.prepareToPlay()
                accent.enableRate = false
                accentPlayers.append(accent)
                
                let normal = try AVAudioPlayer(data: normalSound)
                normal.prepareToPlay()
                normal.enableRate = false
                normalPlayers.append(normal)
            }
        } catch {
            #if DEBUG
            print("Failed to create metronome audio players: \(error.localizedDescription)")
            #endif
        }
    }
    
    private func createSounds(for type: MetronomeSound) -> (Data, Data) {
        switch type {
        case .click:
            // Original click sounds
            let accent = createClickSound(frequency: 200.0, volume: 0.6)
            let normal = createClickSound(frequency: 800.0, volume: 0.25)
            return (accent, normal)
            
        case .woodBlock:
            // Wood block: lower frequency, sharper attack
            let accent = createWoodBlockSound(frequency: 150.0, volume: 0.7)
            let normal = createWoodBlockSound(frequency: 300.0, volume: 0.4)
            return (accent, normal)
            
        case .bell:
            // Bell: harmonic-rich, longer decay
            let accent = createBellSound(frequency: 400.0, volume: 0.5)
            let normal = createBellSound(frequency: 600.0, volume: 0.3)
            return (accent, normal)
            
        case .beep:
            // Simple beep: pure tone
            let accent = createBeepSound(frequency: 440.0, volume: 0.6)
            let normal = createBeepSound(frequency: 880.0, volume: 0.3)
            return (accent, normal)
            
        case .tick:
            // Tick: very short, high frequency
            let accent = createTickSound(frequency: 1000.0, volume: 0.5)
            let normal = createTickSound(frequency: 1200.0, volume: 0.25)
            return (accent, normal)
        }
    }
    
    private func createClickSound(frequency: Double = 1000.0, volume: Double = 0.3) -> Data {
        // Create audio format for the drum-like click sound
        let sampleRate = 44100.0
        let duration = 0.05 // Shorter for better timing
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else {
            return Data()
        }
        
        // Create drum-like sound with multiple frequencies and noise
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            
            // Base frequency (fundamental)
            let fundamental = sin(2.0 * Double.pi * frequency * t)
            
            // Add harmonics for richer sound
            let harmonic2 = 0.5 * sin(2.0 * Double.pi * frequency * 2.0 * t)
            let harmonic3 = 0.25 * sin(2.0 * Double.pi * frequency * 3.0 * t)
            
            // Add some noise for percussive character
            let noise = (Double.random(in: -0.1...0.1))
            
            // Combine components
            var sample = fundamental + harmonic2 + harmonic3 + noise
            
            // Apply exponential decay envelope for drum-like attack and decay
            let attackTime = 0.005 // 5ms attack
            let decayTime = duration - attackTime
            let envelope: Double
            if t < attackTime {
                // Quick attack
                envelope = t / attackTime
            } else {
                // Exponential decay
                let decayProgress = (t - attackTime) / decayTime
                envelope = exp(-decayProgress * 8.0) // Fast decay
            }
            
            sample = sample * envelope * volume
            
            // Clamp to prevent clipping
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }
        
        // Convert to WAV format for AVAudioPlayer
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
    
    // Wood block sound - sharper attack, shorter decay
    private func createWoodBlockSound(frequency: Double = 200.0, volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.03 // Very short for precise timing
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else { return Data() }
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            
            // Sharp attack with quick decay
            let envelope = exp(-t * 30.0) // Very fast decay
            let fundamental = sin(2.0 * Double.pi * frequency * t)
            let harmonic = 0.3 * sin(2.0 * Double.pi * frequency * 2.5 * t)
            
            // Add noise for percussive character
            let noise = Double.random(in: -0.05...0.05)
            
            let sample = (fundamental + harmonic + noise) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }
        
        return convertPCMBufferToWAV(buffer)
    }
    
    // Bell sound - harmonic-rich, shorter for better timing
    private func createBellSound(frequency: Double = 440.0, volume: Double = 0.4) -> Data {
        let sampleRate = 44100.0
        let duration = 0.08 // Shorter for better timing
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else { return Data() }
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            
            // Multiple harmonics for bell-like sound
            let fundamental = sin(2.0 * Double.pi * frequency * t)
            let harmonic2 = 0.5 * sin(2.0 * Double.pi * frequency * 2.0 * t)
            let harmonic3 = 0.25 * sin(2.0 * Double.pi * frequency * 3.0 * t)
            let harmonic5 = 0.15 * sin(2.0 * Double.pi * frequency * 5.0 * t)
            
            // Exponential decay
            let envelope = exp(-t * 8.0)
            
            let sample = (fundamental + harmonic2 + harmonic3 + harmonic5) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }
        
        return convertPCMBufferToWAV(buffer)
    }
    
    // Simple beep - pure tone
    private func createBeepSound(frequency: Double = 440.0, volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.04 // Shorter for better timing
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else { return Data() }
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 10.0) // Quick decay
            let sample = sin(2.0 * Double.pi * frequency * t) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }
        
        return convertPCMBufferToWAV(buffer)
    }
    
    // Tick sound - very short, high frequency
    private func createTickSound(frequency: Double = 1000.0, volume: Double = 0.4) -> Data {
        let sampleRate = 44100.0
        let duration = 0.02 // Very short
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else { return Data() }
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 50.0) // Very fast decay
            let sample = sin(2.0 * Double.pi * frequency * t) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }
        
        return convertPCMBufferToWAV(buffer)
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
        
        isPlaying = true
        currentBeat = -1 // Start at -1 so first beat will be 0
        
        // Initialize timing
        startTime = CACurrentMediaTime()
        nextBeatTime = startTime
        
        startTimer()
        playBeat() // Play first beat immediately
    }
    
    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        displayLink?.invalidate()
        displayLink = nil
        currentBeat = 0
    }
        
    private func startTimer() {
        timer?.invalidate()
        displayLink?.invalidate()
        
        // Use Timer with high precision for metronome timing
        timer = Timer(timeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self, self.isPlaying else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                self.playBeat()
            }
        }
        
        // Add to common run loop modes for better timing accuracy
        guard let timer = timer else { return }
        RunLoop.current.add(timer, forMode: .common)
        RunLoop.current.add(timer, forMode: .tracking)
    }
    
    private func restartTimer() {
        guard isPlaying else { return }
        startTime = CACurrentMediaTime()
        nextBeatTime = startTime
        startTimer()
    }
    
    private func playBeat() {
        // Update beat counter FIRST, then play
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
        
        // Play appropriate sound with minimal latency
        let players = isAccent ? accentPlayers : normalPlayers
        guard !players.isEmpty else {
            #if DEBUG
            print("Metronome: audio players are empty")
            #endif
            return
        }
        
        // Use round-robin to avoid latency from reusing the same player
        let index = isAccent ? accentPlayerIndex : normalPlayerIndex
        let player = players[index % players.count]
        
        if isAccent {
            accentPlayerIndex = (accentPlayerIndex + 1) % accentPlayers.count
        } else {
            normalPlayerIndex = (normalPlayerIndex + 1) % normalPlayers.count
        }
        
        // Reset and play immediately - critical for timing
        if player.isPlaying {
            player.stop()
        }
        player.currentTime = 0
        // Play synchronously for better timing
        player.play()
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

