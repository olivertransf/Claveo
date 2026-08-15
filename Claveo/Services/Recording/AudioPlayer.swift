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

    override init() {
        super.init()
        activatePlaybackSession()
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
                    self.activatePlaybackSession()
                    guard player.play() else { return }
                    self.isPlaying = true
                    self.startTimer()
                @unknown default:
                    break
                }
            }
        }
    }

    private func activatePlaybackSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("Failed to setup playback audio session: \(error)")
            #endif
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
        activatePlaybackSession()
        playbackError = nil

        let startTime = resumeTime(for: recording)

        if currentRecording?.id != recording.id || audioPlayer == nil {
            guard load(recording, startTime: startTime) else { return }
        } else if let player = audioPlayer {
            player.currentTime = min(max(0, startTime), player.duration)
            currentTime = player.currentTime
        }

        guard let player = audioPlayer else { return }
        player.enableRate = true
        player.rate = playbackRate
        guard player.play() else {
            playbackError = String(localized: "Playback could not start.")
            return
        }
        isPlaying = true
        startTimer()

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()

        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
        impactFeedback.impactOccurred()
    }

    func stop() {
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
            _ = load(recording, startTime: clamped)
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

    @discardableResult
    private func load(_ recording: Recording, startTime: TimeInterval) -> Bool {
        activatePlaybackSession()
        playbackError = nil

        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        stopTimer()

        do {
            guard FileManager.default.fileExists(atPath: recording.fileURL.path) else {
                playbackError = String(localized: "Recording file not found. It may still be downloading from iCloud.")
                return false
            }

            let player = try AVAudioPlayer(contentsOf: recording.fileURL)
            player.delegate = self
            player.enableRate = true
            player.prepareToPlay()
            player.rate = playbackRate
            duration = player.duration
            currentRecording = recording
            audioPlayer = player
            applySeek(startTime)
            return true
        } catch {
            playbackError = String(localized: "Failed to play recording: \(error.localizedDescription)")
            return false
        }
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
