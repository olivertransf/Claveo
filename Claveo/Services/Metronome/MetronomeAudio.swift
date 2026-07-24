//
//  MetronomeAudio.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Foundation

enum MetronomeAudio {
    static let sampleRate = 44_100.0
    static let maximumSampleMagnitude: Float = 0.9

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
        let outputGain = min(max(gain, 0) * 1.25, Double(maximumSampleMagnitude))
        let normalization = max(
            1,
            specification.frequencies.indices.reduce(0.0) {
                $0 + 1.0 / Double($1 + 1)
            }
        )

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            var sample = 0.0
            for (index, frequency) in specification.frequencies.enumerated() {
                sample += sin(2 * .pi * frequency * time) / Double(index + 1)
            }
            if specification.noiseMix > 0 {
                let deterministicNoise = sin(Double(frame * 12_989 + 78_233)) * 43_758.5453
                sample += (deterministicNoise - floor(deterministicNoise) - 0.5) * specification.noiseMix
            }
            let attack = min(1, time * specification.attackRate)
            let envelope = attack * exp(-time * specification.decayRate)
            let rendered = sample / normalization * envelope * outputGain
            samples[frame] = Float(max(
                -Double(maximumSampleMagnitude),
                min(Double(maximumSampleMagnitude), rendered)
            ))
        }

        return buffer
    }

    private static func specification(for sound: MetronomeSound) -> SoundSpecification {
        switch sound {
        case .click:
            return SoundSpecification(duration: 0.025, frequencies: [1_000, 2_000], decayRate: 110)
        case .woodBlock:
            return SoundSpecification(duration: 0.06, frequencies: [420, 760, 1_180], decayRate: 55)
        case .bell:
            return SoundSpecification(duration: 0.12, frequencies: [600, 1_205, 1_810], decayRate: 22)
        case .beep:
            return SoundSpecification(duration: 0.05, frequencies: [880], decayRate: 45, attackRate: 800)
        case .tick:
            return SoundSpecification(duration: 0.02, frequencies: [2_000, 3_900], decayRate: 140)
        case .cowbell:
            return SoundSpecification(duration: 0.1, frequencies: [800, 1_180, 1_600], decayRate: 24)
        case .triangle:
            return SoundSpecification(duration: 0.15, frequencies: [1_200, 2_410, 3_615], decayRate: 18)
        case .marimba:
            return SoundSpecification(duration: 0.18, frequencies: [300, 600, 1_200], decayRate: 13, attackRate: 120)
        case .drum:
            return SoundSpecification(duration: 0.12, frequencies: [100, 205], decayRate: 18, noiseMix: 0.35)
        case .chimes:
            return SoundSpecification(duration: 0.22, frequencies: [500, 1_005, 1_515, 2_030], decayRate: 11)
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

        let settings = SettingsManager.shared
        accentBuffer = MetronomeAudio.makeBuffer(
            for: settings.metronomeEmphasizedSoundEnum,
            gain: settings.settings.metronomeVolume
        )
        normalBuffer = MetronomeAudio.makeBuffer(
            for: settings.metronomeNonEmphasizedSoundEnum,
            gain: settings.settings.metronomeVolume
        )

        guard let accentBuffer, let normalBuffer else {
            stopAudioEngine()
            return .audioBuffersUnavailable
        }

        engine.connect(player, to: engine.mainMixerNode, format: accentBuffer.format)
        accentBufferConverted = accentBuffer
        normalBufferConverted = normalBuffer
        engine.prepare()
        return nil
    }

    func rebuildAudioBuffersAndReschedule() {
        guard isPlaying else { return }
        if let error = setupAudioPlayer() {
            failPlayback(with: error)
            return
        }
        do {
            try audioEngine?.start()
            playerNode?.play()
            restartTimer()
        } catch {
            failPlayback(with: .audioEngineFailed(error.localizedDescription))
        }
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
