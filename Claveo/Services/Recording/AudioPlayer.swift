//
//  AudioPlayer.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Foundation
import Combine
import UIKit

@MainActor
class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentRecording: Recording?
    @Published var playbackError: String?
    @Published var playbackRate: Float = 1.0 {
        didSet {
            updatePlaybackRate()
        }
    }

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var pendingSeek: (id: UUID, time: TimeInterval)?
    /// Bumped by play, pause, and stop so a session activation that finishes late cannot start audio the user already cancelled.
    private var playbackGeneration = 0

    override init() {
        super.init()
        observeInterruptions()
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    /// Calls, alarms and Siri stop the player without telling the delegate, which
    /// would otherwise leave the UI showing a paused file as still playing.
    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard
                    let rawType = info?[AVAudioSessionInterruptionTypeKey] as? UInt,
                    let type = AVAudioSession.InterruptionType(rawValue: rawType)
                else { return }

                switch type {
                case .began:
                    guard self.isPlaying else { return }
                    self.audioPlayer?.pause()
                    self.isPlaying = false
                    self.stopTimer()
                case .ended:
                    let rawOptions = info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    guard
                        AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume),
                        let player = self.audioPlayer
                    else { return }
                    let generation = self.playbackGeneration
                    await Self.configurePlaybackSession()
                    guard generation == self.playbackGeneration else { return }
                    guard player.play() else { return }
                    self.isPlaying = true
                    self.startTimer()
                @unknown default:
                    break
                }
            }
        }
    }

    /// Category changes and session activation block. Keep them off the main actor.
    private nonisolated static func configurePlaybackSession() async {
        await Task.detached {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                if #available(iOS 27, *) {
                    await Self.activate(session)
                } else {
                    try session.setActive(true)
                }
            } catch {
                #if DEBUG
                print("Failed to setup playback audio session: \(error)")
                #endif
            }
        }.value
    }

    private nonisolated enum OpenedPlayer: Sendable {
        case ready(LoadedPlayer)
        case missing
        case failed
    }

    private nonisolated final class LoadedPlayer: @unchecked Sendable {
        let player: AVAudioPlayer
        init(_ player: AVAudioPlayer) { self.player = player }
    }

    /// Opens the file away from the main actor. `AVAudioPlayer` activates the session while it loads.
    private nonisolated static func openPlayer(at url: URL, rate: Float) async -> OpenedPlayer {
        await Task.detached {
            await configurePlaybackSession()
            guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.enableRate = true
                player.prepareToPlay()
                player.rate = rate
                return .ready(LoadedPlayer(player))
            } catch {
                return .failed
            }
        }.value
    }

    @available(iOS 27, *)
    private nonisolated static func activate(_ session: AVAudioSession) async {
        await withCheckedContinuation { continuation in
            session.activate(options: []) { _, _ in
                continuation.resume()
            }
        }
    }

    private func updatePlaybackRate() {
        guard let player = audioPlayer else { return }

        let wasPlaying = isPlaying
        let currentTime = player.currentTime

        if wasPlaying {
            player.pause()
        }

        player.enableRate = true
        player.rate = playbackRate
        player.currentTime = currentTime

        if wasPlaying {
            player.play()
        }
    }

    func play(_ recording: Recording) {
        playbackGeneration += 1
        let generation = playbackGeneration
        playbackError = nil

        let startTime = resumeTime(for: recording)
        let url = recording.fileURL
        let rate = playbackRate
        let replacePlayer = currentRecording?.id != recording.id || audioPlayer == nil
        Task {
            if replacePlayer {
                let opened = await Self.openPlayer(at: url, rate: rate)
                guard generation == playbackGeneration else { return }
                switch opened {
                case .ready(let loaded):
                    install(loaded.player, for: recording, startTime: startTime, startPlaying: true)
                case .missing:
                    playbackError = String(localized: "Recording file not found. It may still be downloading from iCloud.")
                case .failed:
                    playbackError = String(localized: "Failed to play recording.")
                }
            } else {
                await Self.configurePlaybackSession()
                guard generation == playbackGeneration else { return }
                beginPlayback(recording, startTime: startTime)
            }
        }
    }

    private func beginPlayback(_ recording: Recording, startTime: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(max(0, startTime), player.duration)
        currentTime = player.currentTime
        player.enableRate = true
        player.rate = playbackRate
        guard player.play() else {
            playbackError = String(localized: "Playback could not start.")
            return
        }
        isPlaying = true
        startTimer()

        HapticFeedback.lightImpact()
    }

    func pause() {
        playbackGeneration += 1
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()

        HapticFeedback.softImpact()
    }

    func stop() {
        playbackGeneration += 1
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentRecording = nil
        pendingSeek = nil
        stopTimer()
    }

    func pauseIfPlaying(_ recording: Recording) {
        guard currentRecording?.id == recording.id, isPlaying else { return }
        pause()
    }

    func seek(_ recording: Recording, to time: TimeInterval) {
        let clamped = max(0, time)
        pendingSeek = (recording.id, clamped)
        currentTime = clamped

        if currentRecording?.id != recording.id || audioPlayer == nil {
            let generation = playbackGeneration
            let url = recording.fileURL
            let rate = playbackRate
            Task {
                let opened = await Self.openPlayer(at: url, rate: rate)
                guard generation == playbackGeneration else { return }
                switch opened {
                case .ready(let loaded):
                    install(loaded.player, for: recording, startTime: clamped, startPlaying: false)
                case .missing:
                    playbackError = String(localized: "Recording file not found. It may still be downloading from iCloud.")
                case .failed:
                    playbackError = String(localized: "Failed to play recording.")
                }
            }
            return
        }

        applySeek(clamped)
    }

    func seek(to time: TimeInterval) {
        if let recording = currentRecording {
            seek(recording, to: time)
            return
        }
        currentTime = max(0, time)
    }

    func skipBackward(seconds: TimeInterval = 15) {
        let wasPlaying = isPlaying
        let base = audioPlayer?.currentTime ?? currentTime
        let newTime = max(0, base - seconds)
        if let recording = currentRecording {
            seek(recording, to: newTime)
        } else {
            seek(to: newTime)
        }
        if wasPlaying, let recording = currentRecording {
            play(recording)
        }
    }

    func skipForward(seconds: TimeInterval = 15) {
        let wasPlaying = isPlaying
        let limit = duration > 0 ? duration : .greatestFiniteMagnitude
        let base = audioPlayer?.currentTime ?? currentTime
        let newTime = min(limit, base + seconds)
        if let recording = currentRecording {
            seek(recording, to: newTime)
        } else {
            seek(to: newTime)
        }
        if wasPlaying, let recording = currentRecording {
            play(recording)
        }
    }

    private func resumeTime(for recording: Recording) -> TimeInterval {
        if currentRecording?.id == recording.id, let player = audioPlayer {
            return player.currentTime
        }
        if let pendingSeek, pendingSeek.id == recording.id {
            return pendingSeek.time
        }
        if currentRecording?.id == recording.id {
            return currentTime
        }
        return 0
    }

    private func install(
        _ player: AVAudioPlayer,
        for recording: Recording,
        startTime: TimeInterval,
        startPlaying: Bool
    ) {
        audioPlayer?.stop()
        player.delegate = self
        duration = player.duration
        currentRecording = recording
        audioPlayer = player
        isPlaying = false
        stopTimer()
        applySeek(startTime)
        guard startPlaying else { return }
        player.enableRate = true
        player.rate = playbackRate
        guard player.play() else {
            playbackError = String(localized: "Playback could not start.")
            return
        }
        isPlaying = true
        startTimer()
        HapticFeedback.lightImpact()
    }

    private func applySeek(_ time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let clamped = min(max(0, time), max(player.duration, 0))
        let wasPlaying = isPlaying
        if wasPlaying {
            player.pause()
        }
        player.currentTime = clamped
        currentTime = clamped
        if let recording = currentRecording {
            pendingSeek = (recording.id, clamped)
        }
        if wasPlaying {
            player.play()
        }
    }

    private func startTimer() {
        stopTimer()
        let newTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stop()
        }
    }
}
