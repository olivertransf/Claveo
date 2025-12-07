//
//  TunerView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct TunerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var pitchDetector = PitchDetector()
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showingPermissionAlert = false
    
    private var showFrequencyDisplay: Bool {
        settingsManager.settings.showFrequencyDisplay
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                
                // Main tuner display
                if pitchDetector.isDetecting && pitchDetector.frequency > 0 {
                    VStack(spacing: 30) {
                        // Note display - large and centered
                        Text(pitchDetector.note)
                            .font(.system(size: 96, weight: .ultraLight, design: .rounded))
                            .foregroundColor(.themeLabel)
                            .monospacedDigit()
                        
                        // Frequency display (optional)
                        if showFrequencyDisplay {
                            Text(String(format: "%.1f Hz", pitchDetector.frequency))
                                .font(.title2)
                                .foregroundColor(.themeSecondaryLabel)
                                .monospacedDigit()
                        }
                        
                        // Tuning meter - the main visual indicator
                        TuningMeterView(
                            cents: pitchDetector.cents,
                            note: pitchDetector.note
                        )
                        .environmentObject(themeManager)
                        .frame(height: 200)
                        .padding(.horizontal, 20)
                        
                        // Precise tuning meter - for fine-tuning (5 cents range)
                        PreciseTuningMeterView(
                            cents: pitchDetector.cents,
                            note: pitchDetector.note
                        )
                        .environmentObject(themeManager)
                        .frame(height: 120)
                        .padding(.horizontal, 20)
                    }
                } else {
                    // Waiting state
                    VStack(spacing: 20) {
                        Text("Listening...")
                            .font(.title2)
                            .foregroundColor(.themeSecondaryLabel)
                        
                        Text("Play a note")
                            .font(.subheadline)
                            .foregroundColor(.themeTertiaryLabel)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Tuner")
            .navigationBarTitleDisplayMode(.inline)
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
                // Auto-start tuner when tab appears
                Task {
                    await pitchDetector.startDetection()
                }
            }
            .onDisappear {
                // Auto-stop tuner when tab disappears
                pitchDetector.stopDetection()
            }
            .onChange(of: settingsManager.settings.a4ReferenceFrequency) { _, _ in
                // Recalculate note when reference frequency changes
                if pitchDetector.frequency > 0 {
                    pitchDetector.updateNote(from: pitchDetector.frequency)
                }
            }
        }
    }
}

struct TuningMeterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let cents: Double // -20 to +20
    let note: String
    
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
                
                // Center line - represents the target note (closest note in equal temperament)
//                VStack(spacing: 4) {
//                    // Note label above center line
//                    Text(note)
//                        .font(.system(size: 16, weight: .bold))
//                        .foregroundColor(.themeAccent)
//                        .padding(.horizontal, 8)
//                        .padding(.vertical, 4)
//                        .background(Color.themeBackground)
//                        .cornerRadius(6)
//                    
//                    // Center line (perfectly in tune for target note)
//                    Rectangle()
//                        .fill(Color.themeAccent.opacity(0.8))
//                        .frame(width: 2, height: 60)
//                }
//                .offset(x: centerX - 1, y: -20)
                
                // Scale marks - centered around 0 (in tune), range -20 to +20 cents
                // Only show marks at: -20, -10, 0, +10 (no +20 mark on right edge)
                ForEach([-2, -1, 0, 1, 2], id: \.self) { mark in
                    // Position: leftEdge + (mark + 2) / 4 * scaleWidth
                    // This maps -2 to leftEdge, 0 to center, +1 to 3/4 way to right
                    let position = leftEdge + (CGFloat(mark + 2) / 4.0) * scaleWidth
                    
                    // Major marks (every 10 cents) - skip center (0) as it has its own line
                    if mark != 0 {
                        Rectangle()
                            .fill(Color.themeLabel.opacity(0.2))
                            .frame(width: 1, height: 50)
                            .offset(x: position - centerX - 0.5)
                    }
                    
                    // Labels for major marks
                    if mark == -2 {
                        Text("-20")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.themeSecondaryLabel)
                            .offset(x: position - centerX, y: 38)
                    } else if mark == -1 {
                        Text("-10")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.themeSecondaryLabel)
                            .offset(x: position - centerX, y: 38)
                    } else if mark == 1 {
                        Text("+10")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.themeSecondaryLabel)
                            .offset(x: position - centerX, y: 38)
                    } else if mark == 2 {
                        Text("+20")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.themeSecondaryLabel)
                            .offset(x: position - centerX, y: 38)
                    }
                    // Note: Center (0) is labeled by the note name above the center line
                }
                
                // Note label at bottom - only show center note (target note)
                Text(note)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.accentColor)
                    .offset(y: 50)
                
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
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: cents)
            }
        }
    }
    
    private var needleColor: Color {
        let absCents = abs(cents)
        if absCents < 5 {
            return .green
        } else if absCents < 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func needlePosition(in width: Double, centerX: CGFloat, leftEdge: CGFloat, rightEdge: CGFloat, scaleWidth: CGFloat) -> Double {
        // Map cents (-20 to +20) to position
        // Center (0 cents) should be at centerX
        // -20 cents maps to leftEdge, +20 cents maps to rightEdge
        let position = centerX + (cents / 20.0) * (scaleWidth / 2)
        
        // Clamp to stay within bounds
        return max(leftEdge, min(rightEdge, position))
    }
}

// Precise tuning meter - shows -5 to +5 cents range for fine-tuning
struct PreciseTuningMeterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let cents: Double // -5 to +5 (clamped)
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
                
//                // Center line (perfectly in tune)
//                Rectangle()
//                    .fill(Color.themeAccent.opacity(0.8))
//                    .frame(width: 2, height: 50)
//                    .offset(x: centerX - 1)
                
                // Scale marks - centered around 0, range -5 to +5 cents
                ForEach([-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5], id: \.self) { mark in
                    // Position: center + (mark / 5) * half of scale width
                    let position = centerX + (CGFloat(mark) / 5.0) * (scaleWidth / 2)
                    
                    // Major marks (every 1 cent)
                    Rectangle()
                        .fill(Color.themeLabel.opacity(mark == 0 ? 0.6 : 0.3))
                        .frame(width: mark == 0 ? 1.5 : 0.5, height: mark % 5 == 0 ? 40 : 25)
                        .offset(x: position - centerX - (mark == 0 ? 0.75 : 0.25))
                    
                    // Labels for major marks (every 1 cent)
                    if mark % 5 == 0 && mark != 0 {
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
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: cents)
            }
        }
    }
    
    private var preciseNeedleColor: Color {
        let absCents = abs(cents)
        if absCents < 1 {
            return .green
        } else if absCents < 3 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func preciseNeedlePosition(in width: Double, centerX: CGFloat, leftEdge: CGFloat, rightEdge: CGFloat, scaleWidth: CGFloat) -> Double {
        // Clamp cents to -5 to +5 for precise view
        let clampedCents = max(-5, min(5, cents))
        
        // Map cents (-5 to +5) to position
        // Center (0 cents) should be at centerX
        // -5 cents maps to leftEdge, +5 cents maps to rightEdge
        let position = centerX + (clampedCents / 5.0) * (scaleWidth / 2)
        
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
