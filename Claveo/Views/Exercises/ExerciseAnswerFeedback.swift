//
//  ExerciseAnswerFeedback.swift
//  Claveo
//
//  Shared reveal timing for exercise answer tiles.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

enum ExerciseAnswerFeedback {
    static func reveal(
        correct: Bool,
        show: @escaping () -> Void,
        advance: @escaping () -> Void
    ) {
        if !correct {
            HapticFeedback.rigidImpact()
        }
        Motion.animate(correct ? Motion.interactive : Motion.emphasis) {
            show()
            guard correct else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                Motion.animate {
                    advance()
                }
            }
        }
    }
}
