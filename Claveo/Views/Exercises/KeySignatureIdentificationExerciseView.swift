//
//  KeySignatureIdentificationExerciseView.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import UIKit

// MARK: - Answer grid model (file-local; mirrors note identification)

private enum KSNoteLetter: Int, CaseIterable {
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
}

private enum KSWrittenAccidental: CaseIterable {
    case natural
    case sharp
    case flat
}

private enum KeySigMode: String, CaseIterable {
    case major
    case minor

    var chipTitle: String {
        switch self {
        case .major: return String(localized: "Major")
        case .minor: return String(localized: "Minor")
        }
    }
}

private struct KeySignatureQuestion: Equatable, Hashable {
    let vexKeySpec: String
    let letter: KSNoteLetter
    let accidental: KSWrittenAccidental
    let mode: KeySigMode

    func matchesSelection(letter: KSNoteLetter, accidental: KSWrittenAccidental) -> Bool {
        letter == self.letter && accidental == self.accidental
    }
}

private struct KSAnswerTileFeedback: Equatable {
    let letter: KSNoteLetter
    let accidental: KSWrittenAccidental
    let correct: Bool
}

// MARK: - Question pools & layout constants

private enum KeySignatureExercise {
    static let majorPool: [KeySignatureQuestion] = [
        KeySignatureQuestion(vexKeySpec: "C", letter: .c, accidental: .natural, mode: .major),
        KeySignatureQuestion(vexKeySpec: "G", letter: .g, accidental: .natural, mode: .major),
        KeySignatureQuestion(vexKeySpec: "D", letter: .d, accidental: .natural, mode: .major),
        KeySignatureQuestion(vexKeySpec: "A", letter: .a, accidental: .natural, mode: .major),
        KeySignatureQuestion(vexKeySpec: "E", letter: .e, accidental: .natural, mode: .major),
        KeySignatureQuestion(vexKeySpec: "B", letter: .b, accidental: .natural, mode: .major),
        KeySignatureQuestion(vexKeySpec: "F#", letter: .f, accidental: .sharp, mode: .major),
        KeySignatureQuestion(vexKeySpec: "C#", letter: .c, accidental: .sharp, mode: .major),
        KeySignatureQuestion(vexKeySpec: "F", letter: .f, accidental: .natural, mode: .major),
        KeySignatureQuestion(vexKeySpec: "Bb", letter: .b, accidental: .flat, mode: .major),
        KeySignatureQuestion(vexKeySpec: "Eb", letter: .e, accidental: .flat, mode: .major),
        KeySignatureQuestion(vexKeySpec: "Ab", letter: .a, accidental: .flat, mode: .major),
        KeySignatureQuestion(vexKeySpec: "Db", letter: .d, accidental: .flat, mode: .major),
        KeySignatureQuestion(vexKeySpec: "Gb", letter: .g, accidental: .flat, mode: .major),
        KeySignatureQuestion(vexKeySpec: "Cb", letter: .c, accidental: .flat, mode: .major),
    ]

    static let minorPool: [KeySignatureQuestion] = [
        KeySignatureQuestion(vexKeySpec: "Am", letter: .a, accidental: .natural, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "Em", letter: .e, accidental: .natural, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "Bm", letter: .b, accidental: .natural, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "F#m", letter: .f, accidental: .sharp, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "C#m", letter: .c, accidental: .sharp, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "G#m", letter: .g, accidental: .sharp, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "D#m", letter: .d, accidental: .sharp, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "A#m", letter: .a, accidental: .sharp, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "Dm", letter: .d, accidental: .natural, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "Gm", letter: .g, accidental: .natural, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "Cm", letter: .c, accidental: .natural, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "Fm", letter: .f, accidental: .natural, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "Bbm", letter: .b, accidental: .flat, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "Ebm", letter: .e, accidental: .flat, mode: .minor),
        KeySignatureQuestion(vexKeySpec: "Abm", letter: .a, accidental: .flat, mode: .minor),
    ]

    static let sharpRowSlots: [(KSNoteLetter, KSWrittenAccidental)?] = [
        (.c, .sharp), (.d, .sharp), nil, (.f, .sharp), (.g, .sharp), (.a, .sharp), nil,
    ]

    static let flatRowSlots: [(KSNoteLetter, KSWrittenAccidental)?] = [
        (.c, .flat), (.d, .flat), (.e, .flat), nil, (.g, .flat), (.a, .flat), (.b, .flat),
    ]

    static let naturalLetters: [KSNoteLetter] = [.c, .d, .e, .f, .g, .a, .b]

    /// Sharps/flats count for canvas sizing (Vex relative major/minor pairs share a signature).
    static func accidentalCount(vexKeySpec: String) -> Int {
        switch vexKeySpec {
        case "C", "Am": return 0
        case "G", "Em", "F", "Dm": return 1
        case "D", "Bm", "Bb", "Gm": return 2
        case "A", "F#m", "Eb", "Cm": return 3
        case "E", "C#m", "Ab", "Fm": return 4
        case "B", "G#m", "Db", "Bbm": return 5
        case "F#", "D#m", "Gb", "Ebm": return 6
        case "C#", "A#m", "Cb", "Abm": return 7
        default: return 0
        }
    }

    static func randomQuestion(enabledModes: Set<KeySigMode>) -> KeySignatureQuestion {
        let parts: [[KeySignatureQuestion]] = KeySigMode.allCases.compactMap { m in
            guard enabledModes.contains(m) else { return nil }
            return m == .major ? majorPool : minorPool
        }
        let pool = parts.flatMap { $0 }
        return pool.randomElement() ?? majorPool[0]
    }
}

// MARK: - View

struct KeySignatureIdentificationExerciseView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private static func loadSavedModesFromSettings() -> Set<KeySigMode> {
        let raw = SettingsManager.shared.settings.keySignatureIdentificationEnabledModeRawValues
        let allowed = Set(KeySigMode.allCases)
        let parsed = Set(raw.compactMap { KeySigMode(rawValue: $0) }.filter { allowed.contains($0) })
        return parsed.isEmpty ? allowed : parsed
    }

    private static let initialEnabledModes = KeySignatureIdentificationExerciseView.loadSavedModesFromSettings()

    @State private var enabledModes: Set<KeySigMode> = KeySignatureIdentificationExerciseView.initialEnabledModes
    @State private var question = KeySignatureExercise.randomQuestion(
        enabledModes: KeySignatureIdentificationExerciseView.initialEnabledModes
    )
    @State private var buttonFeedback: KSAnswerTileFeedback?

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
                        promptSection
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        modeToggleSection
                            .padding(.horizontal, 16)
                            .padding(.top, 10)

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
        .navigationTitle("Key Signature ID")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.accentColor)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newQuestion()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("New key signature")
            }
        }
        .onChange(of: enabledModes) { _, newSet in
            persistEnabledModesToSettings(newSet)
            if !newSet.contains(question.mode) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    question = KeySignatureExercise.randomQuestion(enabledModes: newSet)
                    buttonFeedback = nil
                }
            }
        }
    }

    private func persistEnabledModesToSettings(_ modes: Set<KeySigMode>) {
        let ordered = KeySigMode.allCases.filter { modes.contains($0) }
        SettingsManager.shared.settings.keySignatureIdentificationEnabledModeRawValues = ordered.map(\.rawValue)
        SettingsManager.shared.saveSettings()
    }

    private var modeToggleSection: some View {
        VStack(spacing: 10) {
            Text("Mode")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                ForEach(KeySigMode.allCases, id: \.rawValue) { mode in
                    modeChip(mode)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func modeChip(_ mode: KeySigMode) -> some View {
        let on = enabledModes.contains(mode)
        return Button {
            toggleMode(mode)
        } label: {
            Text(mode.chipTitle)
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

    private func toggleMode(_ mode: KeySigMode) {
        if enabledModes.contains(mode) {
            guard enabledModes.count > 1 else { return }
            enabledModes.remove(mode)
        } else {
            enabledModes.insert(mode)
        }
    }

    private var promptSection: some View {
        VStack(spacing: 6) {
            Text(
                question.mode == .major
                    ? String(localized: "Treble clef — which major key?")
                    : String(localized: "Treble clef — which minor key?")
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text(
                question.mode == .major
                    ? String(localized: "__ Major")
                    : String(localized: "__ minor")
            )
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var scrollableColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            promptSection
            modeToggleSection
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
        let acc = KeySignatureExercise.accidentalCount(vexKeySpec: question.vexKeySpec)
        VStack(spacing: 0) {
            KeySignatureIdentificationVexStaffView(vexKeySpec: question.vexKeySpec, accidentalCount: acc)
                .frame(height: blockH)
                .frame(maxWidth: .infinity)
                .id("\(question.vexKeySpec)-\(question.mode.rawValue)")
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
            question = KeySignatureExercise.randomQuestion(enabledModes: enabledModes)
            buttonFeedback = nil
        }
    }

    private func answerCellFill(letter: KSNoteLetter, accidental: KSWrittenAccidental) -> Color {
        guard let f = buttonFeedback, f.letter == letter, f.accidental == accidental else {
            return Color(.tertiarySystemFill)
        }
        return f.correct ? Color.green.opacity(0.44) : Color.red.opacity(0.4)
    }

    private func answerCellBorder(letter: KSNoteLetter, accidental: KSWrittenAccidental) -> Color {
        guard let f = buttonFeedback, f.letter == letter, f.accidental == accidental else {
            return Color.clear
        }
        return f.correct ? Color.green.opacity(0.55) : Color.red.opacity(0.55)
    }

    private var answerGrid: some View {
        VStack(spacing: 18) {
            labeledRow(String(localized: "Sharps")) {
                gridRow(slots: KeySignatureExercise.sharpRowSlots)
            }
            labeledRow(String(localized: "Naturals")) {
                HStack(spacing: 6) {
                    ForEach(KeySignatureExercise.naturalLetters, id: \.rawValue) { letter in
                        answerButton(letter: letter, accidental: .natural, label: letter.displayLetter)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            labeledRow(String(localized: "Flats")) {
                gridRow(slots: KeySignatureExercise.flatRowSlots)
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

    private func gridRow(slots: [(KSNoteLetter, KSWrittenAccidental)?]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                if let (letter, acc) = slot {
                    answerButton(letter: letter, accidental: acc, label: slotLabel(letter: letter, accidental: acc))
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func slotLabel(letter: KSNoteLetter, accidental: KSWrittenAccidental) -> String {
        switch accidental {
        case .natural: return letter.displayLetter
        case .sharp: return "\(letter.displayLetter)#"
        case .flat: return "\(letter.displayLetter)♭"
        }
    }

    private func answerButton(letter: KSNoteLetter, accidental: KSWrittenAccidental, label: String) -> some View {
        Button {
            select(letter: letter, accidental: accidental)
        } label: {
            Text(label)
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
        .buttonStyle(KeySigExerciseAnswerButtonStyle())
    }

    private func select(letter: KSNoteLetter, accidental: KSWrittenAccidental) {
        let correct = question.matchesSelection(letter: letter, accidental: accidental)
        let generator = UIImpactFeedbackGenerator(style: correct ? .light : .rigid)
        generator.prepare()
        generator.impactOccurred()

        withAnimation(correct ? .easeOut(duration: 0.2) : .easeOut(duration: 0.22)) {
            buttonFeedback = KSAnswerTileFeedback(letter: letter, accidental: accidental, correct: correct)
            if correct {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        question = KeySignatureExercise.randomQuestion(enabledModes: enabledModes)
                        buttonFeedback = nil
                    }
                }
            }
        }
    }
}

private struct KeySigExerciseAnswerButtonStyle: ButtonStyle {
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
        KeySignatureIdentificationExerciseView()
            .environmentObject(ThemeManager.shared)
    }
}
