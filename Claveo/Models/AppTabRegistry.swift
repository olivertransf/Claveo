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
        case 0: return "Recordings"
        case 1: return "Metronome"
        case 2: return "Tuner"
        case 3: return "Practice"
        case 4: return "Exercises"
        case 5: return "Dictionary"
        case 6: return "Settings"
        case 7: return "Chords"
        default: return "Tab"
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
