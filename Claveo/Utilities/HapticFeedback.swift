import SwiftUI
import UIKit

enum HapticFeedback {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    static func lightImpact() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    static func mediumImpact() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    static func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
}

extension View {
    func hapticButtonPress(trigger isPressed: Bool) -> some View {
        sensoryFeedback(.impact(weight: .light), trigger: isPressed) { _, pressed in
            pressed
        }
    }
}
