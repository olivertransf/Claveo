//
//  AppSettings.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import Foundation

struct AppSettings: Codable {
    // Tuner Settings
    var a4ReferenceFrequency: Double = 440.0
    var showFrequencyDisplay: Bool = true
    
    // Metronome Settings
    var defaultMetronomeTempo: Int = 120
    var metronomeSound: String = MetronomeSound.click.rawValue
    var metronomeHapticEnabled: Bool = true
    var metronomeAutoStopOnTabSwitch: Bool = false
    var favoriteTempos: [Int] = []
    
    // Dictionary Settings
    var showAdvancedDictionaryItems: Bool = true
    
    // Theme Settings
    var accentColor: String = AccentColorOption.blue.rawValue
    
    enum CodingKeys: String, CodingKey {
        case a4ReferenceFrequency, showFrequencyDisplay
        case defaultMetronomeTempo, metronomeSound, metronomeHapticEnabled
        case metronomeAutoStopOnTabSwitch, favoriteTempos
        case showAdvancedDictionaryItems, accentColor
    }
}

