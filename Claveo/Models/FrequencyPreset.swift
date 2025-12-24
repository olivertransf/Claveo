//
//  FrequencyPreset.swift
//  Claveo
//
//  Shared frequency presets extracted from SettingsView.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

enum FrequencyPreset: String, CaseIterable, Identifiable {
    case scientificPitch = "Scientific Pitch (A432)"
    case concertPitch = "Concert Pitch (A440)"
    case diapasonNormal = "Diapason Normal (A435)"
    case baroquePitch = "Baroque Pitch (A415)"
    case classicalPitch = "Classical Pitch (A430)"
    case chorton = "Chorton (A466)"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .scientificPitch: return "A432"
        case .concertPitch: return "A440"
        case .diapasonNormal: return "A435"
        case .baroquePitch: return "A415"
        case .classicalPitch: return "A430"
        case .chorton: return "A466"
        case .custom: return "Custom"
        }
    }
    
    var fullName: String {
        switch self {
        case .scientificPitch: return "Scientific Pitch (A432)"
        case .concertPitch: return "Concert Pitch (A440)"
        case .diapasonNormal: return "Diapason Normal (A435)"
        case .baroquePitch: return "Baroque Pitch (A415)"
        case .classicalPitch: return "Classical Pitch (A430)"
        case .chorton: return "Chorton (A466)"
        case .custom: return "Custom"
        }
    }
    
    var frequency: Double? {
        switch self {
        case .scientificPitch: return 432.0
        case .concertPitch: return 440.0
        case .diapasonNormal: return 435.0
        case .baroquePitch: return 415.0
        case .classicalPitch: return 430.0
        case .chorton: return 466.0
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


