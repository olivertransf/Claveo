//
//  NoteIdentificationExerciseView.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import UIKit
import VexFoundation

// MARK: - Model

private enum NoteLetter: Int, CaseIterable {
    case c, d, e, f, g, a, b

    var displayLetter: String {
        switch self {
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        case .g: return "G"
        case .a: return "A"
        case .b: return "B"
        }
    }

    fileprivate func diatonicUp() -> NoteLetter {
        let order: [NoteLetter] = [.c, .d, .e, .f, .g, .a, .b]
        let i = order.firstIndex(of: self)!
        return order[(i + 1) % 7]
    }

    fileprivate func diatonicDown() -> NoteLetter {
        let order: [NoteLetter] = [.c, .d, .e, .f, .g, .a, .b]
        let i = order.firstIndex(of: self)!
        return order[(i + 6) % 7]
    }
}

private enum WrittenAccidental: CaseIterable {
    case natural
    case sharp
    case flat

    var smuflCode: String? {
        switch self {
        case .natural: return nil
        case .sharp: return "U+E262"
        case .flat: return "U+E260"
        }
    }
}

private struct NoteQuestion: Equatable, Hashable {
    let clef: ClefName
    let letter: NoteLetter
    let octave: Int
    let accidental: WrittenAccidental

    func matchesSelection(letter: NoteLetter, accidental: WrittenAccidental) -> Bool {
        self.letter == letter && self.accidental == accidental
    }
}

private struct AnswerTileFeedback: Equatable {
    let letter: NoteLetter
    let accidental: WrittenAccidental
    let correct: Bool
}

// MARK: - Clef practice subset

private enum NoteIdentificationClefs {
    static let ordered: [ClefName] = [.treble, .bass, .alto, .tenor]
    static let allEnabled: Set<ClefName> = Set(ordered)

    static func label(_ clef: ClefName) -> String {
        clef.rawValue.capitalized
    }

    /// Bottom-line diatonic pitch for each practice clef (treble E4, bass G2, alto F3, tenor D3).
    static func bottomLineAnchor(for clef: ClefName) -> (letter: NoteLetter, octave: Int) {
        switch clef {
        case .treble: return (.e, 4)
        case .bass: return (.g, 2)
        case .alto: return (.f, 3)
        case .tenor: return (.d, 3)
        default: return (.e, 4)
        }
    }
}

// MARK: - Main exercise

struct NoteIdentificationExerciseView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private static func loadSavedClefsFromSettings() -> Set<ClefName> {
        let raw = SettingsManager.shared.settings.noteIdentificationEnabledClefRawValues
        let allowed = NoteIdentificationClefs.allEnabled
        let parsed = Set(raw.compactMap { ClefName(rawValue: $0) }.filter { allowed.contains($0) })
        return parsed.isEmpty ? allowed : parsed
    }

    private static let initialEnabledClefs = NoteIdentificationExerciseView.loadSavedClefsFromSettings()

    @State private var enabledClefs: Set<ClefName> = NoteIdentificationExerciseView.initialEnabledClefs
    @State private var question = NoteIdentificationExerciseView.randomQuestion(enabledClefs: NoteIdentificationExerciseView.initialEnabledClefs)
    @State private var buttonFeedback: AnswerTileFeedback?

    private let columnLetters: [NoteLetter] = [.c, .d, .e, .f, .g, .a, .b]

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                ScrollView {
                    scrollableColumn
                }
                .scrollIndicators(.hidden)
            } else {
                GeometryReader { geo in
                    let contentW = geo.size.width - 32
                    VStack(alignment: .leading, spacing: 0) {
                        clefToggleSection
                            .padding(.horizontal, 16)
                            .padding(.top, 6)

                        staffCard(contentMaxWidth: contentW)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        Spacer(minLength: 0)

                        answerGrid
                            .padding(.horizontal, 12)
                            .padding(.bottom, max(2, geo.safeAreaInsets.bottom))
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Note Identification")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.accentColor)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newQuestion()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("New note")
            }
        }
        .onChange(of: enabledClefs) { _, newSet in
            persistEnabledClefsToSettings(newSet)
            if !newSet.contains(question.clef) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    question = Self.randomQuestion(enabledClefs: newSet)
                    buttonFeedback = nil
                }
            }
        }
    }

    private func persistEnabledClefsToSettings(_ clefs: Set<ClefName>) {
        let ordered = NoteIdentificationClefs.ordered.filter { clefs.contains($0) }
        SettingsManager.shared.settings.noteIdentificationEnabledClefRawValues = ordered.map(\.rawValue)
        SettingsManager.shared.saveSettings()
    }

    private var clefToggleSection: some View {
        VStack(spacing: 10) {
            Text("Clefs")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(NoteIdentificationClefs.ordered, id: \.rawValue) { clef in
                    clefChip(clef)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func clefChip(_ clef: ClefName) -> some View {
        let on = enabledClefs.contains(clef)
        return Button {
            toggleClef(clef)
        } label: {
            Text(NoteIdentificationClefs.label(clef))
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
        .accessibilityHint(
            on
                ? String(localized: "Included in practice")
                : String(localized: "Excluded from practice")
        )
    }

    private func toggleClef(_ clef: ClefName) {
        if enabledClefs.contains(clef) {
            guard enabledClefs.count > 1 else { return }
            enabledClefs.remove(clef)
        } else {
            enabledClefs.insert(clef)
        }
    }

    private var scrollableColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            clefToggleSection
            staffSectionMeasured
            answerGrid
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var staffSectionMeasured: some View {
        let w = UIScreen.main.bounds.width - 32
        staffCard(contentMaxWidth: w)
    }

    @ViewBuilder
    private func staffCard(contentMaxWidth: CGFloat) -> some View {
        let innerW = max(80, contentMaxWidth - 32)
        let blockH = NoteIdentificationStaffMetrics.notationBlockHeight(innerContentWidth: innerW)
        VStack(spacing: 0) {
            NoteIdentificationVexStaffView(clef: question.clef, easyScoreLine: Self.vexEasyScore(for: question))
                .frame(height: blockH)
                .frame(maxWidth: .infinity)
                .id(question)
        }
        .padding(.top, 2)
        .padding(.bottom, 0)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
    }

    private func newQuestion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            question = Self.randomQuestion(enabledClefs: enabledClefs)
            buttonFeedback = nil
        }
    }

    private func answerCellFill(letter: NoteLetter, accidental: WrittenAccidental) -> Color {
        guard let f = buttonFeedback, f.letter == letter, f.accidental == accidental else {
            return Color(.tertiarySystemFill)
        }
        return f.correct ? Color.green.opacity(0.44) : Color.red.opacity(0.4)
    }

    private func answerCellBorder(letter: NoteLetter, accidental: WrittenAccidental) -> Color {
        guard let f = buttonFeedback, f.letter == letter, f.accidental == accidental else {
            return Color.clear
        }
        return f.correct ? Color.green.opacity(0.55) : Color.red.opacity(0.55)
    }

    private var answerGrid: some View {
        VStack(spacing: 18) {
            labeledRow(String(localized: "Sharps")) {
                gridRow(accidental: .sharp) { "\($0.displayLetter)#" }
            }
            labeledRow(String(localized: "Naturals")) {
                gridRow(accidental: .natural) { $0.displayLetter }
            }
            labeledRow(String(localized: "Flats")) {
                gridRow(accidental: .flat) { "\($0.displayLetter)♭" }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func labeledRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            content()
        }
        .frame(maxWidth: .infinity)
    }

    private func gridRow(
        accidental: WrittenAccidental,
        label: @escaping (NoteLetter) -> String
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(columnLetters, id: \.rawValue) { letter in
                Button {
                    select(letter: letter, accidental: accidental)
                } label: {
                    Text(label(letter))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(answerCellFill(letter: letter, accidental: accidental))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(answerCellBorder(letter: letter, accidental: accidental), lineWidth: 1.5)
                        )
                }
                .buttonStyle(ExerciseAnswerButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func select(letter: NoteLetter, accidental: WrittenAccidental) {
        let correct = question.matchesSelection(letter: letter, accidental: accidental)
        let generator = UIImpactFeedbackGenerator(style: correct ? .light : .rigid)
        generator.prepare()
        generator.impactOccurred()

        withAnimation(correct ? .easeOut(duration: 0.2) : .easeOut(duration: 0.22)) {
            buttonFeedback = AnswerTileFeedback(letter: letter, accidental: accidental, correct: correct)
            if correct {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        question = Self.randomQuestion(enabledClefs: enabledClefs)
                        buttonFeedback = nil
                    }
                }
            }
        }
    }

    private static func randomQuestion(enabledClefs: Set<ClefName>) -> NoteQuestion {
        let pool = NoteIdentificationClefs.allEnabled.intersection(enabledClefs)
        let clef = pool.randomElement() ?? .treble
        let step = Int.random(in: -2...11)
        let anchor = NoteIdentificationClefs.bottomLineAnchor(for: clef)
        let (letter, octave) = advanceDiatonic(from: anchor.letter, octave: anchor.octave, steps: step)
        let accidental = WrittenAccidental.allCases.randomElement() ?? .natural
        return NoteQuestion(clef: clef, letter: letter, octave: octave, accidental: accidental)
    }

    private static func advanceDiatonic(from letter: NoteLetter, octave: Int, steps: Int) -> (NoteLetter, Int) {
        var l = letter
        var o = octave
        if steps > 0 {
            for _ in 0..<steps {
                let prev = l
                l = l.diatonicUp()
                if prev == .b { o += 1 }
            }
        } else if steps < 0 {
            for _ in 0..<(-steps) {
                let prev = l
                l = l.diatonicDown()
                if prev == .c { o -= 1 }
            }
        }
        return (l, o)
    }

    private static func vexEasyScore(for q: NoteQuestion) -> String {
        let body: String
        switch q.accidental {
        case .natural:
            body = "\(q.letter.displayLetter)\(q.octave)"
        case .sharp:
            body = "\(q.letter.displayLetter)#\(q.octave)"
        case .flat:
            body = "\(q.letter.displayLetter)b\(q.octave)"
        }
        return "\(body)/w"
    }
}

// MARK: - Button style

private struct ExerciseAnswerButtonStyle: ButtonStyle {
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
        NoteIdentificationExerciseView()
            .environmentObject(ThemeManager.shared)
    }
}
