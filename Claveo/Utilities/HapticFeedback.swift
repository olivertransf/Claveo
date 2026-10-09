import SwiftUI
import UIKit

enum HapticFeedback {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func lightImpact(intensity: CGFloat = 1) {
        lightGenerator.impactOccurred(intensity: intensity)
        lightGenerator.prepare()
    }

    static func mediumImpact(intensity: CGFloat = 1) {
        mediumGenerator.impactOccurred(intensity: intensity)
        mediumGenerator.prepare()
    }

    static func softImpact() {
        softGenerator.impactOccurred()
        softGenerator.prepare()
    }

    static func rigidImpact() {
        rigidGenerator.impactOccurred()
        rigidGenerator.prepare()
    }

    static func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    static func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    static func prepareImpacts() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        softGenerator.prepare()
        rigidGenerator.prepare()
    }
}

extension View {
    func hapticButtonPress(trigger isPressed: Bool) -> some View {
        sensoryFeedback(.impact(weight: .light), trigger: isPressed) { _, pressed in
            pressed
        }
    }
}
