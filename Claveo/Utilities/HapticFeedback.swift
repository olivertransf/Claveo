//
//  HapticFeedback.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import UIKit

enum HapticFeedback {
    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    static func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

extension View {
    func hapticButtonPress(trigger isPressed: Bool) -> some View {
        sensoryFeedback(.impact(weight: .light), trigger: isPressed) { _, pressed in
            pressed
        }
    }
}
