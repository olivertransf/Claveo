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
    static let normalizedPeak = 0.97
    /// Saturation amount applied after normalization: raises perceived loudness
    /// (more energy per click) without pushing the peak past `normalizedPeak`.
    private static let saturationDrive = 3.4
    /// Fade applied to the tail of a click so the buffer never ends mid-waveform.
    private static let releaseDuration = 0.004

    /// Player-node gain for a 0…1 user volume. Slightly convex so the low end of
    /// the slider stays usable while 100% stays at full output.
    static func playerVolume(for gain: Double) -> Float {
        let clamped = min(max(gain, 0), 1)
        return Float(pow(clamped, 0.7))
    }

    static func makeBuffer(for sound: MetronomeSound, gain: Double) -> AVAudioPCMBuffer? {
        if let sample = sound.sampleResource {
            return makeSampleBuffer(sample, gain: gain)
        }
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
            return SoundSpecification(duration: 0.045, frequencies: [1_000, 2_000], decayRate: 64)
        case .woodBlock:
            return SoundSpecification(duration: 0.09, frequencies: [420, 760, 1_180], decayRate: 36)
        case .bell:
            return SoundSpecification(duration: 0.16, frequencies: [600, 1_205, 1_810], decayRate: 18)
        case .beep:
            return SoundSpecification(duration: 0.07, frequencies: [880], decayRate: 32, attackRate: 800)
        case .tick:
            return SoundSpecification(duration: 0.035, frequencies: [2_000, 3_900], decayRate: 88)
        case .cowbell:
            return SoundSpecification(duration: 0.13, frequencies: [800, 1_180, 1_600], decayRate: 19)
        case .triangle:
            return SoundSpecification(duration: 0.2, frequencies: [1_200, 2_410, 3_615], decayRate: 14)
        case .marimba:
            return SoundSpecification(duration: 0.22, frequencies: [300, 600, 1_200], decayRate: 10, attackRate: 120)
        case .drum:
            return SoundSpecification(duration: 0.16, frequencies: [100, 205], decayRate: 14, noiseMix: 0.35)
        case .chimes:
            return SoundSpecification(duration: 0.26, frequencies: [500, 1_005, 1_515, 2_030], decayRate: 9)
        case .clickKicker, .keys:
            return SoundSpecification(duration: 0.05, frequencies: [1_000], decayRate: 40)
        }
    }

    private static func makeSampleBuffer(
        _ sample: (name: String, ext: String, trimSilence: Bool, maxDuration: TimeInterval?),
        gain: Double
    ) -> AVAudioPCMBuffer? {
        guard let url = bundledSampleURL(name: sample.name, extension: sample.ext),
              let file = try? AVAudioFile(forReading: url),
              let target = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
              ),
              file.length > 0,
              let raw = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
              ) else {
            return nil
        }
        do {
            try file.read(into: raw)
        } catch {
            return nil
        }
        guard let converted = convert(raw, to: target) else { return nil }
        let source = monoSamples(from: converted)
        let trimmed = trim(
            source,
            sampleRate: target.sampleRate,
            trimSilence: sample.trimSilence,
            maxDuration: sample.maxDuration
        )
        guard !trimmed.isEmpty else { return nil }
        return render(trimmed, sampleRate: target.sampleRate, gain: gain)
    }

    private static func bundledSampleURL(name: String, extension ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        return Bundle(identifier: "com.olivertran.Claveo")?.url(forResource: name, withExtension: ext)
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
        guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var error: NSError?
        var supplied = false
        let input = buffer
        converter.convert(to: converted, error: &error) { _, status in
            if supplied {
                status.pointee = .endOfStream
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return input
        }
        guard error == nil, converted.frameLength > 0 else { return nil }
        return converted
    }

    private static func monoSamples(from buffer: AVAudioPCMBuffer) -> [Double] {
        guard let channels = buffer.floatChannelData else { return [] }
        let count = Int(buffer.frameLength)
        var samples = [Double](repeating: 0, count: count)
        let channelCount = Int(buffer.format.channelCount)
        for frame in 0..<count {
            var mixed = 0.0
            for channel in 0..<max(channelCount, 1) {
                mixed += Double(channels[channel][frame])
            }
            samples[frame] = mixed / Double(max(channelCount, 1))
        }
        return samples
    }

    private static func trim(
        _ samples: [Double],
        sampleRate: Double,
        trimSilence: Bool,
        maxDuration: TimeInterval?
    ) -> [Double] {
        var start = 0
        if trimSilence {
            let threshold = 0.02
            start = samples.firstIndex { abs($0) >= threshold } ?? 0
            let lead = Int(0.01 * sampleRate)
            start = max(0, start - lead)
        }
        var end = samples.count
        if let maxDuration {
            end = min(samples.count, start + Int((maxDuration * sampleRate).rounded(.up)))
        }
        guard start < end else { return [] }
        return Array(samples[start..<end])
    }

    private static func render(_ samples: [Double], sampleRate: Double, gain: Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let peak = samples.map(abs).max() ?? 0
        let normalization = peak > 0 ? 1 / peak : 0
        let amplitude = normalizedPeak * min(max(gain, 0), 1)
        let releaseFrames = max(1, Int((releaseDuration * sampleRate).rounded(.up)))
        for frame in 0..<samples.count {
            let remaining = samples.count - 1 - frame
            let release = remaining < releaseFrames
                ? Double(remaining) / Double(releaseFrames)
                : 1
            let shaped = samples[frame] * normalization * amplitude * release
            channel[frame] = Float(max(
                -Double(maximumSampleMagnitude),
                min(Double(maximumSampleMagnitude), shaped)
            ))
        }
        if samples.count > 0 {
            channel[samples.count - 1] = 0
        }
        return buffer
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
    func setupAudioSession() async -> MetronomeStartupError? {
        do {
            try await Task.detached {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setPreferredIOBufferDuration(0.005)
                try await AudioSessionActivation.activate(session)
            }.value
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
    /// Sounds are passed in because `SettingsManager.$settings` publishes on `willSet`:
    /// a subscriber that read the singleton back would still see the previous sounds.
    @discardableResult
    func makeClickBuffers(
        emphasized: MetronomeSound? = nil,
        normal normalSound: MetronomeSound? = nil
    ) -> Bool {
        let settings = SettingsManager.shared
        let resolvedNormal = normalSound ?? settings.metronomeNonEmphasizedSoundEnum
        guard let accent = MetronomeAudio.makeBuffer(
            for: emphasized ?? settings.metronomeEmphasizedSoundEnum,
            gain: 1
        ), let normal = MetronomeAudio.makeBuffer(
            for: resolvedNormal,
            gain: 1
        ), let quietNormal = MetronomeAudio.makeBuffer(
            for: resolvedNormal,
            gain: Double(MetronomeScheduledClick.subdivisionTickGain)
        ) else {
            return false
        }

        accentBuffer = accent
        normalBuffer = normal
        quietNormalBuffer = quietNormal
        accentBufferConverted = accent
        normalBufferConverted = normal
        quietNormalBufferConverted = quietNormal
        return true
    }

    func applyVolume(_ gain: Double) {
        playerNode?.volume = MetronomeAudio.playerVolume(for: gain)
    }

    /// Swaps in freshly rendered clicks and re-queues upcoming beats, keeping the
    /// existing beat timeline so the tempo and downbeat do not jump.
    func reloadClickSounds(
        emphasized: MetronomeSound? = nil,
        normal normalSound: MetronomeSound? = nil
    ) {
        guard makeClickBuffers(emphasized: emphasized, normal: normalSound) else {
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
        quietNormalBuffer = nil
        accentBufferConverted = nil
        normalBufferConverted = nil
        quietNormalBufferConverted = nil
    }
}
