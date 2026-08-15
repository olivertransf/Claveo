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
    /// Beats closer than this are treated as already gone; scheduling them would
    /// make AVAudioPlayerNode fire them immediately as an extra click.
    static let minimumScheduleLead: TimeInterval = 0.01
    static let maximumScheduleLookahead: TimeInterval = 1.5

    func updateInterval() {
        interval = 60.0 / Double(tempo)
    }
    
    func updateBeatPattern() {
        var pattern = Array(repeating: false, count: max(1, beatsPerMeasure))
        pattern[0] = true
        beatPattern = pattern
    }

    func setSubdivision(_ next: MetronomeSubdivision) {
        guard next != subdivision else { return }
        subdivision = next
        SettingsManager.shared.update(\.metronomeSubdivision, value: next.rawValue)
        resyncScheduledBeats()
    }

    func toggleBeatAccent(at index: Int) {
        guard beatPattern.indices.contains(index) else { return }

        var updated = beatPattern
        updated[index].toggle()
        beatPattern = updated
        SettingsManager.shared.update(\.metronomeBeatPattern, value: updated)
        resyncScheduledBeats()
    }

    /// Re-queues upcoming beats without touching the beat timeline, so accent and
    /// sound changes apply on the next beat instead of restarting the tempo.
    func resyncScheduledBeats() {
        guard isPlaying, let player = playerNode else { return }
        player.stop()
        player.reset()
        scheduledBeatCount = 0
        player.play()
        scheduleBeatsAhead()
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
        // The beat timeline starts one output-latency ahead so scheduled audio and
        // on-screen beats line up instead of the first click landing in the past.
        startTime = CACurrentMediaTime() + audioOutputLatency
        nextBeatTime = startTime
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
    
    func setTimeSignature(_ signature: TimeSignature) {
        timeSignature = signature
        customTimeSignature = nil
        updateBeatPattern()
        resyncScheduledBeats()
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
        resyncScheduledBeats()
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
        // Only queue beats that are still ahead of us, so AVAudioPlayerNode never
        // burst-plays late buffers after a lag spike, resume, or sound change.
        let firstFutureBeat = max(0, Int(ceil((now + Self.minimumScheduleLead - startTime) / interval)))
        if scheduledBeatCount < firstFutureBeat {
            scheduledBeatCount = firstFutureBeat
        }
        let targetScheduled = firstFutureBeat + beatsToScheduleAhead
        while scheduledBeatCount < targetScheduled {
            let beatNumber = scheduledBeatCount
            let beatTimeInSeconds = startTime + (Double(beatNumber) * interval)
            // Keep the queue short at slow tempos so accent, sound, and tempo
            // changes take effect promptly instead of after many queued beats.
            if beatNumber > firstFutureBeat + 1,
               beatTimeInSeconds - now > Self.maximumScheduleLookahead {
                return
            }
            let clicks = subdivision.scheduledClicks(
                beatNumber: beatNumber,
                startTime: startTime,
                interval: interval,
                beatsPerMeasure: beatsPerMeasure,
                beatPattern: beatPattern,
                now: now,
                minimumLead: Self.minimumScheduleLead
            )

            for click in clicks {
                let buffer = click.isAccent
                    ? accentBufferConverted
                    : (click.gain < 1 ? quietNormalBufferConverted : normalBufferConverted)
                guard let audioBuffer = buffer else {
                    scheduleState.recordSchedule(succeeded: false)
                    return
                }

                let audioTime = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: click.hostTimeSeconds))
                player.scheduleBuffer(audioBuffer, at: audioTime, options: [], completionHandler: nil)
            }

            scheduleState.recordSchedule(succeeded: true)
        }
    }

    func checkAndPlayBeat() {
        guard isPlaying else { return }

        let currentTime = CACurrentMediaTime()
        scheduleBeatsAhead()

        let elapsed = currentTime - startTime
        guard elapsed >= -0.001 else {
            prepareHapticsIfNeeded(timeUntilNextBeat: startTime - currentTime)
            return
        }

        let latestBeatNumber = Int(floor(elapsed / interval))
        let lastFiredBeatNumber = beatCount > 0 ? beatCount - 1 : -1
        guard latestBeatNumber > lastFiredBeatNumber else {
            let nextBeatNumber = lastFiredBeatNumber + 1
            let timeUntilNext = startTime + (Double(nextBeatNumber) * interval) - currentTime
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
            lastBeatTime = startTime + (Double(beatNumber) * interval)

            if beatNumber == fireUpTo {
                triggerHapticForCurrentBeat()
            }
        }

        nextBeatTime = startTime + (Double(beatCount) * interval)
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
        startTime = CACurrentMediaTime() + audioOutputLatency
        nextBeatTime = startTime
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


