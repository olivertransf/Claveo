//
//  AppSettings.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

struct AppSettings: Codable {
    // Tuner Settings
    var a4ReferenceFrequency: Double = 440.0
    var showFrequencyDisplay: Bool = true
    
    // Metronome Settings
    var lastMetronomeTempo: Int = 120
    var metronomeSound: String = MetronomeSound.click.rawValue
    var metronomeEmphasizedSound: String = MetronomeSound.click.rawValue
    var metronomeNonEmphasizedSound: String = MetronomeSound.tick.rawValue
    var metronomeVolume: Double = 0.7
    var metronomeHapticEnabled: Bool = true
    var metronomeAutoStopOnTabSwitch: Bool = false
    var favoriteTempos: [Int] = []
    var customTimeSignatureTop: Int? = nil
    var customTimeSignatureBottom: Int? = nil
    
    // Practice Settings
    var defaultPracticeTime: Int = 30 // minutes
    var practiceDurationOptions: [Int] = [15, 30, 45, 60] // minutes
    
    // Theme Settings
    var accentColor: String = AccentColorOption.blue.rawValue
    var colorScheme: String = ColorSchemeOption.system.rawValue
    var showTabBarText: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case a4ReferenceFrequency, showFrequencyDisplay
        case lastMetronomeTempo, metronomeSound, metronomeEmphasizedSound, metronomeNonEmphasizedSound, metronomeVolume, metronomeHapticEnabled
        case metronomeAutoStopOnTabSwitch, favoriteTempos
        case customTimeSignatureTop, customTimeSignatureBottom
        case defaultPracticeTime, practiceDurationOptions
        case accentColor, colorScheme, showTabBarText
    }
}

