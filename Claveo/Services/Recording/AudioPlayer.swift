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
    @Published var playbackRate: Float = 1.0 {
        didSet {
            updatePlaybackRate()
        }
    }

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    override init() {
        super.init()
        activatePlaybackSession()
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

        if currentRecording?.id == recording.id, let player = audioPlayer {
            player.enableRate = true
            player.rate = playbackRate
            guard player.play() else {
                #if DEBUG
                print("AVAudioPlayer.play() returned false when resuming")
                #endif
                return
            }
            isPlaying = true
            startTimer()
            return
        }

        stop()

        do {
            guard FileManager.default.fileExists(atPath: recording.fileURL.path) else {
                #if DEBUG
                print("Audio file does not exist at: \(recording.fileURL.path)")
                #endif
                return
            }

            let player = try AVAudioPlayer(contentsOf: recording.fileURL)
            player.delegate = self
            player.enableRate = true
            player.prepareToPlay()
            player.rate = playbackRate
            duration = player.duration
            currentRecording = recording
            audioPlayer = player

            guard player.play() else {
                #if DEBUG
                print("AVAudioPlayer.play() returned false for: \(recording.fileURL.lastPathComponent)")
                #endif
                stop()
                return
            }

            isPlaying = true
            startTimer()

            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } catch {
            #if DEBUG
            print("Failed to play recording: \(error)")
            #endif
            stop()
        }
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
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let wasPlaying = isPlaying

        if wasPlaying {
            player.pause()
        }

        player.currentTime = time
        currentTime = time

        if wasPlaying {
            player.play()
        }
    }

    func skipBackward(seconds: TimeInterval = 15) {
        guard let player = audioPlayer else { return }
        let wasPlaying = isPlaying
        let newTime = max(0, player.currentTime - seconds)
        seek(to: newTime)
        if wasPlaying {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func skipForward(seconds: TimeInterval = 15) {
        guard let player = audioPlayer else { return }
        let wasPlaying = isPlaying
        let newTime = min(duration, player.currentTime + seconds)
        seek(to: newTime)
        if wasPlaying {
            player.play()
            isPlaying = true
            startTimer()
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
