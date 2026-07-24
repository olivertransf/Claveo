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

struct MetronomeScheduleState {
    var scheduledBeatCount = 0

    mutating func recordSchedule(succeeded: Bool) {
        if succeeded {
            scheduledBeatCount += 1
        }
    }

    mutating func reset() {
        scheduledBeatCount = 0
    }
}

extension Metronome {
    func updateInterval() {
        interval = 60.0 / Double(tempo)
    }
    
    func updateBeatPattern() {
        var pattern = Array(repeating: false, count: max(1, beatsPerMeasure))
        pattern[0] = true
        beatPattern = pattern
    }

    func toggleBeatAccent(at index: Int) {
        guard beatPattern.indices.contains(index) else { return }

        var updated = beatPattern
        updated[index].toggle()
        beatPattern = updated
        SettingsManager.shared.update(\.metronomeBeatPattern, value: updated)
        if isPlaying {
            restartTimer()
        }
    }
    
    func start() {
        guard !isPlaying else { return }

        startupError = nil
        if let error = setupAudioSession() {
            failPlayback(with: error)
            return
        }
        if let error = setupAudioPlayer() {
            failPlayback(with: error)
            return
        }

        guard let engine = audioEngine, let player = playerNode else {
            failPlayback(with: .audioBuffersUnavailable)
            return
        }
        do {
            try engine.start()
        } catch {
            failPlayback(with: .audioEngineFailed(error.localizedDescription))
            return
        }
        
        isPlaying = true
        currentBeat = -1
        beatCount = 0
        scheduledBeatCount = 0
        let now = CACurrentMediaTime()
        startTime = now
        nextBeatTime = now + audioOutputLatency
        lastBeatTime = 0
        
        scheduleBeatsAhead()
        player.play()
        startTimer()
        checkAndPlayBeat()
    }
    
    func stop() {
        isPlaying = false
        stopBeatTimer()
        currentBeat = 0
        beatCount = 0
        scheduledBeatCount = 0
        nextBeatTime = 0
        startTime = 0
        stopAudioEngine()
    }

    func failPlayback(with error: MetronomeStartupError) {
        stop()
        startupError = error
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
            restartTimer()
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
            restartTimer()
        }
        // Save custom time signature and reset beat pattern
        SettingsManager.shared.update(\.customTimeSignatureTop, value: clampedTop)
        SettingsManager.shared.update(\.customTimeSignatureBottom, value: validBottom)
        SettingsManager.shared.update(\.metronomeBeatPattern, value: beatPattern)
    }
    
    func startTimer() {
        stopBeatTimer()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: .milliseconds(40), leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.scheduleBeatsAhead()
            }
        }
        schedulingTimer = timer
        timer.resume()

        let target = MetronomeDisplayLinkTarget(metronome: self)
        displayLinkTarget = target
        let link = CADisplayLink(target: target, selector: #selector(MetronomeDisplayLinkTarget.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopBeatTimer() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
        schedulingTimer?.setEventHandler {}
        schedulingTimer?.cancel()
        schedulingTimer = nil
    }
    
    func scheduleBeatsAhead() {
        guard let player = playerNode, audioEngine != nil else { return }

        // Schedule from elapsed time, not UI beatCount — avoids silence when the main thread lags.
        let now = CACurrentMediaTime()
        let elapsedBeats = max(0, Int(floor((now - startTime) / interval)))
        // Skip past beats so AVAudioPlayerNode does not burst-play late buffers on resume.
        if scheduledBeatCount < elapsedBeats {
            scheduledBeatCount = elapsedBeats
        }
        let targetScheduled = elapsedBeats + beatsToScheduleAhead
        while scheduledBeatCount < targetScheduled {
            let beatNumber = scheduledBeatCount
            let beatTimeInSeconds = startTime + (Double(beatNumber) * interval)
            let beatHostTime = AVAudioTime.hostTime(forSeconds: beatTimeInSeconds)

            let beatInMeasure = beatNumber % beatsPerMeasure
            let isAccent = beatInMeasure < beatPattern.count && beatPattern[beatInMeasure]

            let buffer = isAccent ? accentBufferConverted : normalBufferConverted
            guard let audioBuffer = buffer else {
                scheduleState.recordSchedule(succeeded: false)
                return
            }

            let audioTime = AVAudioTime(hostTime: beatHostTime)
            player.scheduleBuffer(audioBuffer, at: audioTime, options: [], completionHandler: nil)
            scheduleState.recordSchedule(succeeded: true)
        }
    }

    func checkAndPlayBeat() {
        guard isPlaying else { return }

        let currentTime = CACurrentMediaTime()
        scheduleBeatsAhead()

        let latency = audioOutputLatency
        let elapsed = currentTime - startTime - latency
        guard elapsed >= -0.001 else {
            prepareHapticsIfNeeded(timeUntilNextBeat: startTime + latency - currentTime)
            return
        }

        let latestBeatNumber = Int(floor(elapsed / interval))
        let lastFiredBeatNumber = beatCount > 0 ? beatCount - 1 : -1
        guard latestBeatNumber > lastFiredBeatNumber else {
            let nextBeatNumber = lastFiredBeatNumber + 1
            let timeUntilNext = startTime + (Double(nextBeatNumber) * interval) + latency - currentTime
            prepareHapticsIfNeeded(timeUntilNextBeat: timeUntilNext)
            return
        }

        let maxCatchUp = 8
        var fireUpTo = latestBeatNumber
        if fireUpTo - lastFiredBeatNumber > maxCatchUp {
            fireUpTo = lastFiredBeatNumber + maxCatchUp
        }

        for beatNumber in (lastFiredBeatNumber + 1)...fireUpTo {
            beatCount = beatNumber + 1
            currentBeat = beatNumber % beatsPerMeasure
            lastBeatTime = startTime + (Double(beatNumber) * interval) + latency

            if beatNumber == fireUpTo {
                triggerHapticForCurrentBeat()
            }
        }

        nextBeatTime = startTime + (Double(beatCount) * interval) + latency
        prepareHapticsIfNeeded(timeUntilNextBeat: nextBeatTime - currentTime)
    }

    func triggerHapticForCurrentBeat() {
        guard hapticEnabled else { return }
        let isAccent = currentBeat < beatPattern.count && beatPattern[currentBeat]
        if isAccent {
            hapticGenerator.impactOccurred(intensity: 1.0)
            hapticGenerator.prepare()
        } else {
            hapticGeneratorLight.impactOccurred(intensity: 0.5)
            hapticGeneratorLight.prepare()
        }
    }

    func prepareHapticsIfNeeded(timeUntilNextBeat: TimeInterval) {
        guard hapticEnabled, timeUntilNextBeat > 0, timeUntilNextBeat < 0.05 else { return }
        hapticGenerator.prepare()
        hapticGeneratorLight.prepare()
    }
    
    func restartTimer() {
        guard isPlaying else { return }
        let currentTime = CACurrentMediaTime()
        startTime = currentTime
        nextBeatTime = currentTime + audioOutputLatency
        beatCount = 0
        scheduledBeatCount = 0
        lastBeatTime = 0
        playerNode?.stop()
        playerNode?.reset()
        playerNode?.play()
        
        scheduleBeatsAhead()
        startTimer()
        checkAndPlayBeat()
    }

    func beginTempoAdjustment() {
        isTempoAdjustmentInProgress = true
    }

    @discardableResult
    func endTempoAdjustment(shouldApply: Bool = true) -> Bool {
        guard hasPendingTempoReschedule else {
            isTempoAdjustmentInProgress = false
            return false
        }
        guard shouldApply else {
            isTempoAdjustmentInProgress = false
            hasPendingTempoReschedule = false
            return false
        }

        isTempoAdjustmentInProgress = false
        hasPendingTempoReschedule = false
        if isPlaying {
            restartTimer()
        }
        return true
    }

    func restartForAudioRouteChange() {
        guard isPlaying else { return }
        if let error = setupAudioSession() ?? setupAudioPlayer() {
            failPlayback(with: error)
            return
        }
        do {
            try audioEngine?.start()
            playerNode?.play()
            restartTimer()
        } catch {
            failPlayback(with: .audioEngineFailed(error.localizedDescription))
        }
    }
}


