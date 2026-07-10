//
//  TunerView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct TunerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var pitchDetector = PitchDetector()
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showingPermissionAlert = false
    @State private var displayNote = "--"
    @State private var displayFrequency: Double = 0
    @State private var displayCents: Double = 0

    private var showFrequencyDisplay: Bool {
        settingsManager.settings.showFrequencyDisplay
    }

    private var hasLiveSignal: Bool {
        pitchDetector.isDetecting && pitchDetector.frequency > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Text(displayNote)
                        .font(.system(size: 96, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(displayNote == "--" ? Color.secondary.opacity(0.45) : .primary)

                    if showFrequencyDisplay {
                        Text(displayNote == "--" ? String(localized: "— Hz") : String(format: "%.1f Hz", displayFrequency))
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    TuningMeterView(
                        cents: displayCents,
                        note: displayNote,
                        frequency: displayFrequency
                    )
                    .environmentObject(themeManager)
                    .frame(height: 200)
                    .padding(.horizontal)

                    PreciseTuningMeterView(
                        cents: displayCents,
                        note: displayNote
                    )
                    .environmentObject(themeManager)
                    .frame(height: 120)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Tuner")
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
            .padding()
            .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Microphone access is required to detect pitch.")
            }
            .onAppear {
                Task { @MainActor in
                    await pitchDetector.startDetection()
                }
            }
            .onDisappear {
                pitchDetector.stopDetection()
            }
            .onChange(of: pitchDetector.frequency) { _, _ in refreshDisplay() }
            .onChange(of: pitchDetector.note) { _, _ in refreshDisplay() }
            .onChange(of: pitchDetector.cents) { _, _ in refreshDisplay() }
            .onChange(of: settingsManager.settings.a4ReferenceFrequency) { _, _ in
                if pitchDetector.frequency > 0 {
                    pitchDetector.recalculateNote()
                    refreshDisplay()
                }
            }
        }
    }

    private func refreshDisplay() {
        guard hasLiveSignal else { return }
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
            let margin: CGFloat = 40
            let scaleWidth = width - (margin * 2)
            let centerX = width / 2
            let leftEdge = margin
            let rightEdge = width - margin

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: TunerPalette.coarseGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 60)

                ForEach([-2, -1, 0, 1, 2], id: \.self) { mark in
                    let position = leftEdge + (CGFloat(mark + 2) / 4.0) * scaleWidth

                    Rectangle()
                        .fill(Color.themeLabel.opacity(mark == 0 ? 0.35 : 0.2))
                        .frame(width: mark == 0 ? 1.5 : 1, height: mark == 0 ? 52 : 50)
                        .offset(x: position - centerX - (mark == 0 ? 0.75 : 0.5))
                }

                if note != "--" {
                    Text(noteBelow)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.themeSecondaryLabel)
                        .offset(x: leftEdge - centerX, y: 50)

                    Text(note)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(themeManager.accentColor)
                        .offset(y: 50)

                    Text(noteAbove)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.themeSecondaryLabel)
                        .offset(x: rightEdge - centerX, y: 50)
                }

                TunerNeedle(color: needleColor, lineHeight: 58, lineWidth: 3, headSize: 13)
                    .offset(x: needlePosition(centerX: centerX, leftEdge: leftEdge, rightEdge: rightEdge, scaleWidth: scaleWidth) - centerX)
                    .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.9), value: cents)
            }
        }
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

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let margin: CGFloat = 40
            let scaleWidth = width - (margin * 2)
            let centerX = width / 2
            let leftEdge = margin
            let rightEdge = width - margin

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: TunerPalette.fineGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 50)

                ForEach(Self.fineMarks, id: \.self) { mark in
                    let position = centerX + (CGFloat(mark) / 15.0) * (scaleWidth / 2)

                    Rectangle()
                        .fill(Color.themeLabel.opacity(mark == 0 ? 0.6 : 0.3))
                        .frame(width: mark == 0 ? 1.5 : 0.5, height: mark.isMultiple(of: 3) ? 40.0 : 25.0)
                        .offset(x: position - centerX - (mark == 0 ? 0.75 : 0.25))

                    if mark.isMultiple(of: 3) && mark != 0 {
                        Text("\(mark > 0 ? "+" : "")\(mark)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.themeSecondaryLabel)
                            .offset(x: position - centerX, y: 35)
                    } else if mark == 0 {
                        Text("0")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                            .offset(x: position - centerX, y: 28)
                    }
                }

                Text(note)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.accentColor)
                    .offset(y: 40)

                TunerNeedle(color: preciseNeedleColor, lineHeight: 44, lineWidth: 2.5, headSize: 11)
                    .offset(x: preciseNeedlePosition(centerX: centerX, leftEdge: leftEdge, rightEdge: rightEdge, scaleWidth: scaleWidth) - centerX)
                    .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.9), value: cents)
            }
        }
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
                .shadow(color: color.opacity(0.45), radius: 5, y: 2)

            Capsule(style: .continuous)
                .fill(color)
                .frame(width: lineWidth, height: lineHeight)
                .shadow(color: color.opacity(0.25), radius: 2, y: 1)
        }
    }
}

private enum TunerPalette {
    static let coarseGradient: [Color] = [
        Color(red: 0.94, green: 0.32, blue: 0.36).opacity(0.45),
        Color(red: 0.98, green: 0.62, blue: 0.22).opacity(0.35),
        Color(red: 0.18, green: 0.76, blue: 0.48).opacity(0.55),
        Color(red: 0.98, green: 0.62, blue: 0.22).opacity(0.35),
        Color(red: 0.94, green: 0.32, blue: 0.36).opacity(0.45)
    ]

    static let fineGradient: [Color] = [
        Color(red: 0.98, green: 0.58, blue: 0.18).opacity(0.4),
        Color(red: 0.22, green: 0.74, blue: 0.46).opacity(0.55),
        Color(red: 0.16, green: 0.68, blue: 0.42).opacity(0.62),
        Color(red: 0.22, green: 0.74, blue: 0.46).opacity(0.55),
        Color(red: 0.98, green: 0.58, blue: 0.18).opacity(0.4)
    ]

    static func needleColor(cents: Double, fine: Bool) -> Color {
        let absCents = abs(cents)
        if fine {
            if absCents < 2 { return Color(red: 0.14, green: 0.72, blue: 0.44) }
            if absCents < 8 { return Color(red: 0.96, green: 0.58, blue: 0.14) }
            return Color(red: 0.92, green: 0.30, blue: 0.34)
        }
        if absCents < 10 { return Color(red: 0.14, green: 0.72, blue: 0.44) }
        if absCents < 30 { return Color(red: 0.96, green: 0.58, blue: 0.14) }
        return Color(red: 0.92, green: 0.30, blue: 0.34)
    }
}

#Preview {
    TunerView()
        .environmentObject(ThemeManager.shared)
}
