//
//  ThemeManager.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import UIKit
import Combine

enum AccentColorOption: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case teal = "Teal"
    case indigo = "Indigo"
    
    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .blue: return String(localized: "Blue")
        case .purple: return String(localized: "Purple")
        case .pink: return String(localized: "Pink")
        case .red: return String(localized: "Red")
        case .orange: return String(localized: "Orange")
        case .yellow: return String(localized: "Yellow")
        case .green: return String(localized: "Green")
        case .teal: return String(localized: "Teal")
        case .indigo: return String(localized: "Indigo")
        }
    }
    
    var color: Color {
        switch self {
        case .blue: return AccentPalette.color(light: (0, 84, 196), dark: (90, 169, 255))
        case .indigo: return AccentPalette.color(light: (55, 48, 163), dark: (165, 160, 255))
        case .purple: return AccentPalette.color(light: (109, 40, 160), dark: (206, 160, 255))
        case .pink: return AccentPalette.color(light: (168, 24, 96), dark: (255, 145, 190))
        case .red: return AccentPalette.color(light: (176, 24, 24), dark: (255, 138, 128))
        case .orange: return AccentPalette.color(light: (154, 52, 0), dark: (255, 171, 92))
        case .yellow: return AccentPalette.color(light: (122, 84, 0), dark: (255, 214, 90))
        case .green: return AccentPalette.color(light: (0, 110, 50), dark: (72, 214, 140))
        case .teal: return AccentPalette.color(light: (0, 102, 102), dark: (64, 214, 204))
        }
    }
}

enum AccentPalette {
    static func color(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { traits in
            let channel = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: channel.0 / 255, green: channel.1 / 255, blue: channel.2 / 255, alpha: 1)
        })
    }
}

enum ColorSchemeOption: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        case .system: return String(localized: "System")
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var accentColorOption: AccentColorOption = .blue {
        didSet {
            // Sync to SettingsManager (but only if not already syncing)
            if !isSyncingFromSettings {
                SettingsManager.shared.setAccentColor(accentColorOption)
            }
        }
    }
    
    @Published var colorSchemeOption: ColorSchemeOption = .system {
        didSet {
            // Sync to SettingsManager (but only if not already syncing)
            if !isSyncingFromColorScheme {
                SettingsManager.shared.setColorScheme(colorSchemeOption)
            }
        }
    }
    
    var accentColor: Color {
        accentColorOption.color
    }

    /// Label color for text and icons drawn on `accentColor`.
    var onAccent: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.07, alpha: 1) : .white
        })
    }

    /// Soft accent fill for badges, chips, and selected rows.
    var accentWash: Color {
        accentColor.opacity(0.2)
    }
    
    var colorScheme: ColorScheme? {
        colorSchemeOption.colorScheme
    }
    
    private var settingsObserver: AnyCancellable?
    private var colorSchemeObserver: AnyCancellable?
    private var isSyncingFromSettings = false
    private var isSyncingFromColorScheme = false
    
    private init() {
        // Load from SettingsManager
        accentColorOption = SettingsManager.shared.accentColorOption
        colorSchemeOption = SettingsManager.shared.colorSchemeOption
        
        // Observe SettingsManager changes for accent color
        settingsObserver = SettingsManager.shared.$settings
            .map { $0.accentColor }
            .removeDuplicates()
            .sink { [weak self] colorRaw in
                guard let self = self else { return }
                if let colorOption = AccentColorOption(rawValue: colorRaw),
                   colorOption != self.accentColorOption {
                    self.isSyncingFromSettings = true
                    self.accentColorOption = colorOption
                    self.isSyncingFromSettings = false
                }
            }
        
        // Observe SettingsManager changes for color scheme
        colorSchemeObserver = SettingsManager.shared.$settings
            .map { $0.colorScheme }
            .removeDuplicates()
            .sink { [weak self] schemeRaw in
                guard let self = self else { return }
                if let schemeOption = ColorSchemeOption(rawValue: schemeRaw),
                   schemeOption != self.colorSchemeOption {
                    self.isSyncingFromColorScheme = true
                    self.colorSchemeOption = schemeOption
                    self.isSyncingFromColorScheme = false
                }
            }
    }
}

// Theme colors that adapt to dark/light mode
extension Color {
    static var themeAccent: Color {
        ThemeManager.shared.accentColor
    }
    
    // Minimal theme colors
    static var themeBackground: Color {
        Color(.systemBackground)
    }
    
    static var themeSecondaryBackground: Color {
        Color(.secondarySystemBackground)
    }
    
    static var themeTertiaryBackground: Color {
        Color(.tertiarySystemBackground)
    }
    
    static var themeGroupedBackground: Color {
        Color(.systemGroupedBackground)
    }
    
    static var themeSecondaryGroupedBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }
    
    static var themeLabel: Color {
        Color(.label)
    }
    
    static var themeSecondaryLabel: Color {
        Color(.secondaryLabel)
    }
    
    static var themeTertiaryLabel: Color {
        Color(.tertiaryLabel)
    }
    
    static var themeSeparator: Color {
        Color(.separator)
    }
    
    static var themeFill: Color {
        Color(.systemFill)
    }
    
    static var themeSecondaryFill: Color {
        Color(.secondarySystemFill)
    }

    /// Amber that stays readable on both light and dark backgrounds.
    static var themeRating: Color {
        AccentPalette.color(light: (176, 96, 0), dark: (255, 179, 64))
    }

    /// Stop and record red that keeps white labels readable.
    static var themeStop: Color {
        Color(red: 210 / 255, green: 48 / 255, blue: 42 / 255)
    }

    static var themeCorrect: Color {
        AccentPalette.color(light: (0, 122, 51), dark: (72, 214, 140))
    }

    static var themeIncorrect: Color {
        AccentPalette.color(light: (176, 32, 28), dark: (255, 138, 128))
    }
}

