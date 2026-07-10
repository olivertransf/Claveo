//
//  IntervalEarTrainingExerciseView.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import UIKit

// MARK: - Interval model

private enum EarTrainingInterval: CaseIterable, Identifiable, Hashable {
    case unison
    case minorSecond
    case majorSecond
    case minorThird
    case majorThird
    case perfectFourth
    case tritone
    case perfectFifth
    case minorSixth
    case majorSixth
    case minorSeventh
    case majorSeventh
    case octave

    var id: Self { self }

    var semitones: Int {
        switch self {
        case .unison: return 0
        case .minorSecond: return 1
        case .majorSecond: return 2
        case .minorThird: return 3
        case .majorThird: return 4
        case .perfectFourth: return 5
        case .tritone: return 6
        case .perfectFifth: return 7
        case .minorSixth: return 8
        case .majorSixth: return 9
        case .minorSeventh: return 10
        case .majorSeventh: return 11
        case .octave: return 12
        }
    }

    var title: String {
        switch self {
        case .unison: return String(localized: "Unison")
        case .minorSecond: return String(localized: "Minor 2nd")
        case .majorSecond: return String(localized: "Major 2nd")
        case .minorThird: return String(localized: "Minor 3rd")
        case .majorThird: return String(localized: "Major 3rd")
        case .perfectFourth: return String(localized: "Perfect 4th")
        case .tritone: return String(localized: "Tritone")
        case .perfectFifth: return String(localized: "Perfect 5th")
        case .minorSixth: return String(localized: "Minor 6th")
        case .majorSixth: return String(localized: "Major 6th")
        case .minorSeventh: return String(localized: "Minor 7th")
        case .majorSeventh: return String(localized: "Major 7th")
        case .octave: return String(localized: "Octave")
        }
    }

    /// Pairs roughly like common ear-training layouts: minor-ish left, major/perfect right.
    private static let layoutRows: [(left: EarTrainingInterval?, right: EarTrainingInterval?)] = [
        (nil, .unison),
        (.minorSecond, .majorSecond),
        (.minorThird, .majorThird),
        (.tritone, .perfectFourth),
        (nil, .perfectFifth),
        (.minorSixth, .majorSixth),
        (.minorSeventh, .majorSeventh),
        (nil, .octave),
    ]

    static var layout: [(left: EarTrainingInterval?, right: EarTrainingInterval?)] { layoutRows }
}

private struct IntervalQuestion: Equatable {
    let interval: EarTrainingInterval
    let lowerMidi: Int
    let upperMidi: Int

    static func random() -> IntervalQuestion {
        let interval = EarTrainingInterval.allCases.randomElement() ?? .majorThird
        let s = interval.semitones
        let minRoot = 58
        let maxRoot = 76 - s
        let root = Int.random(in: minRoot...maxRoot)
        return IntervalQuestion(interval: interval, lowerMidi: root, upperMidi: root + s)
    }
}

// MARK: - View

struct IntervalEarTrainingExerciseView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var audio = ShortIntervalNotePlayer()

    @State private var question = IntervalQuestion.random()
    @State private var feedback: (interval: EarTrainingInterval, correct: Bool)?
    @State private var playbackStyle: IntervalEarTrainingPlaybackStyle = .arpeggiated

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                playbackToggleSection
                playCard
                answerCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Interval Ear Training")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.accentColor)
        .onAppear {
            playCurrent()
        }
        .onChange(of: question) { _, _ in
            feedback = nil
            playCurrent()
        }
        .onChange(of: playbackStyle) { _, _ in
            playCurrent()
        }
        .onDisappear {
            audio.stop()
        }
    }

    private var playbackToggleSection: some View {
        VStack(spacing: 10) {
            Text("Playback")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                playbackChip(title: String(localized: "Same time"), style: .simultaneous)
                playbackChip(title: String(localized: "Arpeggiated"), style: .arpeggiated)
            }
        }
        .padding(.bottom, 4)
    }

    private func playbackChip(title: String, style: IntervalEarTrainingPlaybackStyle) -> some View {
        let on = playbackStyle == style
        return Button {
            playbackStyle = style
        } label: {
            Text(title)
                .font(.body.weight(.semibold))
                .minimumScaleFactor(0.85)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(on ? themeManager.accentColor : Color(.tertiarySystemFill))
                )
                .foregroundStyle(on ? Color.white : Color.primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(on ? Color.clear : Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var playCard: some View {
        Button {
            playCurrent()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundStyle(themeManager.accentColor)
                Text(audio.isPlaying ? String(localized: "Playing…") : String(localized: "Play interval"))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if audio.isPlaying {
                    ProgressView()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 10) {
                ForEach(Array(EarTrainingInterval.layout.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 10) {
                        intervalSlot(row.left)
                        intervalSlot(row.right)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func intervalSlot(_ interval: EarTrainingInterval?) -> some View {
        if let interval {
            intervalButton(interval)
                .frame(maxWidth: .infinity)
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
        }
    }

    private func intervalButton(_ interval: EarTrainingInterval) -> some View {
        Button {
            select(interval)
        } label: {
            Text(interval.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(cellFill(for: interval))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(cellBorder(for: interval), lineWidth: 1.5)
                )
        }
        .buttonStyle(IntervalExerciseButtonStyle())
    }

    private func cellFill(for interval: EarTrainingInterval) -> Color {
        guard let f = feedback, f.interval == interval else {
            return Color(.tertiarySystemFill)
        }
        return f.correct ? Color.green.opacity(0.44) : Color.red.opacity(0.4)
    }

    private func cellBorder(for interval: EarTrainingInterval) -> Color {
        guard let f = feedback, f.interval == interval else {
            return Color.clear
        }
        return f.correct ? Color.green.opacity(0.55) : Color.red.opacity(0.55)
    }

    private func playCurrent() {
        audio.play(
            lowerMidi: question.lowerMidi,
            upperMidi: question.upperMidi,
            a4Reference: settingsManager.settings.a4ReferenceFrequency,
            style: playbackStyle
        )
    }

    private func select(_ interval: EarTrainingInterval) {
        let correct = interval == question.interval
        let generator = UIImpactFeedbackGenerator(style: correct ? .light : .rigid)
        generator.prepare()
        generator.impactOccurred()

        withAnimation(correct ? .easeOut(duration: 0.2) : .easeOut(duration: 0.22)) {
            feedback = (interval, correct)
            if correct {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        question = IntervalQuestion.random()
                    }
                }
            }
        }
    }
}

private struct IntervalExerciseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .hapticButtonPress(trigger: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        IntervalEarTrainingExerciseView()
            .environmentObject(ThemeManager.shared)
    }
}
