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
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                // Note display
                VStack(spacing: 20) {
                    Text(pitchDetector.note)
                        .font(.system(size: 96, weight: .ultraLight, design: .rounded))
                        .foregroundColor(noteColor)
                        .monospacedDigit()
                        .animation(.easeInOut(duration: 0.2), value: pitchDetector.note)
                    
                    if pitchDetector.isDetecting && pitchDetector.frequency > 0 {
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f Hz", pitchDetector.frequency))
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                            
                            if abs(pitchDetector.cents) > 1 {
                                Text(String(format: "%.0f cents %@", abs(pitchDetector.cents), pitchDetector.cents > 0 ? "sharp" : "flat"))
                                    .font(.caption)
                                    .foregroundColor(noteColor)
                            }
                        }
                    }
                }
                
                // Tuning indicator
                if pitchDetector.isDetecting {
                    VStack(spacing: 16) {
                        // Visual tuning meter
                        GeometryReader { geometry in
                            ZStack(alignment: .center) {
                                // Background track with gradient
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [.red.opacity(0.3), .green.opacity(0.3), .red.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 12)
                                
                                // Center line (in tune)
                                Rectangle()
                                    .fill(Color.primary.opacity(0.5))
                                    .frame(width: 2, height: 30)
                                    .offset(x: geometry.size.width / 2 - 1)
                                
                                // Indicator dot with shadow
                                ZStack {
                                    Circle()
                                        .fill(noteColor)
                                        .frame(width: 24, height: 24)
                                    Circle()
                                        .fill(noteColor.opacity(0.3))
                                        .frame(width: 32, height: 32)
                                        .blur(radius: 4)
                                }
                                .offset(x: indicatorPosition(in: geometry.size.width))
                                .animation(.spring(response: 0.15, dampingFraction: 0.8), value: pitchDetector.cents)
                            }
                        }
                        .frame(height: 50)
                        .padding(.horizontal, 40)
                        
                        // Scale labels
                        HStack {
                            Text("Flat")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("In Tune")
                                .font(.caption)
                                .foregroundColor(.green) // Keep green for semantic meaning
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("Sharp")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 40)
                        
                        // Status text
                        if abs(pitchDetector.cents) < 1 {
                            Text("Perfect!")
                                .font(.headline)
                                .foregroundColor(.green)
                        } else if abs(pitchDetector.cents) < 5 {
                            Text("Very close")
                                .font(.subheadline)
                                .foregroundColor(.green.opacity(0.8))
                        } else if abs(pitchDetector.cents) < 20 {
                            Text("Getting there")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        } else {
                            Text("Keep adjusting")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Ready to tune")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Tap the microphone button to start")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Start/Stop button
                Button(action: {
                    if pitchDetector.isDetecting {
                        pitchDetector.stopDetection()
                    } else {
                        Task {
                            await pitchDetector.startDetection()
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(pitchDetector.isDetecting ? Color.themeAccent : Color.themeLabel)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: pitchDetector.isDetecting ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
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
                // Start tuner when tab appears
                if !pitchDetector.isDetecting {
                    Task {
                        await pitchDetector.startDetection()
                    }
                }
            }
            .onDisappear {
                // Stop tuner when tab disappears
                if pitchDetector.isDetecting {
                    pitchDetector.stopDetection()
                }
            }
        }
    }
    
    private var noteColor: Color {
        if !pitchDetector.isDetecting || pitchDetector.frequency == 0 {
            return .primary
        }
        
        let absCents = abs(pitchDetector.cents)
        if absCents < 5 {
            return .green
        } else if absCents < 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func indicatorPosition(in width: Double) -> Double {
        // Map cents (-50 to +50) to position
        let center = width / 2
        let position = center + (pitchDetector.cents / 50.0) * (width / 2 - 20)
        return max(10, min(width - 10, position - 10))
    }
}

#Preview {
    TunerView()
}

