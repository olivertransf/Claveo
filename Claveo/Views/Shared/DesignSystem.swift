//
//  DesignSystem.swift
//  Claveo
//
//  Spacing, shape, and motion tokens shared across the app.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import UIKit

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum Radius {
    static let chip: CGFloat = 8
    static let control: CGFloat = 12
    static let card: CGFloat = 16
    static let sheet: CGFloat = 24
}

enum Motion {
    static let interactive = Animation.snappy(duration: 0.25)
    static let layout = Animation.smooth(duration: 0.3)
    static let emphasis = Animation.bouncy(duration: 0.4)
    static let press = Animation.snappy(duration: 0.12)
    static let pulse = Animation.spring(response: 0.16, dampingFraction: 0.62)
    static let meter = Animation.interactiveSpring(response: 0.42, dampingFraction: 0.9)

    static var isReduced: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    /// Runs `changes` inside `withAnimation` unless Reduce Motion is on.
    static func animate(_ animation: Animation = Motion.interactive, _ changes: () -> Void) {
        if isReduced {
            changes()
        } else {
            withAnimation(animation, changes)
        }
    }
}

struct ClaveoPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in
                pressed
            }
    }
}

extension View {
    func claveoCard() -> some View {
        background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }
}
