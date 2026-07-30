//
//  MetronomeAudio.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Foundation

enum MetronomeAudio {
    static let sampleRate = 44_100.0
    static let maximumSampleMagnitude: Float = 0.97
    /// Peak every click is normalized to, so all sounds are equally loud.
    static let normalizedPeak = 0.95
    /// Saturation amount applied after normalization: raises perceived loudness
    /// (more energy per click) without pushing the peak past `normalizedPeak`.
    private static let saturationDrive = 2.4
    /// Fade applied to the tail of a click so the buffer never ends mid-waveform.
    private static let releaseDuration = 0.004

    /// Player-node gain for a 0…1 user volume. Slightly convex so the low end of
    /// the slider stays usable while 100% stays at full output.
    static func playerVolume(for gain: Double) -> Float {
        let clamped = min(max(gain, 0), 1)
        return Float(pow(clamped, 1.2))
    }

    static func makeBuffer(for sound: MetronomeSound, gain: Double) -> AVAudioPCMBuffer? {
        let specification = specification(for: sound)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            return nil
        }

        let frameCount = AVAudioFrameCount((sampleRate * specification.duration).rounded(.up))
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else {
            return nil
        }

        buffer.frameLength = frameCount

        var rendered = [Double](repeating: 0, count: Int(frameCount))
        var peak = 0.0
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            var sample = 0.0
            for (index, frequency) in specification.frequencies.enumerated() {
                sample += sin(2 * .pi * frequency * time) / Double(index + 1)
            }
            if specification.noiseMix > 0 {
                let deterministicNoise = sin(Double(frame) * 12_989 + 78_233) * 43_758.5453
                sample += (deterministicNoise - floor(deterministicNoise) - 0.5) * specification.noiseMix
            }
            let attack = min(1, time * specification.attackRate)
            let release = releaseGain(time: time, duration: specification.duration)
            let value = sample * attack * exp(-time * specification.decayRate) * release
            rendered[frame] = value
            peak = max(peak, abs(value))
        }

        let normalization = peak > 0 ? 1 / peak : 0
        let amplitude = normalizedPeak * min(max(gain, 0), 1)
        for frame in 0..<Int(frameCount) {
            let shaped = saturate(rendered[frame] * normalization) * amplitude
            samples[frame] = Float(max(
                -Double(maximumSampleMagnitude),
                min(Double(maximumSampleMagnitude), shaped)
            ))
        }

        return buffer
    }

    /// Soft clipper normalized so an input of ±1 maps to ±1.
    private static func saturate(_ value: Double) -> Double {
        tanh(saturationDrive * value) / tanh(saturationDrive)
    }

    private static func releaseGain(time: TimeInterval, duration: TimeInterval) -> Double {
        let release = min(releaseDuration, duration / 4)
        let remaining = duration - time
        guard release > 0, remaining < release else { return 1 }
        return max(0, remaining / release)
    }

    private static func specification(for sound: MetronomeSound) -> SoundSpecification {
        switch sound {
        case .click:
            return SoundSpecification(duration: 0.04, frequencies: [1_000, 2_000], decayRate: 80)
        case .woodBlock:
            return SoundSpecification(duration: 0.08, frequencies: [420, 760, 1_180], decayRate: 45)
        case .bell:
            return SoundSpecification(duration: 0.14, frequencies: [600, 1_205, 1_810], decayRate: 22)
        case .beep:
            return SoundSpecification(duration: 0.06, frequencies: [880], decayRate: 40, attackRate: 800)
        case .tick:
            return SoundSpecification(duration: 0.03, frequencies: [2_000, 3_900], decayRate: 110)
        case .cowbell:
            return SoundSpecification(duration: 0.12, frequencies: [800, 1_180, 1_600], decayRate: 24)
        case .triangle:
            return SoundSpecification(duration: 0.18, frequencies: [1_200, 2_410, 3_615], decayRate: 18)
        case .marimba:
            return SoundSpecification(duration: 0.2, frequencies: [300, 600, 1_200], decayRate: 13, attackRate: 120)
        case .drum:
            return SoundSpecification(duration: 0.14, frequencies: [100, 205], decayRate: 18, noiseMix: 0.35)
        case .chimes:
            return SoundSpecification(duration: 0.24, frequencies: [500, 1_005, 1_515, 2_030], decayRate: 11)
        }
    }

    private struct SoundSpecification {
        let duration: TimeInterval
        let frequencies: [Double]
        let decayRate: Double
        var attackRate: Double = 2_000
        var noiseMix: Double = 0
    }
}

extension Metronome {
    func setupAudioSession() -> MetronomeStartupError? {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
            return nil
        } catch {
            return .audioSessionFailed(error.localizedDescription)
        }
    }

    func setupAudioPlayer() -> MetronomeStartupError? {
        stopAudioEngine()

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        audioEngine = engine
        playerNode = player
        engine.attach(player)

        guard makeClickBuffers() else {
            stopAudioEngine()
            return .audioBuffersUnavailable
        }
        guard let accentBuffer else {
            stopAudioEngine()
            return .audioBuffersUnavailable
        }

        engine.connect(player, to: engine.mainMixerNode, format: accentBuffer.format)
        engine.mainMixerNode.outputVolume = 1
        applyVolume(SettingsManager.shared.settings.metronomeVolume)
        engine.prepare()
        return nil
    }

    /// Renders the accent and normal clicks at full scale. User volume is applied
    /// on the player node so changing it never rebuilds the audio graph.
    @discardableResult
    func makeClickBuffers() -> Bool {
        let settings = SettingsManager.shared
        guard let accent = MetronomeAudio.makeBuffer(
            for: settings.metronomeEmphasizedSoundEnum,
            gain: 1
        ), let normal = MetronomeAudio.makeBuffer(
            for: settings.metronomeNonEmphasizedSoundEnum,
            gain: 1
        ) else {
            return false
        }

        accentBuffer = accent
        normalBuffer = normal
        accentBufferConverted = accent
        normalBufferConverted = normal
        return true
    }

    func applyVolume(_ gain: Double) {
        playerNode?.volume = MetronomeAudio.playerVolume(for: gain)
    }

    /// Swaps in freshly rendered clicks and re-queues upcoming beats, keeping the
    /// existing beat timeline so the tempo and downbeat do not jump.
    func reloadClickSounds() {
        guard makeClickBuffers() else {
            if isPlaying {
                failPlayback(with: .audioBuffersUnavailable)
            }
            return
        }
        // Drops beats already queued with the previous sounds, then re-queues them.
        resyncScheduledBeats()
    }

    func stopAudioEngine() {
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
}
