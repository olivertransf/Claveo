//
//  Metronome.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Combine
import Foundation
import QuartzCore
import UIKit

enum MetronomeSound: String, CaseIterable {
    case click = "Click"
    case woodBlock = "Wood Block"
    case bell = "Bell"
    case beep = "Beep"
    case tick = "Tick"
    case cowbell = "Cowbell"
    case triangle = "Triangle"
    case marimba = "Marimba"
    case drum = "Drum"
    case chimes = "Chimes"

    var localizedName: String {
        switch self {
        case .click: return String(localized: "Click")
        case .woodBlock: return String(localized: "Wood Block")
        case .bell: return String(localized: "Bell")
        case .beep: return String(localized: "Beep")
        case .tick: return String(localized: "Tick")
        case .cowbell: return String(localized: "Cowbell")
        case .triangle: return String(localized: "Triangle")
        case .marimba: return String(localized: "Marimba")
        case .drum: return String(localized: "Drum")
        case .chimes: return String(localized: "Chimes")
        }
    }
}

enum MetronomeStartupError: LocalizedError, Equatable {
    case audioSessionFailed(String)
    case audioBuffersUnavailable
    case audioEngineFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioSessionFailed(let detail):
            return String(localized: "The metronome could not configure audio: \(detail)")
        case .audioBuffersUnavailable:
            return String(localized: "The metronome could not create playable click sounds.")
        case .audioEngineFailed(let detail):
            return String(localized: "The metronome could not start audio: \(detail)")
        }
    }
}

struct MetronomeAudioConfiguration: Equatable {
    let emphasizedSound: MetronomeSound
    let normalSound: MetronomeSound
    let gain: Double
}

@MainActor
class Metronome: ObservableObject {
    @Published var isPlaying = false
    @Published var startupError: MetronomeStartupError?
    @Published var tempo: Int = 120 {
        didSet {
            updateInterval()
            if isTempoAdjustmentInProgress {
                hasPendingTempoReschedule = true
            } else if isPlaying {
                restartTimer()
            }
        }
    }
    @Published var timeSignature: TimeSignature = .fourFour
    @Published var customTimeSignature: (top: Int, bottom: Int)? = nil
    @Published var beatPattern: [Bool] = [true, false, false, false]
    @Published var currentBeat: Int = 0
    @Published var hapticEnabled: Bool = true
    
    var interval: TimeInterval = 0.5
    var nextBeatTime: TimeInterval = 0
    var startTime: TimeInterval = 0
    var beatCount: Int = 0
    var lastBeatTime: TimeInterval = 0
    var scheduleState = MetronomeScheduleState()
    var scheduledBeatCount: Int {
        get { scheduleState.scheduledBeatCount }
        set { scheduleState.scheduledBeatCount = newValue }
    }
    let beatsToScheduleAhead = 8
    var schedulingTimer: DispatchSourceTimer?
    var displayLink: CADisplayLink?
    var displayLinkTarget: MetronomeDisplayLinkTarget?
    var isTempoAdjustmentInProgress = false
    var hasPendingTempoReschedule = false
    
    let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    let hapticGeneratorLight = UIImpactFeedbackGenerator(style: .light)
    
    var beatsPerMeasure: Int {
        customTimeSignature?.top ?? timeSignature.beatsPerMeasure
    }
    
    var displayTimeSignature: String {
        if let custom = customTimeSignature {
            return "\(custom.top)/\(custom.bottom)"
        }
        return timeSignature.rawValue
    }
    
    private var observerTokens: [NSObjectProtocol] = []
    private var settingsCancellable: AnyCancellable?
    private var lastAudioConfiguration: MetronomeAudioConfiguration
    private var shouldResumeAfterInterruption = false

    init() {
        let settings = SettingsManager.shared.settings
        lastAudioConfiguration = MetronomeAudioConfiguration(
            emphasizedSound: MetronomeSound(rawValue: settings.metronomeEmphasizedSound) ?? .tick,
            normalSound: MetronomeSound(rawValue: settings.metronomeNonEmphasizedSound) ?? .click,
            gain: settings.metronomeVolume
        )
        
        // Load last tempo (or 120 if no last tempo saved)
        let tempoToLoad = settings.lastMetronomeTempo > 0 ? settings.lastMetronomeTempo : 120
        if tempoToLoad >= 20 && tempoToLoad <= 300 {
            tempo = tempoToLoad
        }

        // Load time signature
        if let saved = TimeSignature(rawValue: settings.metronomeTimeSignature) {
            timeSignature = saved
        }

        // Load custom time signature
        if let top = settings.customTimeSignatureTop, let bottom = settings.customTimeSignatureBottom {
            customTimeSignature = (top, bottom)
        }

        hapticEnabled = settings.metronomeHapticEnabled

        updateInterval()
        updateBeatPattern()

        // Restore saved beat pattern if it matches the current beat count
        let savedPattern = settings.metronomeBeatPattern
        if savedPattern.count == beatsPerMeasure {
            beatPattern = savedPattern
        }
        
        // Prepare haptic generators
        hapticGenerator.prepare()
        hapticGeneratorLight.prepare()

        let interruptionToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleAudioSessionInterruption(userInfo: notification.userInfo)
            }
        }
        observerTokens.append(interruptionToken)

        let routeToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleAudioRouteChange(userInfo: notification.userInfo)
            }
        }
        observerTokens.append(routeToken)

        settingsCancellable = SettingsManager.shared.$settings
            .dropFirst()
            .sink { [weak self] settings in
                let configuration = MetronomeAudioConfiguration(
                    emphasizedSound: MetronomeSound(rawValue: settings.metronomeEmphasizedSound) ?? .tick,
                    normalSound: MetronomeSound(rawValue: settings.metronomeNonEmphasizedSound) ?? .click,
                    gain: settings.metronomeVolume
                )
                guard let self, configuration != self.lastAudioConfiguration else { return }
                let previous = self.lastAudioConfiguration
                self.lastAudioConfiguration = configuration
                if configuration.gain != previous.gain {
                    self.applyVolume(configuration.gain)
                }
                let soundsChanged = configuration.emphasizedSound != previous.emphasizedSound
                    || configuration.normalSound != previous.normalSound
                if soundsChanged, self.isPlaying {
                    self.reloadClickSounds()
                }
            }
    }

    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
    }

    private func handleAudioSessionInterruption(userInfo: [AnyHashable: Any]?) {
        guard let userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isPlaying
            if shouldResumeAfterInterruption {
                stop()
            }
        case .ended:
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if shouldResumeAfterInterruption, options.contains(.shouldResume) {
                start()
            }
            shouldResumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    private func handleAudioRouteChange(userInfo: [AnyHashable: Any]?) {
        guard isPlaying,
              let reasonValue = userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .routeConfigurationChange:
            restartForAudioRouteChange()
        default:
            break
        }
    }
    
    // Use AVAudioEngine for precise, sample-accurate timing
    var audioEngine: AVAudioEngine?
    var playerNode: AVAudioPlayerNode?
    var accentBuffer: AVAudioPCMBuffer?
    var normalBuffer: AVAudioPCMBuffer?
    var accentBufferConverted: AVAudioPCMBuffer? // Pre-converted buffers
    var normalBufferConverted: AVAudioPCMBuffer? // Pre-converted buffers

    /// Estimated delay from scheduled host time until the user hears output.
    var audioOutputLatency: TimeInterval {
        let session = AVAudioSession.sharedInstance()
        let nodeLatency = audioEngine?.outputNode.presentationLatency ?? 0
        return nodeLatency + session.outputLatency + session.ioBufferDuration
    }
}

/// Holds a weak reference so CADisplayLink does not retain the metronome.
final class MetronomeDisplayLinkTarget: NSObject {
    private weak var metronome: Metronome?

    init(metronome: Metronome) {
        self.metronome = metronome
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let metronome else {
            link.invalidate()
            return
        }
        MainActor.assumeIsolated {
            guard metronome.isPlaying else { return }
            metronome.checkAndPlayBeat()
        }
    }
}

enum TimeSignature: String, CaseIterable {
    case twoTwo = "2/2"
    case threeFour = "3/4"
    case fourFour = "4/4"
    case fiveFour = "5/4"
    case sixEight = "6/8"
    case nineEight = "9/8"
    
    var beatsPerMeasure: Int {
        switch self {
        case .twoTwo: return 2
        case .threeFour: return 3
        case .fourFour: return 4
        case .fiveFour: return 5
        case .sixEight: return 6
        case .nineEight: return 9
        }
    }
}

