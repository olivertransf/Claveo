//
//  MetronomeSoundPreview.swift
//  Claveo
//
//  Plays a single click so sound pickers can be auditioned without starting
//  the metronome.
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Foundation

@MainActor
final class MetronomeSoundPreview {
    static let shared = MetronomeSoundPreview()

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var teardownTask: Task<Void, Never>?

    private init() {}

    func play(_ sound: MetronomeSound, gain: Double) {
        guard let buffer = MetronomeAudio.makeBuffer(for: sound, gain: 1) else { return }

        teardownTask?.cancel()
        teardownTask = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }

        if engine == nil || player == nil || engine?.isRunning == false {
            teardown()
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
            do {
                try engine.start()
            } catch {
                return
            }
            self.engine = engine
            self.player = player
        }

        guard let player else { return }
        player.volume = MetronomeAudio.playerVolume(for: gain)
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        player.play()

        // Idle engines keep the audio session alive, so release shortly after.
        teardownTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.teardown()
        }
    }

    private func teardown() {
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
        teardownTask = nil
    }
}
