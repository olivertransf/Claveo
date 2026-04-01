//
//  ToneGeneratorEngine.swift
//  Claveo
//
//  Continuous sine reference tone (metronome tab).
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Combine
import Foundation

extension Notification.Name {
    static let claveoSelectedTabChanged = Notification.Name("Claveo.selectedTabChanged")
}

@MainActor
final class ToneGeneratorEngine: ObservableObject {
    static let frequencyMin = 30.0
    static let frequencyMax = 2000.0

    @Published private(set) var isPlaying = false
    @Published private(set) var frequency: Double = 440

    private final class RenderState: @unchecked Sendable {
        let lock = NSLock()
        var phase: Double = 0
        var hz: Double = 440
    }

    private let renderState = RenderState()
    private var engine: AVAudioEngine?

    init() {
        renderState.lock.lock()
        renderState.hz = Self.clamp(440)
        renderState.lock.unlock()
    }

    static func clamp(_ f: Double) -> Double {
        min(frequencyMax, max(frequencyMin, f))
    }

    static func midiNoteToHz(midi: Int, a4: Double) -> Double {
        a4 * pow(2.0, Double(midi - 69) / 12.0)
    }

    func applyFrequency(_ hz: Double) {
        let c = Self.clamp(hz)
        frequency = c
        renderState.lock.lock()
        renderState.hz = c
        renderState.lock.unlock()
    }

    private func prepareSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("ToneGeneratorEngine: session error \(error)")
            #endif
        }
    }

    func start() {
        guard !isPlaying else { return }
        prepareSession()

        let eng = AVAudioEngine()
        let format = eng.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let renderState = self.renderState

        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let n = Int(frameCount)
            renderState.lock.lock()
            let phase = renderState.phase
            let hz = renderState.hz
            renderState.lock.unlock()

            let twoPi = 2.0 * Double.pi
            var ph = phase
            let inc = twoPi * hz / sampleRate
            let amp: Float = 0.18

            for frame in 0..<n {
                let sample = Float(sin(ph)) * amp
                ph += inc
                if ph >= twoPi { ph -= twoPi }
                if ph < 0 { ph += twoPi }
                for buffer in abl {
                    guard let base = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    base[frame] = sample
                }
            }

            renderState.lock.lock()
            renderState.phase = ph
            renderState.lock.unlock()
            return noErr
        }

        eng.attach(node)
        eng.connect(node, to: eng.mainMixerNode, format: format)

        do {
            try eng.start()
            engine = eng
            isPlaying = true
        } catch {
            #if DEBUG
            print("ToneGeneratorEngine: start error \(error)")
            #endif
            eng.stop()
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        isPlaying = false
    }
}
