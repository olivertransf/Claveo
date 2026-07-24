//
//  MetronomeView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct MetronomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var toneGenerator: ToneGeneratorEngine
    @StateObject var metronome = Metronome()
    @StateObject var settingsManager = SettingsManager.shared
    @State var manualToneFrequencyText = ""
    /// Scientific octave for tone generator (1…6, maps to MIDI C1…B6 range).
    @State var selectedToneOctave = 4
    @State var tapTimes: [Date] = []
    @State var showingTemposManagement = false
    @State var showingBeatPattern = false
    @State var showingCustomTimeSignatureSheet = false
    @State var showingVolumeSheet = false
    @State var customTop: Int = 4
    @State var customBottom: Int = 4
    @FocusState var isToneFrequencyFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    /// Last note button tapped (0–11). Non-nil once the user has picked any note.
    @State var selectedNoteIndex: Int? = nil
    
    var favoriteTempos: [Int] {
        settingsManager.settings.favoriteTempos
    }
    
    var autoStopOnTabSwitch: Bool {
        settingsManager.settings.metronomeAutoStopOnTabSwitch
    }
    
    func addFavoriteTempo(_ tempo: Int) {
        var tempos = settingsManager.settings.favoriteTempos
        if !tempos.contains(tempo) {
            tempos.append(tempo)
            tempos.sort()
            settingsManager.update(\.favoriteTempos, value: tempos)
        }
    }
    
    func removeFavoriteTempo(_ tempo: Int) {
        var tempos = settingsManager.settings.favoriteTempos
        tempos.removeAll { $0 == tempo }
        settingsManager.update(\.favoriteTempos, value: tempos)
    }
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationStack {
            mainContentView
        }
        .onAppear {
            manualToneFrequencyText = String(format: "%.1f", toneGenerator.frequency)
        }
        .onChange(of: toneGenerator.frequency) { _, newValue in
            manualToneFrequencyText = String(format: "%.1f", newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .claveoSelectedTabChanged)) { notification in
            guard let idx = notification.userInfo?["index"] as? Int else { return }
            guard idx != 1 else { return }
            if autoStopOnTabSwitch && metronome.isPlaying {
                metronome.stop()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .claveoPlaybackShouldYieldForTuner)) { _ in
            if metronome.isPlaying {
                metronome.stop()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .claveoPlaybackMayResumeAfterTuner)) { _ in
            // Session category is restored when the user presses Start again.
            // Auto-resume is intentionally skipped to avoid surprising clicks after tuner use.
        }
        .sheet(isPresented: $showingCustomTimeSignatureSheet) {
            customTimeSignatureSheet
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingVolumeSheet) {
            volumeSheet
                .environmentObject(themeManager)
        }
    }
    
    var customTimeSignatureSheet: some View {
        NavigationStack {
            Form {
                Section("Top Number") {
                    Stepper(value: $customTop, in: 1...16) {
                        Text("\(customTop)")
                    }
                }
                
                Section("Bottom Number") {
                    Picker("Bottom", selection: $customBottom) {
                        ForEach([1, 2, 4, 8, 16], id: \.self) { value in
                            Text("\(value)")
                                .tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Button("Save Custom Time Signature") {
                        saveCustomTimeSignature()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.accentColor)
                }
            }
            .navigationTitle("Custom Time Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCustomTimeSignatureSheet = false
                    }
                }
            }
        }
    }

    var volumeSheet: some View {
        NavigationStack {
            Form {
                Section("System Volume") {
                    SystemVolumeSlider()
                        .frame(height: 40)
                        .padding(.vertical, 8)
                }

                MetronomeSettingsSection()
            }
            .navigationTitle("Metronome Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingVolumeSheet = false
                    }
                }
            }
        }
    }
}

#Preview {
    MetronomeView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(ToneGeneratorEngine())
}
