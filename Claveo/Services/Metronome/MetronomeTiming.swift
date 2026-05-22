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
        scheduledBeatCount = 0
        let now = CACurrentMediaTime()
        startTime = now
        nextBeatTime = now
        lastBeatTime = 0
        
        scheduleBeatsAhead()
        startTimer()

        // Immediately align UI/haptics to the first scheduled beat without re-scheduling audio.
        checkAndPlayBeat()
    }
    
    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        currentBeat = 0
        beatCount = 0
        scheduledBeatCount = 0
        nextBeatTime = 0
        startTime = 0
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
        SettingsManager.shared.update(\.metronomeTimeSignature, value: signature.rawValue)
        SettingsManager.shared.update(\.metronomeBeatPattern, value: beatPattern)
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
        // Save custom time signature and reset beat pattern
        SettingsManager.shared.update(\.customTimeSignatureTop, value: clampedTop)
        SettingsManager.shared.update(\.customTimeSignatureBottom, value: validBottom)
        SettingsManager.shared.update(\.metronomeBeatPattern, value: beatPattern)
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
    }
    
    func scheduleBeatsAhead() {
        guard let player = playerNode, audioEngine != nil else { return }

        // Schedule from elapsed time, not UI beatCount — avoids silence when the main thread lags.
        let now = CACurrentMediaTime()
        let elapsedBeats = max(0, Int(floor((now - startTime) / interval)))
        let targetScheduled = elapsedBeats + beatsToScheduleAhead
        let beatsToAdd = targetScheduled - scheduledBeatCount
        guard beatsToAdd > 0 else { return }

        for i in 0..<beatsToAdd {
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

        scheduledBeatCount += beatsToAdd
    }

    func checkAndPlayBeat() {
        let currentTime = CACurrentMediaTime()
        scheduleBeatsAhead()

        // Catch up UI/haptics if the timer was delayed (cap avoids a long main-thread loop).
        var catchUpCount = 0
        while currentTime >= nextBeatTime - 0.001, catchUpCount < 8 {
            lastBeatTime = currentTime
            beatCount += 1
            currentBeat = (beatCount - 1) % beatsPerMeasure

            if hapticEnabled {
                let isAccent = currentBeat < beatPattern.count && beatPattern[currentBeat]
                if isAccent {
                    hapticGenerator.prepare()
                    hapticGenerator.impactOccurred(intensity: 1.0)
                } else {
                    hapticGeneratorLight.prepare()
                    hapticGeneratorLight.impactOccurred(intensity: 0.5)
                }
            }

            nextBeatTime = startTime + (Double(beatCount) * interval)
            catchUpCount += 1
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
        playerNode?.stop()
        playerNode?.reset()
        playerNode?.play()
        
        scheduleBeatsAhead()
        startTimer()

        // Immediately align UI/haptics to the first scheduled beat without re-scheduling audio.
        checkAndPlayBeat()
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


