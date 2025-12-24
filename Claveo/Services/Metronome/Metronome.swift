//
//  Metronome.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Foundation
import Combine
import UIKit
import QuartzCore

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
}

@MainActor
class Metronome: ObservableObject {
    @Published var isPlaying = false
    @Published var tempo: Int = 120 {
        didSet {
            updateInterval()
            // Restart timer if playing to apply new tempo immediately
            if isPlaying {
                restartTimer()
            }
        }
    }
    @Published var timeSignature: TimeSignature = .fourFour
    @Published var customTimeSignature: (top: Int, bottom: Int)? = nil
    @Published var beatPattern: [Bool] = [true, false, false, false]
    @Published var currentBeat: Int = 0
    @Published var soundType: MetronomeSound = .click {
        didSet {
            // Recreate audio players when sound changes
            if isPlaying {
                setupAudioPlayer()
            }
        }
    }
    @Published var hapticEnabled: Bool = true
    
    var timer: Timer?
    var interval: TimeInterval = 0.5
    var nextBeatTime: TimeInterval = 0
    var startTime: TimeInterval = 0
    var beatCount: Int = 0
    var lastBeatTime: TimeInterval = 0
    var isPlayingBeat: Bool = false
    var scheduledBeatCount: Int = 0 // Track how many beats we've pre-scheduled
    let beatsToScheduleAhead = 4 // Pre-schedule 4 beats ahead
    
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
    
    init() {
        let settings = SettingsManager.shared.settings
        
        // Load last tempo (or 120 if no last tempo saved)
        let tempoToLoad = settings.lastMetronomeTempo > 0 ? settings.lastMetronomeTempo : 120
        if tempoToLoad >= 20 && tempoToLoad <= 300 {
            tempo = tempoToLoad
        }
        
        // Load custom time signature
        if let top = settings.customTimeSignatureTop, let bottom = settings.customTimeSignatureBottom {
            customTimeSignature = (top, bottom)
        }
        
        // Load saved preferences
        if let sound = MetronomeSound(rawValue: settings.metronomeSound) {
            soundType = sound
        }
        hapticEnabled = settings.metronomeHapticEnabled
        
        updateInterval()
        updateBeatPattern()
        
        // Prepare haptic generators
        hapticGenerator.prepare()
        hapticGeneratorLight.prepare()
    }
    
    // Use AVAudioEngine for precise, sample-accurate timing
    var audioEngine: AVAudioEngine?
    var playerNode: AVAudioPlayerNode?
    var accentBuffer: AVAudioPCMBuffer?
    var normalBuffer: AVAudioPCMBuffer?
    var accentBufferConverted: AVAudioPCMBuffer? // Pre-converted buffers
    var normalBufferConverted: AVAudioPCMBuffer? // Pre-converted buffers
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

