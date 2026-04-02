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
import UIKit

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
        /// Smoothed amplitude — render loop interpolates toward targetAmplitude each sample.
        var amplitude: Double = 0
        /// Desired amplitude: 0.18 when playing, 0 when fading out.
        var targetAmplitude: Double = 0
    }

    private let renderState = RenderState()
    private var engine: AVAudioEngine?
    /// Task that stops the engine after a fade-out completes.
    private var stopTask: Task<Void, Never>?

    init() {
        renderState.lock.lock()
        renderState.hz = Self.clamp(440)
        renderState.lock.unlock()

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.gracefulStop()
            }
        }
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

    /// Fades amplitude to zero over ~40 ms then tears down the engine.
    func gracefulStop() {
        guard isPlaying else { return }
        isPlaying = false
        stopTask?.cancel()
        renderState.lock.lock()
        renderState.targetAmplitude = 0
        renderState.lock.unlock()
        stopTask = Task { @MainActor [weak self] in
            // Wait for the fade (50 ms headroom over the 40 ms ramp).
            try? await Task.sleep(nanoseconds: 50_000_000)
            self?.engine?.stop()
            self?.engine = nil
        }
    }

    func start() {
        guard !isPlaying else { return }
        stopTask?.cancel()
        stopTask = nil
        prepareSession()

        let eng = AVAudioEngine()
        let format = eng.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let renderState = self.renderState

        // Per-sample amplitude step for a ~40 ms fade (avoids clicks on start/stop).
        let fadeStep = 0.18 / (0.04 * sampleRate)

        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let n = Int(frameCount)
            renderState.lock.lock()
            var ph = renderState.phase
            let hz = renderState.hz
            var amp = renderState.amplitude
            let target = renderState.targetAmplitude
            renderState.lock.unlock()

            let twoPi = 2.0 * Double.pi
            let inc = twoPi * hz / sampleRate

            for frame in 0..<n {
                // Smooth amplitude toward target one step at a time.
                if amp < target {
                    amp = min(target, amp + fadeStep)
                } else if amp > target {
                    amp = max(target, amp - fadeStep)
                }
                let sample = Float(sin(ph)) * Float(amp)
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
            renderState.amplitude = amp
            renderState.lock.unlock()
            return noErr
        }

        eng.attach(node)
        eng.connect(node, to: eng.mainMixerNode, format: format)

        // Reset amplitude state so the fade-in starts from silence.
        renderState.lock.lock()
        renderState.amplitude = 0
        renderState.targetAmplitude = 0.18
        renderState.lock.unlock()

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
        gracefulStop()
    }
}
