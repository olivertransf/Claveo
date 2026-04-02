//
//  ShortIntervalNotePlayer.swift
//  Claveo
//
//  Plays two brief, decaying harmonic tones (not sustained sine) for interval ear training.
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Combine
import Foundation

enum IntervalEarTrainingPlaybackStyle: Sendable, Equatable {
    /// Both notes sound together in one short pluck.
    case simultaneous
    /// Lower note, longer silence, then upper note.
    case arpeggiated
}

/// Generates pluck notes with a few harmonics so they read as pitches, not drones.
enum ShortIntervalNoteSynthesizer {
    private static let noteSeconds = 0.46
    /// Gap between arpeggiated notes (scales with longer note length).
    private static let arpeggiatedGapSeconds = 0.35

    static func midiToHz(midi: Int, a4: Double) -> Double {
        a4 * pow(2.0, Double(midi - 69) / 12.0)
    }

    /// Mono samples for one decaying note (caller may duplicate to stereo).
    private static func renderNote(sampleRate: Double, midi: Int, a4: Double) -> [Float] {
        let n = max(1, Int(sampleRate * noteSeconds))
        let attackSamples = max(1, Int(sampleRate * 0.004))
        var out = [Float](repeating: 0, count: n)
        let hz = midiToHz(midi: midi, a4: a4)
        let twoPi = 2.0 * Double.pi
        var phase: Double = 0
        let inc = twoPi * hz / sampleRate

        for i in 0..<n {
            let t = Double(i) / sampleRate
            let attack = min(1.0, Double(i + 1) / Double(attackSamples))
            let decay = exp(-3.5 * t)
            let env = attack * decay

            let f1 = sin(phase)
            let f2 = sin(phase * 2)
            let f3 = sin(phase * 3)
            let f4 = sin(phase * 4)
            let sum = f1 + 0.42 * f2 + 0.28 * f3 + 0.14 * f4
            phase += inc
            if phase >= twoPi { phase -= twoPi }

            out[i] = Float(env * sum * 0.22)
        }
        return out
    }

    /// Two notes at once, shared envelope, scaled so the sum doesn’t clip.
    private static func renderSimultaneous(sampleRate: Double, lowerMidi: Int, upperMidi: Int, a4: Double) -> [Float] {
        if lowerMidi == upperMidi {
            return renderNote(sampleRate: sampleRate, midi: lowerMidi, a4: a4)
        }

        let n = max(1, Int(sampleRate * noteSeconds))
        let attackSamples = max(1, Int(sampleRate * 0.004))
        var out = [Float](repeating: 0, count: n)

        let hz1 = midiToHz(midi: lowerMidi, a4: a4)
        let hz2 = midiToHz(midi: upperMidi, a4: a4)
        let twoPi = 2.0 * Double.pi
        var ph1: Double = 0
        var ph2: Double = 0
        let inc1 = twoPi * hz1 / sampleRate
        let inc2 = twoPi * hz2 / sampleRate

        for i in 0..<n {
            let t = Double(i) / sampleRate
            let attack = min(1.0, Double(i + 1) / Double(attackSamples))
            let decay = exp(-3.5 * t)
            let env = attack * decay

            func harmonics(_ ph: Double) -> Double {
                sin(ph) + 0.42 * sin(ph * 2) + 0.28 * sin(ph * 3) + 0.14 * sin(ph * 4)
            }

            let sum = harmonics(ph1) + harmonics(ph2)
            ph1 += inc1
            ph2 += inc2
            if ph1 >= twoPi { ph1 -= twoPi }
            if ph2 >= twoPi { ph2 -= twoPi }

            out[i] = Float(env * sum * 0.11)
        }
        return out
    }

    private static func copyMono(_ samples: [Float], into buffer: AVAudioPCMBuffer, channelCount: Int) {
        guard let ch = buffer.floatChannelData else { return }
        for (idx, s) in samples.enumerated() {
            for c in 0..<channelCount {
                ch[c][idx] = s
            }
        }
    }

    static func makeStereoBuffer(
        lowerMidi: Int,
        upperMidi: Int,
        a4: Double,
        format: AVAudioFormat,
        style: IntervalEarTrainingPlaybackStyle
    ) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let chCount = Int(format.channelCount)

        switch style {
        case .simultaneous:
            let mono = renderSimultaneous(sampleRate: sr, lowerMidi: lowerMidi, upperMidi: upperMidi, a4: a4)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(mono.count)) else { return nil }
            buffer.frameLength = AVAudioFrameCount(mono.count)
            copyMono(mono, into: buffer, channelCount: chCount)
            return buffer

        case .arpeggiated:
            let note1 = renderNote(sampleRate: sr, midi: lowerMidi, a4: a4)
            let gapCount = max(1, Int(sr * arpeggiatedGapSeconds))
            let note2 = renderNote(sampleRate: sr, midi: upperMidi, a4: a4)
            let total = note1.count + gapCount + note2.count
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)) else { return nil }
            buffer.frameLength = AVAudioFrameCount(total)

            guard let channels = buffer.floatChannelData else { return nil }

            var idx = 0
            for s in note1 {
                for c in 0..<chCount {
                    channels[c][idx] = s
                }
                idx += 1
            }
            for _ in 0..<gapCount {
                for c in 0..<chCount {
                    channels[c][idx] = 0
                }
                idx += 1
            }
            for s in note2 {
                for c in 0..<chCount {
                    channels[c][idx] = s
                }
                idx += 1
            }
            return buffer
        }
    }
}

@MainActor
final class ShortIntervalNotePlayer: ObservableObject {
    @Published private(set) var isPlaying = false

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var outputFormat: AVAudioFormat?

    private func prepareSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("ShortIntervalNotePlayer: session \(error)")
            #endif
        }
    }

    private func ensureEngine() throws -> (AVAudioEngine, AVAudioPlayerNode, AVAudioFormat) {
        if let eng = engine, let node = playerNode, let fmt = outputFormat {
            return (eng, node, fmt)
        }
        prepareSession()
        let eng = AVAudioEngine()
        let node = AVAudioPlayerNode()
        eng.attach(node)
        let fmt = eng.mainMixerNode.outputFormat(forBus: 0)
        eng.connect(node, to: eng.mainMixerNode, format: fmt)
        try eng.start()
        engine = eng
        playerNode = node
        outputFormat = fmt
        return (eng, node, fmt)
    }

    /// Plays the interval: either both notes together or arpeggiated (low then high).
    func play(
        lowerMidi: Int,
        upperMidi: Int,
        a4Reference: Double,
        style: IntervalEarTrainingPlaybackStyle
    ) {
        let low = min(lowerMidi, upperMidi)
        let high = max(lowerMidi, upperMidi)

        do {
            let (_, node, fmt) = try ensureEngine()
            node.stop()

            guard let buffer = ShortIntervalNoteSynthesizer.makeStereoBuffer(
                lowerMidi: low,
                upperMidi: high,
                a4: a4Reference,
                format: fmt,
                style: style
            ) else { return }

            isPlaying = true
            node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: {
                Task { @MainActor [weak self] in
                    self?.isPlaying = false
                }
            })
            node.play()
        } catch {
            #if DEBUG
            print("ShortIntervalNotePlayer: \(error)")
            #endif
            isPlaying = false
        }
    }

    func stop() {
        playerNode?.stop()
        isPlaying = false
    }
}
