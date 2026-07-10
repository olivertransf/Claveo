//
//  AppTabRegistry.swift
//  Claveo
//
//  Semantic tab indices (0–7) shared by ContentView and settings.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

enum AppTabRegistry {
    static let semanticIds: [Int] = [0, 1, 2, 3, 4, 5, 6, 7]

    static func title(_ id: Int) -> String {
        switch id {
        case 0: return String(localized: "Recordings")
        case 1: return String(localized: "Metronome")
        case 2: return String(localized: "Tuner")
        case 3: return String(localized: "Practice")
        case 4: return String(localized: "Exercises")
        case 5: return String(localized: "Dictionary")
        case 6: return String(localized: "Settings")
        case 7: return String(localized: "Chords")
        default: return String(localized: "Tab")
        }
    }

    static func systemImage(_ id: Int) -> String {
        switch id {
        case 0: return "waveform"
        case 1: return "metronome"
        case 2: return "tuningfork"
        case 3: return "calendar.badge.clock"
        case 4: return "list.bullet.clipboard"
        case 5: return "book"
        case 6: return "gear"
        case 7: return "music.note.list"
        default: return "questionmark"
        }
    }
}
