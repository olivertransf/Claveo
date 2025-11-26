//
//  AudioPlayer.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import AVFoundation
import Foundation
import Combine

@MainActor
class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentRecording: Recording?
    @Published var playbackRate: Float = 1.0 {
        didSet {
            audioPlayer?.rate = playbackRate
            audioPlayer?.enableRate = true
        }
    }
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("Failed to setup audio session: \(error)")
            #endif
        }
    }
    
    func play(_ recording: Recording) {
        if currentRecording?.id == recording.id && audioPlayer != nil {
            audioPlayer?.play()
            isPlaying = true
            startTimer()
            return
        }
        
        stop()
        
        do {
            // Check if file exists before trying to play
            guard FileManager.default.fileExists(atPath: recording.fileURL.path) else {
                #if DEBUG
                print("Audio file does not exist at: \(recording.fileURL.path)")
                #endif
                return
            }
            
            audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackRate
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            currentRecording = recording
            audioPlayer?.play()
            isPlaying = true
            startTimer()
            
            // Haptic feedback for playback start
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } catch {
            #if DEBUG
            print("Failed to play recording: \(error)")
            #endif
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
        
        // Haptic feedback for playback pause
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
        timer?.invalidate()
        timer = nil
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    func skipBackward(seconds: TimeInterval = 15) {
        guard let player = audioPlayer else { return }
        let wasPlaying = isPlaying
        let newTime = max(0, player.currentTime - seconds)
        seek(to: newTime)
        // Auto-resume if it was playing
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
        // Auto-resume if it was playing
        if wasPlaying {
            player.play()
            isPlaying = true
            startTimer()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
            }
        }
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stop()
        }
    }
}

