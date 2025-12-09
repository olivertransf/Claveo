//
//  FrequencyPreset.swift
//  Claveo
//
//  Shared frequency presets extracted from SettingsView.
//

import Foundation

enum FrequencyPreset: String, CaseIterable, Identifiable {
    case modernStandard = "Modern Standard (A440)"
    case baroque = "Baroque (A415)"
    case classical = "Classical (A430)"
    case verdi = "Verdi (A432)"
    case historical = "Historical (A409)"
    case earlyMusic = "Early Music (A392)"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .modernStandard: return "A440"
        case .baroque: return "A415"
        case .classical: return "A430"
        case .verdi: return "A432"
        case .historical: return "A409"
        case .earlyMusic: return "A392"
        case .custom: return "Custom"
        }
    }
    
    var fullName: String { rawValue }
    
    var frequency: Double? {
        switch self {
        case .modernStandard: return 440.0
        case .baroque: return 415.0
        case .classical: return 430.0
        case .verdi: return 432.0
        case .historical: return 409.0
        case .earlyMusic: return 392.0
        case .custom: return nil
        }
    }
    
    static func preset(for frequency: Double) -> FrequencyPreset {
        for preset in FrequencyPreset.allCases where preset != .custom {
            if abs(preset.frequency! - frequency) < 0.1 {
                return preset
            }
        }
        return .custom
    }
}


