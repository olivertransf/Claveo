//
//  TunerView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct TunerView: View {
    let isTabSelected: Bool

    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var pitchDetector = PitchDetector()
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var displayNote = "--"
    @State private var displayFrequency: Double = 0
    @State private var displayCents: Double = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var showFrequencyDisplay: Bool {
        settingsManager.settings.showFrequencyDisplay
    }

    private var a4Frequency: Double {
        settingsManager.settings.a4ReferenceFrequency
    }

    private var a4Presets: [FrequencyPreset] {
        FrequencyPreset.allCases.filter { $0 != .custom }
    }

    private var a4ToolbarLabel: String {
        "A4 \(Int(a4Frequency.rounded()))"
    }

    private var a4AccessibilityLabel: String {
        String(
            format: String(localized: "A4 reference %d hertz"),
            Int(a4Frequency.rounded())
        )
    }

    private var hasLiveSignal: Bool {
        pitchDetector.isDetecting && pitchDetector.frequency > 0
    }

    private var isListening: Bool {
        pitchDetector.isDetecting
    }

    private var centsLabel: String {
        guard hasLiveSignal else { return String(localized: "—") }
        return String(format: "%+.1f¢", displayCents)
    }

    private var tuningStatusText: String {
        guard hasLiveSignal else {
            return isListening
                ? String(localized: "Listening…")
                : String(localized: "Not listening")
        }
        let absCents = abs(displayCents)
        if absCents < 2 { return String(localized: "In tune") }
        if displayCents < 0 { return String(localized: "Flat") }
        return String(localized: "Sharp")
    }

    private var liveResultAccessibilityValue: String {
        guard hasLiveSignal else { return String(localized: "No pitch detected") }
        return String(
            format: String(localized: "%1$@, %2$.1f hertz, %3$+.1f cents"),
            displayNote,
            displayFrequency,
            displayCents
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if isIPad {
                        iPadLayout
                    } else {
                        phoneLayout
                    }
                }
                .padding(.bottom, isIPad ? 40 : 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tuner")
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
            .toolbar {
                a4ToolbarContent
            }
            .alert(item: $pitchDetector.lifecycleError) { error in
                switch error {
                case .permissionDenied:
                    Alert(
                        title: Text("Microphone Access Required"),
                        message: Text(error.recoverySuggestion ?? ""),
                        primaryButton: .default(Text("Open Settings")) {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                case .audioSession:
                    Alert(
                        title: Text("Audio Unavailable"),
                        message: Text(error.recoverySuggestion ?? ""),
                        primaryButton: .default(Text("Try Again")) {
                            guard isTabSelected else { return }
                            Task { await pitchDetector.startDetection() }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .task(id: isTabSelected) {
                if isTabSelected {
                    if !pitchDetector.isDetecting {
                        await pitchDetector.startDetection()
                    }
                } else {
                    pitchDetector.stopDetection()
                    resetDisplay()
                }
            }
            .onDisappear {
                pitchDetector.stopDetection()
                resetDisplay()
            }
            .onChange(of: pitchDetector.isDetecting) { _, isDetecting in
                if !isDetecting {
                    resetDisplay()
                } else {
                    refreshDisplay()
                }
            }
            .onChange(of: pitchDetector.frequency) { _, _ in refreshDisplay() }
            .onChange(of: settingsManager.settings.a4ReferenceFrequency) { _, _ in
                if pitchDetector.frequency > 0 {
                    pitchDetector.recalculateNote()
                    refreshDisplay()
                }
            }
        }
    }

    // MARK: - Layouts

    @ToolbarContentBuilder
    private var a4ToolbarContent: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .navigationBarTrailing) {
                a4ReferenceMenu
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                a4ReferenceMenu
            }
        }
    }

    private var a4ReferenceMenu: some View {
        Menu {
            ForEach(a4Presets) { preset in
                a4PresetButton(preset)
            }
        } label: {
            Text(a4ToolbarLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(minWidth: 88)
                .background(Color(.tertiarySystemFill), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a4AccessibilityLabel)
        .accessibilityHint(String(localized: "Change A4 reference frequency"))
    }

    @ViewBuilder
    private func a4PresetButton(_ preset: FrequencyPreset) -> some View {
        let isSelected = FrequencyPreset.preset(for: a4Frequency) == preset
        Button {
            if let frequency = preset.frequency {
                settingsManager.update(\.a4ReferenceFrequency, value: frequency)
            }
        } label: {
            if isSelected {
                Label(preset.fullName, systemImage: "checkmark")
            } else {
                Text(preset.fullName)
            }
        }
    }

    private var phoneLayout: some View {
        VStack(spacing: 16) {
            heroCard
                .frame(height: 280)
            metersCard
                .frame(height: 280)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var iPadLayout: some View {
        VStack(spacing: 20) {
            heroCard
                .frame(height: 360)
            metersCard
                .frame(height: 380)
        }
        .frame(maxWidth: 1180)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 24)
    }

    // MARK: - Cards

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }

    private var heroCard: some View {
        VStack(spacing: isIPad ? 22 : 16) {
            HStack {
                Label("Pitch", systemImage: "tuningfork")
                    .font((isIPad ? Font.headline : Font.subheadline).weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                listeningBadge
            }

            HStack(alignment: .center, spacing: isIPad ? 24 : 16) {
                VStack(alignment: isIPad ? .center : .leading, spacing: isIPad ? 6 : 2) {
                    Text(displayNote)
                        .font(.system(size: isIPad ? 136 : 84, weight: .light, design: .rounded))
                        .foregroundStyle(hasLiveSignal ? Color.primary : Color.secondary.opacity(0.45))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(height: isIPad ? 148 : 92, alignment: .center)
                        .frame(maxWidth: .infinity, alignment: isIPad ? .center : .leading)
                        .transaction { $0.animation = nil }

                    Text(frequencySubtitle)
                        .font((isIPad ? Font.body : Font.subheadline).weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(height: isIPad ? 24 : 20, alignment: .center)
                        .frame(maxWidth: .infinity, alignment: isIPad ? .center : .leading)
                        .opacity(showFrequencyDisplay ? 1 : 0)
                        .accessibilityHidden(!showFrequencyDisplay)
                }
                .frame(maxWidth: .infinity, alignment: isIPad ? .center : .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Detected pitch")
                .accessibilityValue(liveResultAccessibilityValue)

                VStack(alignment: .trailing, spacing: isIPad ? 12 : 8) {
                    statusChip(
                        title: String(localized: "Cents"),
                        value: centsLabel,
                        accent: needleAccentColor
                    )
                    statusChip(
                        title: String(localized: "Status"),
                        value: tuningStatusText,
                        accent: needleAccentColor
                    )
                }
                .frame(width: isIPad ? 176 : 128)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            listeningControlButton
        }
        .padding(isIPad ? 24 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panelBackground)
    }

    private var frequencySubtitle: String {
        if showFrequencyDisplay {
            return hasLiveSignal ? String(format: "%.1f Hz", displayFrequency) : String(localized: "— Hz")
        }
        return " "
    }

    private var metersCard: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 12) {
            VStack(alignment: .leading, spacing: isIPad ? 10 : 6) {
                Text("Coarse")
                    .font((isIPad ? Font.subheadline : Font.caption).weight(.semibold))
                    .foregroundStyle(.secondary)
                TuningMeterView(
                    cents: displayCents,
                    note: displayNote,
                    frequency: displayFrequency
                )
                .environmentObject(themeManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: isIPad ? 10 : 6) {
                Text("Fine")
                    .font((isIPad ? Font.subheadline : Font.caption).weight(.semibold))
                    .foregroundStyle(.secondary)
                PreciseTuningMeterView(
                    cents: displayCents,
                    note: displayNote
                )
                .environmentObject(themeManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(isIPad ? 24 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panelBackground)
    }

    private var listeningBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isListening ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(isListening ? String(localized: "On") : String(localized: "Off"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minWidth: 64)
        .background(Color(.tertiarySystemFill), in: Capsule(style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isListening
                ? String(localized: "Tuner listening")
                : String(localized: "Tuner idle")
        )
    }

    private func statusChip(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .trailing, spacing: isIPad ? 4 : 2) {
            Text(title)
                .font((isIPad ? Font.caption : Font.caption2).weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font((isIPad ? Font.body : Font.subheadline).weight(.semibold))
                .foregroundStyle(hasLiveSignal ? accent : .secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, isIPad ? 12 : 8)
        .padding(.horizontal, isIPad ? 14 : 10)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: isIPad ? 12 : 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: isIPad ? 12 : 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var listeningControlButton: some View {
        Button {
            Task {
                if isListening {
                    pitchDetector.stopDetection()
                    resetDisplay()
                } else {
                    await pitchDetector.startDetection()
                }
            }
        } label: {
            Label(
                isListening ? String(localized: "Stop Listening") : String(localized: "Start Listening"),
                systemImage: isListening ? "stop.fill" : "mic.fill"
            )
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isIPad ? 16 : 14)
            .background(
                isListening ? Color.red : themeManager.accentColor,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isListening
                ? String(localized: "Stop tuner")
                : String(localized: "Start tuner")
        )
    }

    private var needleAccentColor: Color {
        TunerPalette.needleColor(cents: displayCents, fine: true)
    }

    // MARK: - Display sync

    private func resetDisplay() {
        displayNote = "--"
        displayFrequency = 0
        displayCents = 0
    }

    private func refreshDisplay() {
        guard hasLiveSignal else {
            resetDisplay()
            return
        }
        displayNote = pitchDetector.note
        displayFrequency = pitchDetector.frequency
        displayCents = pitchDetector.cents
    }
}

struct TuningMeterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let cents: Double
    let note: String
    let frequency: Double

    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    private var accessibilityValue: String {
        guard note != "--" else { return String(localized: "No pitch detected") }
        let direction: String
        if abs(cents) < 1 {
            direction = String(localized: "in tune")
        } else if cents < 0 {
            direction = String(localized: "flat")
        } else {
            direction = String(localized: "sharp")
        }
        return String(
            format: String(localized: "%1$@, %2$+.1f cents, %3$@"),
            note,
            cents,
            direction
        )
    }

    private var noteBelow: String {
        guard note != "--" else { return "--" }
        let (noteName, octave) = parseNote(note)
        guard let noteIndex = noteNames.firstIndex(of: noteName) else { return "--" }

        var newIndex = noteIndex - 1
        var newOctave = octave

        if newIndex < 0 {
            newIndex = 11
            newOctave -= 1
        }

        return "\(noteNames[newIndex])\(newOctave)"
    }

    private var noteAbove: String {
        guard note != "--" else { return "--" }
        let (noteName, octave) = parseNote(note)
        guard let noteIndex = noteNames.firstIndex(of: noteName) else { return "--" }

        var newIndex = noteIndex + 1
        var newOctave = octave

        if newIndex >= 12 {
            newIndex = 0
            newOctave += 1
        }

        return "\(noteNames[newIndex])\(newOctave)"
    }

    private func parseNote(_ noteWithOctave: String) -> (String, Int) {
        if let firstDigitIndex = noteWithOctave.firstIndex(where: { $0.isNumber }) {
            let noteName = String(noteWithOctave[..<firstDigitIndex])
            let octaveString = String(noteWithOctave[firstDigitIndex...])
            if let octave = Int(octaveString) {
                return (noteName, octave)
            }
        }
        return ("--", 0)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let margin: CGFloat = 24
            let scaleWidth = width - (margin * 2)
            let centerX = width / 2
            let leftEdge = margin
            let rightEdge = width - margin

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: TunerPalette.coarseGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                    .frame(height: 56)

                ForEach([-2, -1, 0, 1, 2], id: \.self) { mark in
                    let position = leftEdge + (CGFloat(mark + 2) / 4.0) * scaleWidth

                    Rectangle()
                        .fill(Color.primary.opacity(mark == 0 ? 0.35 : 0.18))
                        .frame(width: mark == 0 ? 1.5 : 1, height: mark == 0 ? 48 : 44)
                        .offset(x: position - centerX - (mark == 0 ? 0.75 : 0.5))
                }

                if note != "--" {
                    Text(noteBelow)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .offset(x: leftEdge - centerX, y: 42)

                    Text(note)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(themeManager.accentColor)
                        .offset(y: 42)

                    Text(noteAbove)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .offset(x: rightEdge - centerX, y: 42)
                }

                TunerNeedle(color: needleColor, lineHeight: 52, lineWidth: 3, headSize: 12)
                    .offset(x: needlePosition(centerX: centerX, leftEdge: leftEdge, rightEdge: rightEdge, scaleWidth: scaleWidth) - centerX)
                    .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.9), value: cents)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tuning meter")
        .accessibilityValue(accessibilityValue)
    }

    private var needleColor: Color {
        TunerPalette.needleColor(cents: cents, fine: false)
    }

    private func needlePosition(centerX: CGFloat, leftEdge: CGFloat, rightEdge: CGFloat, scaleWidth: CGFloat) -> CGFloat {
        let clampedCents = max(-50, min(50, cents))
        let position = centerX + (clampedCents / 50.0) * (scaleWidth / 2)
        return max(leftEdge, min(rightEdge, position))
    }
}

struct PreciseTuningMeterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let cents: Double
    let note: String

    private static let fineMarks = [-15, -12, -9, -6, -3, 0, 3, 6, 9, 12, 15]

    private var accessibilityValue: String {
        guard note != "--" else { return String(localized: "No pitch detected") }
        return String(format: String(localized: "%1$@, %2$+.1f cents"), note, cents)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let margin: CGFloat = 24
            let scaleWidth = width - (margin * 2)
            let centerX = width / 2
            let leftEdge = margin
            let rightEdge = width - margin

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: TunerPalette.fineGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                    .frame(height: 48)

                ForEach(Self.fineMarks, id: \.self) { mark in
                    let position = centerX + (CGFloat(mark) / 15.0) * (scaleWidth / 2)

                    Rectangle()
                        .fill(Color.primary.opacity(mark == 0 ? 0.55 : 0.22))
                        .frame(width: mark == 0 ? 1.5 : 0.5, height: mark.isMultiple(of: 3) ? 36.0 : 22.0)
                        .offset(x: position - centerX - (mark == 0 ? 0.75 : 0.25))

                    if mark.isMultiple(of: 3) && mark != 0 {
                        Text("\(mark > 0 ? "+" : "")\(mark)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .offset(x: position - centerX, y: 32)
                    } else if mark == 0 {
                        Text("0")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(TunerPalette.needleColor(cents: 0, fine: true))
                            .offset(x: position - centerX, y: 26)
                    }
                }

                Text(note)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(themeManager.accentColor)
                    .offset(y: 36)

                TunerNeedle(color: preciseNeedleColor, lineHeight: 40, lineWidth: 2.5, headSize: 10)
                    .offset(x: preciseNeedlePosition(centerX: centerX, leftEdge: leftEdge, rightEdge: rightEdge, scaleWidth: scaleWidth) - centerX)
                    .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.9), value: cents)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fine tuning meter")
        .accessibilityValue(accessibilityValue)
    }

    private var preciseNeedleColor: Color {
        TunerPalette.needleColor(cents: cents, fine: true)
    }

    private func preciseNeedlePosition(centerX: CGFloat, leftEdge: CGFloat, rightEdge: CGFloat, scaleWidth: CGFloat) -> CGFloat {
        let clampedCents = max(-15, min(15, cents))
        let position = centerX + (clampedCents / 15.0) * (scaleWidth / 2)
        return max(leftEdge, min(rightEdge, position))
    }
}

// MARK: - Needle & palette

private struct TunerNeedle: View {
    let color: Color
    var lineHeight: CGFloat
    var lineWidth: CGFloat
    var headSize: CGFloat

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: headSize, height: headSize)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5)
                }
                .shadow(color: color.opacity(0.35), radius: 4, y: 1)

            Capsule(style: .continuous)
                .fill(color)
                .frame(width: lineWidth, height: lineHeight)
        }
    }
}

enum TunerPalette {
    private static let flat = Color(red: 0.86, green: 0.38, blue: 0.36)
    private static let near = Color(red: 0.93, green: 0.66, blue: 0.28)
    private static let inTune = Color(red: 0.22, green: 0.66, blue: 0.48)

    static let coarseGradient: [Color] = [
        flat.opacity(0.38),
        near.opacity(0.32),
        inTune.opacity(0.48),
        near.opacity(0.32),
        flat.opacity(0.38)
    ]

    static let fineGradient: [Color] = [
        near.opacity(0.34),
        inTune.opacity(0.40),
        inTune.opacity(0.52),
        inTune.opacity(0.40),
        near.opacity(0.34)
    ]

    static func needleColor(cents: Double, fine: Bool) -> Color {
        let absCents = abs(cents)
        if fine {
            if absCents < 2 { return inTune }
            if absCents < 8 { return near }
            return flat
        }
        if absCents < 10 { return inTune }
        if absCents < 30 { return near }
        return flat
    }
}

#Preview {
    TunerView(isTabSelected: true)
        .environmentObject(ThemeManager.shared)
}
