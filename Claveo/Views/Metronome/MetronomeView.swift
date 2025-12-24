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
    @StateObject var metronome = Metronome()
    @StateObject var settingsManager = SettingsManager.shared
    @State var tapTimes: [Date] = []
    @State var showingTemposManagement = false
    @State var showingBeatPattern = false
    @State var showingCustomTimeSignatureSheet = false
    @State var showingSettingsSheet = false
    @State var showingVolumeSheet = false
    @State var customTop: Int = 4
    @State var customBottom: Int = 4
    
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
        .sheet(isPresented: $showingCustomTimeSignatureSheet) {
            customTimeSignatureSheet
        }
        .sheet(isPresented: $showingSettingsSheet) {
            metronomeSettingsSheet
        }
        .sheet(isPresented: $showingVolumeSheet) {
            volumeSheet
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCustomTimeSignatureSheet = false
                    }
                }
            }
        }
    }

    var metronomeSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Sounds") {
                    // Emphasized sound selection
                    Picker("Emphasized Sound", selection: Binding(
                        get: { settingsManager.metronomeEmphasizedSoundEnum },
                        set: {
                            settingsManager.setMetronomeEmphasizedSound($0)
                            metronome.setupAudioPlayer()
                            // Restart metronome if it's playing to pick up new sounds
                            if metronome.isPlaying {
                                metronome.stop()
                                metronome.start()
                            }
                        }
                    )) {
                        ForEach(MetronomeSound.allCases, id: \.self) { sound in
                            Text(sound.rawValue).tag(sound)
                        }
                    }

                    // Non-emphasized sound selection
                    Picker("Non-Emphasized Sound", selection: Binding(
                        get: { settingsManager.metronomeNonEmphasizedSoundEnum },
                        set: {
                            settingsManager.setMetronomeNonEmphasizedSound($0)
                            metronome.setupAudioPlayer()
                            // Restart metronome if it's playing to pick up new sounds
                            if metronome.isPlaying {
                                metronome.stop()
                                metronome.start()
                            }
                        }
                    )) {
                        ForEach(MetronomeSound.allCases, id: \.self) { sound in
                            Text(sound.rawValue).tag(sound)
                        }
                    }

                    // Volume slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text("\(Int(settingsManager.settings.metronomeVolume * 100))%")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }

                        Slider(value: Binding(
                            get: { settingsManager.settings.metronomeVolume },
                            set: {
                                settingsManager.update(\.metronomeVolume, value: $0)
                                metronome.setupAudioPlayer()
                                // Restart metronome if it's playing to pick up new volume
                                if metronome.isPlaying {
                                    metronome.stop()
                                    metronome.start()
                                }
                            }
                        ), in: 0.0...1.0, step: 0.05)

                        HStack {
                            Text("Quiet").font(.caption2).foregroundColor(.secondary)
                            Spacer()
                            Text("Loud").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }

                Section("Behavior") {
                    Toggle("Haptic Feedback", isOn: Binding(
                        get: { metronome.hapticEnabled },
                        set: { metronome.hapticEnabled = $0; settingsManager.update(\.metronomeHapticEnabled, value: $0) }
                    ))

                    Toggle("Auto-stop when switching tabs", isOn: Binding(
                        get: { settingsManager.settings.metronomeAutoStopOnTabSwitch },
                        set: { settingsManager.update(\.metronomeAutoStopOnTabSwitch, value: $0) }
                    ))
                }
            }
            .navigationTitle("Metronome Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSettingsSheet = false
                    }
                }
            }
        }
    }
    
    var volumeSheet: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title3)
                                .foregroundColor(themeManager.accentColor)
                            Text("System Volume")
                                .font(.headline)
                        }
                        
                        SystemVolumeSlider()
                            .frame(height: 40)
                            .padding(.vertical, 8)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("System Volume")
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
}
