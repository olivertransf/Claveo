//
//  Metronome+Timing.swift
//  Claveo
//
//  Timing and scheduling logic extracted from Metronome.
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import QuartzCore
import Foundation
import UIKit

extension Metronome {
    func updateInterval() {
        interval = 60.0 / Double(tempo)
    }
    
    func updateBeatPattern() {
        beatPattern = Array(repeating: false, count: max(1, beatsPerMeasure))
        beatPattern[0] = true
    }
    
    func start() {
        guard !isPlaying else { return }
        
        setupAudioSession()
        setupAudioPlayer()
        
        guard let engine = audioEngine, let player = playerNode else { return }
        do {
            try engine.start()
            player.play()
        } catch {
            #if DEBUG
            print("Failed to start audio engine: \(error)")
            #endif
            return
        }
        
        isPlaying = true
        currentBeat = -1
        beatCount = 0
        isPlayingBeat = false
        
        let now = CACurrentMediaTime()
        startTime = now
        nextBeatTime = now
        lastBeatTime = 0
        
        scheduleBeatsAhead()
        startTimer()
        
        isPlayingBeat = true
        lastBeatTime = now
        beatCount = 1
        scheduledBeatCount = 1
        nextBeatTime = startTime + interval
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            self?.isPlayingBeat = false
        }
    }
    
    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        currentBeat = 0
        stopAudioEngine()
    }
    
    func savePreferences() {
        SettingsManager.shared.setMetronomeSound(soundType)
        SettingsManager.shared.update(\.metronomeHapticEnabled, value: hapticEnabled)
    }
    
    func setTimeSignature(_ signature: TimeSignature) {
        timeSignature = signature
        customTimeSignature = nil
        updateBeatPattern()
        if isPlaying {
            currentBeat = 0
        }
        // Clear custom time signature when selecting a standard one
        SettingsManager.shared.update(\.customTimeSignatureTop, value: nil)
        SettingsManager.shared.update(\.customTimeSignatureBottom, value: nil)
    }
    
    func setCustomTimeSignature(top: Int, bottom: Int) {
        let allowedBottoms: [Int] = [1, 2, 4, 8, 16]
        let clampedTop = max(1, min(16, top))
        let validBottom = allowedBottoms.contains(bottom) ? bottom : 4
        customTimeSignature = (clampedTop, validBottom)
        updateBeatPattern()
        if isPlaying {
            currentBeat = 0
        }
        // Save custom time signature
        SettingsManager.shared.update(\.customTimeSignatureTop, value: clampedTop)
        SettingsManager.shared.update(\.customTimeSignatureBottom, value: validBottom)
    }
    
    func startTimer() {
        timer?.invalidate()
        let timerInterval = min(interval / 20.0, 0.025)
        timer = Timer(timeInterval: timerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying else { return }
                self.checkAndPlayBeat()
            }
        }
        
        guard let timer else { return }
        RunLoop.current.add(timer, forMode: .common)
        RunLoop.current.add(timer, forMode: .tracking)
    }
    
    func scheduleBeatsAhead() {
        guard let player = playerNode, audioEngine != nil else { return }
        
        for i in 0..<beatsToScheduleAhead {
            let beatNumber = scheduledBeatCount + i
            let beatTimeInSeconds = startTime + (Double(beatNumber) * interval)
            let beatHostTime = AVAudioTime.hostTime(forSeconds: beatTimeInSeconds)
            
            let beatInMeasure = beatNumber % beatsPerMeasure
            let isAccent = beatInMeasure < beatPattern.count && beatPattern[beatInMeasure]
            
            let buffer = isAccent ? accentBufferConverted : normalBufferConverted
            guard let audioBuffer = buffer else { continue }
            
            let audioTime = AVAudioTime(hostTime: beatHostTime)
            player.scheduleBuffer(audioBuffer, at: audioTime, options: [], completionHandler: nil)
        }
        
        scheduledBeatCount += beatsToScheduleAhead
    }
    
    func checkAndPlayBeat() {
        guard !isPlayingBeat else { return }
        
        let currentTime = CACurrentMediaTime()
        
        let beatsAhead = scheduledBeatCount - beatCount
        if beatsAhead < 2 {
            scheduleBeatsAhead()
        }
        
        if currentTime >= nextBeatTime - 0.001 {
            isPlayingBeat = true
            lastBeatTime = currentTime
            beatCount += 1
            
            currentBeat = (beatCount - 1) % beatsPerMeasure
            
            if hapticEnabled {
                let isAccent = currentBeat < beatPattern.count && beatPattern[currentBeat]
                // Prepare generators right before use for better reliability
                if isAccent {
                    hapticGenerator.prepare()
                    hapticGenerator.impactOccurred(intensity: 1.0)
                } else {
                    hapticGeneratorLight.prepare()
                    hapticGeneratorLight.impactOccurred(intensity: 0.5)
                }
            }
            
            nextBeatTime = startTime + (Double(beatCount) * interval)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) { [weak self] in
                self?.isPlayingBeat = false
            }
        }
    }
    
    func restartTimer() {
        guard isPlaying else { return }
        let currentTime = CACurrentMediaTime()
        startTime = currentTime
        nextBeatTime = currentTime
        beatCount = 0
        scheduledBeatCount = 0
        lastBeatTime = 0
        isPlayingBeat = false
        
        playerNode?.stop()
        playerNode?.reset()
        playerNode?.play()
        
        scheduleBeatsAhead()
        startTimer()
        beatCount = 1
        scheduledBeatCount = beatsToScheduleAhead
        nextBeatTime = startTime + interval
    }
    
    func playBeat() {
        currentBeat = (currentBeat + 1) % beatsPerMeasure
        
        let isAccent = currentBeat < beatPattern.count && beatPattern[currentBeat]
        
        if hapticEnabled {
            // Prepare generators right before use for better reliability
            if isAccent {
                hapticGenerator.prepare()
                hapticGenerator.impactOccurred(intensity: 1.0)
            } else {
                hapticGeneratorLight.prepare()
                hapticGeneratorLight.impactOccurred(intensity: 0.5)
            }
        }
        
        guard let player = playerNode else { return }
        let audioBuffer = isAccent ? accentBufferConverted : normalBufferConverted
        guard let buffer = audioBuffer else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
}


