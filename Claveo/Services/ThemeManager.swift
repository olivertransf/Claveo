//
//  ThemeManager.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

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

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var accentColorOption: AccentColorOption = .blue {
        didSet {
            UserDefaults.standard.set(accentColorOption.rawValue, forKey: "accentColor")
        }
    }
    
    var accentColor: Color {
        accentColorOption.color
    }
    
    private init() {
        if let savedColor = UserDefaults.standard.string(forKey: "accentColor"),
           let colorOption = AccentColorOption(rawValue: savedColor) {
            accentColorOption = colorOption
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

