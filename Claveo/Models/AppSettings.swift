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
    /// When true, stop the reference tone leaving the Metronome tab. Default false = tone keeps playing in background.
    var stopToneWhenLeavingMetronomeTab: Bool = false
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

    // Navigation
    var lastSelectedTab: Int = 0

    /// Order of main tabs (semantic ids 0…7). First four = bottom bar on compact width; remaining four = More menu / trailing tabs.
    /// Default matches historical layout: Chords before Settings in the overflow strip.
    var tabBarCustomizationOrder: [Int] = [0, 1, 2, 3, 4, 5, 7, 6]

    static let defaultTabBarCustomizationOrder: [Int] = [0, 1, 2, 3, 4, 5, 7, 6]

    static func normalizedTabBarOrder(_ order: [Int]) -> [Int] {
        guard order.count == 8, Set(order) == Set(0...7) else {
            return defaultTabBarCustomizationOrder
        }
        return order
    }

    // Metronome pattern
    var metronomeTimeSignature: String = TimeSignature.fourFour.rawValue
    var metronomeBeatPattern: [Bool] = []

    /// Clef names enabled for Note Identification (`ClefName.rawValue`: treble, bass, alto, tenor).
    var noteIdentificationEnabledClefRawValues: [String] = ["treble", "bass", "alto", "tenor"]

    /// Modes enabled for Key Signature Identification (`"major"`, `"minor"`).
    var keySignatureIdentificationEnabledModeRawValues: [String] = ["major", "minor"]

    enum CodingKeys: String, CodingKey {
        case a4ReferenceFrequency, showFrequencyDisplay
        case lastMetronomeTempo, metronomeSound, metronomeEmphasizedSound, metronomeNonEmphasizedSound, metronomeVolume, metronomeHapticEnabled
        case metronomeAutoStopOnTabSwitch, stopToneWhenLeavingMetronomeTab, favoriteTempos
        case customTimeSignatureTop, customTimeSignatureBottom
        case defaultPracticeTime, practiceDurationOptions
        case accentColor, colorScheme, showTabBarText
        case lastSelectedTab, tabBarCustomizationOrder
        case metronomeTimeSignature, metronomeBeatPattern
        case noteIdentificationEnabledClefRawValues
        case keySignatureIdentificationEnabledModeRawValues
    }
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        a4ReferenceFrequency = try c.decodeIfPresent(Double.self, forKey: .a4ReferenceFrequency) ?? 440.0
        showFrequencyDisplay = try c.decodeIfPresent(Bool.self, forKey: .showFrequencyDisplay) ?? true
        lastMetronomeTempo = try c.decodeIfPresent(Int.self, forKey: .lastMetronomeTempo) ?? 120
        metronomeSound = try c.decodeIfPresent(String.self, forKey: .metronomeSound) ?? MetronomeSound.click.rawValue
        metronomeEmphasizedSound = try c.decodeIfPresent(String.self, forKey: .metronomeEmphasizedSound) ?? MetronomeSound.click.rawValue
        metronomeNonEmphasizedSound = try c.decodeIfPresent(String.self, forKey: .metronomeNonEmphasizedSound) ?? MetronomeSound.tick.rawValue
        metronomeVolume = try c.decodeIfPresent(Double.self, forKey: .metronomeVolume) ?? 0.7
        metronomeHapticEnabled = try c.decodeIfPresent(Bool.self, forKey: .metronomeHapticEnabled) ?? true
        metronomeAutoStopOnTabSwitch = try c.decodeIfPresent(Bool.self, forKey: .metronomeAutoStopOnTabSwitch) ?? false
        stopToneWhenLeavingMetronomeTab = try c.decodeIfPresent(Bool.self, forKey: .stopToneWhenLeavingMetronomeTab) ?? false
        favoriteTempos = try c.decodeIfPresent([Int].self, forKey: .favoriteTempos) ?? []
        customTimeSignatureTop = try c.decodeIfPresent(Int.self, forKey: .customTimeSignatureTop)
        customTimeSignatureBottom = try c.decodeIfPresent(Int.self, forKey: .customTimeSignatureBottom)
        defaultPracticeTime = try c.decodeIfPresent(Int.self, forKey: .defaultPracticeTime) ?? 30
        practiceDurationOptions = try c.decodeIfPresent([Int].self, forKey: .practiceDurationOptions) ?? [15, 30, 45, 60]
        accentColor = try c.decodeIfPresent(String.self, forKey: .accentColor) ?? AccentColorOption.blue.rawValue
        colorScheme = try c.decodeIfPresent(String.self, forKey: .colorScheme) ?? ColorSchemeOption.system.rawValue
        showTabBarText = try c.decodeIfPresent(Bool.self, forKey: .showTabBarText) ?? false
        lastSelectedTab = try c.decodeIfPresent(Int.self, forKey: .lastSelectedTab) ?? 0
        let rawOrder = try c.decodeIfPresent([Int].self, forKey: .tabBarCustomizationOrder)
        tabBarCustomizationOrder = AppSettings.normalizedTabBarOrder(rawOrder ?? AppSettings.defaultTabBarCustomizationOrder)
        metronomeTimeSignature = try c.decodeIfPresent(String.self, forKey: .metronomeTimeSignature) ?? TimeSignature.fourFour.rawValue
        metronomeBeatPattern = try c.decodeIfPresent([Bool].self, forKey: .metronomeBeatPattern) ?? []
        noteIdentificationEnabledClefRawValues = try c.decodeIfPresent([String].self, forKey: .noteIdentificationEnabledClefRawValues)
            ?? ["treble", "bass", "alto", "tenor"]
        keySignatureIdentificationEnabledModeRawValues = try c.decodeIfPresent([String].self, forKey: .keySignatureIdentificationEnabledModeRawValues)
            ?? ["major", "minor"]
    }
}

