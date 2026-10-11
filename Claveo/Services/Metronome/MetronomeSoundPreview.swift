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
    private var playbackTask: Task<Void, Never>?
    private var playGeneration = 0

    private init() {}

    func play(_ sound: MetronomeSound, gain: Double) {
        guard let buffer = MetronomeAudio.makeBuffer(for: sound, gain: 1) else { return }

        playGeneration += 1
        let generation = playGeneration
        playbackTask?.cancel()
        playbackTask = Task { @MainActor [weak self] in
            let ready = await Self.activatePlaybackSession()
            guard ready, let self, generation == self.playGeneration else { return }
            self.startPreview(buffer: buffer, gain: gain, generation: generation)
        }
    }

    private func startPreview(buffer: AVAudioPCMBuffer, gain: Double, generation: Int) {
        if engine == nil || player == nil || engine?.isRunning == false {
            teardownEngine()
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
        playbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled, let self, generation == self.playGeneration else { return }
            self.teardown()
        }
    }

    private nonisolated static func activatePlaybackSession() async -> Bool {
        await Task.detached {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try await AudioSessionActivation.activate(session)
                return true
            } catch {
                return false
            }
        }.value
    }

    private func teardown() {
        playbackTask?.cancel()
        playbackTask = nil
        teardownEngine()
    }

    private func teardownEngine() {
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
    }
}
