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
    @State private var manualFrequencyText = ""
    @FocusState private var isFrequencyFieldFocused: Bool

    private var showFrequencyDisplay: Binding<Bool> {
        Binding(
            get: { settingsManager.settings.showFrequencyDisplay },
            set: { settingsManager.update(\.showFrequencyDisplay, value: $0) }
        )
    }


    private var selectedPreset: FrequencyPreset {
        FrequencyPreset.preset(for: settingsManager.settings.a4ReferenceFrequency)
    }

    private var a4ReferenceFrequency: Binding<Double> {
        Binding(
            get: { settingsManager.settings.a4ReferenceFrequency },
            set: { settingsManager.update(\.a4ReferenceFrequency, value: $0) }
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Text(pitchDetector.note)
                        .font(.system(size: 96, weight: .light, design: .rounded))
                        .monospacedDigit()

                    if showFrequencyDisplay.wrappedValue {
                        Text(String(format: "%.1f Hz", pitchDetector.frequency))
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    TuningMeterView(
                        cents: pitchDetector.cents,
                        note: pitchDetector.note,
                        frequency: pitchDetector.frequency
                    )
                    .environmentObject(themeManager)
                    .frame(height: 200)
                    .padding(.horizontal)

                    PreciseTuningMeterView(
                        cents: pitchDetector.cents,
                        note: pitchDetector.note
                    )
                    .environmentObject(themeManager)
                    .frame(height: 120)
                    .padding(.horizontal)
                }
                .opacity(pitchDetector.isDetecting && pitchDetector.frequency > 0 ? 1.0 : 0.3)

                Spacer()
            }
            .navigationTitle("Tuner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
            }
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
                // Initialize frequency text field
                manualFrequencyText = String(format: "%.1f", settingsManager.settings.a4ReferenceFrequency)

                Task { @MainActor in
                    await pitchDetector.startDetection()
                }
            }
            .onDisappear {
                pitchDetector.stopDetection()
            }
            .onChange(of: settingsManager.settings.a4ReferenceFrequency) { _, _ in
                if pitchDetector.frequency > 0 {
                    pitchDetector.recalculateNote()
                }
            }
        }
    }
}

struct TuningMeterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let cents: Double // Semitone-relative position
    let note: String
    let frequency: Double
    
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    // Calculate notes one semitone below and above
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
        // Find the first digit to separate note name from octave
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
            let _ = geometry.size.height
            
            ZStack {
                // Background scale with gradient
                let margin: CGFloat = 40
                let scaleWidth = width - (margin * 2)
                let centerX = width / 2
                let leftEdge = margin
                let rightEdge = width - margin
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.3),
                                Color.orange.opacity(0.2),
                                Color.green.opacity(0.3),
                                Color.orange.opacity(0.2),
                                Color.red.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 60)
                    .offset(x: 0, y: 0)
                
                // Scale marks - range -100 to +100 cents (one semitone below to one above)
                // Show marks at: -100, -50, 0, +50, +100 cents
                ForEach([-2, -1, 0, 1, 2], id: \.self) { mark in
                    // Position: leftEdge + (mark + 2) / 4 * scaleWidth
                    // This maps -2 to leftEdge, 0 to center, +2 to rightEdge
                    let position = leftEdge + (CGFloat(mark + 2) / 4.0) * scaleWidth
                    
                    // Major marks (every 50 cents) - skip center (0) as it has its own line
                    if mark != 0 {
                        Rectangle()
                            .fill(Color.themeLabel.opacity(0.2))
                            .frame(width: 1, height: 50)
                            .offset(x: position - centerX - 0.5)
                    }
                }
                
                // Note labels at bottom - show note below, current note, note above
                if note != "--" {
                    // Note below (left edge)
                    Text(noteBelow)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.themeSecondaryLabel)
                        .offset(x: leftEdge - centerX, y: 50)
                    
                    // Current note (center)
                    Text(note)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.accentColor)
                        .offset(y: 50)
                    
                    // Note above (right edge)
                    Text(noteAbove)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.themeSecondaryLabel)
                        .offset(x: rightEdge - centerX, y: 50)
                }
                
                // Needle/indicator - shows actual pitch position
                VStack(spacing: 0) {
                    // Needle point
                    Triangle()
                        .fill(needleColor)
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(180))
                    
                    // Needle line
                    Rectangle()
                        .fill(needleColor)
                        .frame(width: 3, height: 60)
                }
                .offset(x: needlePosition(in: width, centerX: centerX, leftEdge: leftEdge, rightEdge: rightEdge, scaleWidth: scaleWidth) - centerX)
            }
        }
    }
    
    private var needleColor: Color {
        let absCents = abs(cents)
        if absCents < 10 {
            return .green
        } else if absCents < 30 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func needlePosition(in width: Double, centerX: CGFloat, leftEdge: CGFloat, rightEdge: CGFloat, scaleWidth: CGFloat) -> Double {
        // Map cents (-50 to +50 relative to current note) to position
        // The display shows one semitone below to one above:
        // - leftEdge = note below (cents = -50 relative to current note)
        // - centerX = current note (cents = 0)
        // - rightEdge = note above (cents = +50 relative to current note)
        
        // Clamp cents to -50 to +50 for main meter display
        let clampedCents = max(-50, min(50, cents))
        let position = centerX + (clampedCents / 50.0) * (scaleWidth / 2)
        
        // Clamp to stay within bounds
        return max(leftEdge, min(rightEdge, position))
    }
}

// Precise tuning meter - shows -15 to +15 cents range for fine-tuning
struct PreciseTuningMeterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let cents: Double // Cents deviation from target note
    let note: String
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let _ = geometry.size.height
            
            ZStack {
                // Background scale with gradient (more green in center for precision)
                let margin: CGFloat = 40
                let scaleWidth = width - (margin * 2)
                let centerX = width / 2
                let leftEdge = margin
                let rightEdge = width - margin
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.3),
                                Color.green.opacity(0.4),
                                Color.green.opacity(0.5),
                                Color.green.opacity(0.4),
                                Color.orange.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 50)
                
                // Scale marks - centered around 0, range -15 to +15 cents
                ForEach([-15, -12, -9, -6, -3, 0, 3, 6, 9, 12, 15], id: \.self) { mark in
                    // Position: center + (mark / 15) * half of scale width
                    let position = centerX + (CGFloat(mark) / 15.0) * (scaleWidth / 2)
                    
                    // Major marks (every 3 cents)
                    Rectangle()
                        .fill(Color.themeLabel.opacity(mark == 0 ? 0.6 : 0.3))
                        .frame(width: mark == 0 ? 1.5 : 0.5, height: mark % 3 == 0 ? 40 : 25)
                        .offset(x: position - centerX - (mark == 0 ? 0.75 : 0.25))
                    
                    // Labels for major marks (every 3 cents)
                    if mark % 3 == 0 && mark != 0 {
                        Text("\(mark > 0 ? "+" : "")\(mark)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.themeSecondaryLabel)
                            .offset(x: position - centerX, y: 35)
                    } else if mark == 0 {
                        Text("0")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .offset(x: position - centerX, y: 28)
                    }
                }
                
                // Note label at bottom
                Text(note)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.accentColor)
                    .offset(y: 40)
                
                // Needle/indicator - shows actual pitch position
                VStack(spacing: 0) {
                    // Needle point
                    Triangle()
                        .fill(preciseNeedleColor)
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(180))
                    
                    // Needle line
                    Rectangle()
                        .fill(preciseNeedleColor)
                        .frame(width: 2, height: 45)
                }
                .offset(x: preciseNeedlePosition(in: width, centerX: centerX, leftEdge: leftEdge, rightEdge: rightEdge, scaleWidth: scaleWidth) - centerX)
            }
        }
    }
    
    private var preciseNeedleColor: Color {
        let absCents = abs(cents)
        if absCents < 2 {
            return .green
        } else if absCents < 8 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func preciseNeedlePosition(in width: Double, centerX: CGFloat, leftEdge: CGFloat, rightEdge: CGFloat, scaleWidth: CGFloat) -> Double {
        // Clamp cents to -15 to +15 for precise view
        let clampedCents = max(-15, min(15, cents))
        
        // Map cents (-15 to +15) to position
        // Center (0 cents) should be at centerX
        // -15 cents maps to leftEdge, +15 cents maps to rightEdge
        let position = centerX + (clampedCents / 15.0) * (scaleWidth / 2)
        
        // Clamp to stay within bounds
        return max(leftEdge, min(rightEdge, position))
    }
}

// Triangle shape for needle point
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    TunerView()
        .environmentObject(ThemeManager.shared)
}
