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
    var lastMetronomeTempo: Int = 120
    var metronomeSound: String = MetronomeSound.click.rawValue
    var metronomeHapticEnabled: Bool = true
    var metronomeAutoStopOnTabSwitch: Bool = false
    var favoriteTempos: [Int] = []
    var customTimeSignatureTop: Int? = nil
    var customTimeSignatureBottom: Int? = nil
    
    // Theme Settings
    var accentColor: String = AccentColorOption.blue.rawValue
    var colorScheme: String = ColorSchemeOption.system.rawValue
    var showTabBarText: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case a4ReferenceFrequency, showFrequencyDisplay
        case lastMetronomeTempo, metronomeSound, metronomeHapticEnabled
        case metronomeAutoStopOnTabSwitch, favoriteTempos
        case customTimeSignatureTop, customTimeSignatureBottom
        case accentColor, colorScheme, showTabBarText
    }
}

