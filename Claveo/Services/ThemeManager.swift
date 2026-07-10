//
//  ThemeManager.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
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
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        case .indigo: return .indigo
        }
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
}

