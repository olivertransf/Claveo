//
//  SettingsView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showingStorageInfo = false
    
    private var a4ReferenceFrequency: Binding<Double> {
        Binding(
            get: { settingsManager.settings.a4ReferenceFrequency },
            set: { settingsManager.update(\.a4ReferenceFrequency, value: $0) }
        )
    }
    
    private var defaultMetronomeTempo: Binding<Int> {
        Binding(
            get: { settingsManager.settings.defaultMetronomeTempo },
            set: { settingsManager.update(\.defaultMetronomeTempo, value: $0) }
        )
    }
    
    private var showFrequencyDisplay: Binding<Bool> {
        Binding(
            get: { settingsManager.settings.showFrequencyDisplay },
            set: { settingsManager.update(\.showFrequencyDisplay, value: $0) }
        )
    }
    
    private var showAdvancedDictionaryItems: Binding<Bool> {
        Binding(
            get: { settingsManager.settings.showAdvancedDictionaryItems },
            set: { settingsManager.update(\.showAdvancedDictionaryItems, value: $0) }
        )
    }
    
    private var metronomeSound: Binding<MetronomeSound> {
        Binding(
            get: { settingsManager.metronomeSoundEnum },
            set: { settingsManager.setMetronomeSound($0) }
        )
    }
    
    private var metronomeHapticEnabled: Binding<Bool> {
        Binding(
            get: { settingsManager.settings.metronomeHapticEnabled },
            set: { settingsManager.update(\.metronomeHapticEnabled, value: $0) }
        )
    }
    
    private var metronomeAutoStopOnTabSwitch: Binding<Bool> {
        Binding(
            get: { settingsManager.settings.metronomeAutoStopOnTabSwitch },
            set: { settingsManager.update(\.metronomeAutoStopOnTabSwitch, value: $0) }
        )
    }
    
    private var favoriteTempos: [Int] {
        settingsManager.settings.favoriteTempos
    }
    
    private func removeFavoriteTempo(_ tempo: Int) {
        var tempos = settingsManager.settings.favoriteTempos
        tempos.removeAll { $0 == tempo }
        settingsManager.update(\.favoriteTempos, value: tempos)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Tuner Settings
                Section("Tuner") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A4 Reference Frequency")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Slider(value: a4ReferenceFrequency, in: 400...480, step: 1)
                            Text("\(Int(settingsManager.settings.a4ReferenceFrequency)) Hz")
                                .font(.body)
                                .monospacedDigit()
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Preset frequencies
                    Menu("Preset Frequencies") {
                        Button("Modern Standard (A440)") {
                            settingsManager.update(\.a4ReferenceFrequency, value: 440.0)
                        }
                        Button("Baroque (A415)") {
                            settingsManager.update(\.a4ReferenceFrequency, value: 415.0)
                        }
                        Button("Classical (A430)") {
                            settingsManager.update(\.a4ReferenceFrequency, value: 430.0)
                        }
                        Button("Verdi (A432)") {
                            settingsManager.update(\.a4ReferenceFrequency, value: 432.0)
                        }
                        Button("Historical (A409)") {
                            settingsManager.update(\.a4ReferenceFrequency, value: 409.0)
                        }
                        Button("Early Music (A392)") {
                            settingsManager.update(\.a4ReferenceFrequency, value: 392.0)
                        }
                    }
                    
                    Toggle("Show Frequency Display", isOn: showFrequencyDisplay)
                }
                
                // Metronome Settings
                Section("Metronome") {
                    Stepper(value: defaultMetronomeTempo, in: 30...300, step: 1) {
                        HStack {
                            Text("Default Tempo")
                            Spacer()
                            Text("\(settingsManager.settings.defaultMetronomeTempo) BPM")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    
                    Picker("Sound Type", selection: metronomeSound) {
                        ForEach(MetronomeSound.allCases, id: \.self) { sound in
                            Text(sound.rawValue).tag(sound)
                        }
                    }
                    
                    Toggle("Haptic Feedback", isOn: metronomeHapticEnabled)
                    
                    Toggle("Auto-stop when switching tabs", isOn: metronomeAutoStopOnTabSwitch)
                    
                    // Favorite Tempos
                    if favoriteTempos.isEmpty {
                        Text("No favorite tempos")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(favoriteTempos.sorted(), id: \.self) { tempo in
                            HStack {
                                Text("\(tempo) BPM")
                                Spacer()
                                Button(action: {
                                    removeFavoriteTempo(tempo)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let sorted = favoriteTempos.sorted()
                            for index in indexSet {
                                if index < sorted.count {
                                    removeFavoriteTempo(sorted[index])
                                }
                            }
                        }
                    }
                }
                
                // Dictionary Settings
                Section("Dictionary") {
                    Toggle("Show Advanced Symbols & Terms", isOn: showAdvancedDictionaryItems)
                        .help("Hide specialized and lesser-known musical symbols and terms")
                }
                
                // Appearance Settings
                Section("Appearance") {
                    Picker("Accent Color", selection: $themeManager.accentColorOption) {
                        ForEach(AccentColorOption.allCases) { option in
                            HStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 20, height: 20)
                                Text(option.rawValue)
                            }
                            .tag(option)
                        }
                    }
                }
                
                // Storage Settings
                Section("Storage") {
                    Button(action: {
                        showingStorageInfo = true
                    }) {
                        HStack {
                            Text("Storage Location")
                            Spacer()
                            Text(iCloudManager.shared.getStorageLocation())
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    if iCloudManager.shared.isAvailable {
                        Label("iCloud Drive Enabled", systemImage: "icloud.fill")
                            .foregroundColor(.themeAccent)
                    } else {
                        Label("Using Local Storage", systemImage: "folder.fill")
                            .foregroundColor(.themeSecondaryLabel)
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingStorageInfo) {
                StorageInfoView()
            }
        }
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
}

struct StorageInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your recordings are stored in:")
                    .font(.headline)
                
                Text(iCloudManager.shared.getStoragePath())
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.themeTertiaryBackground)
                    .cornerRadius(8)
                
                if iCloudManager.shared.isAvailable {
                    Label("Files will automatically sync to iCloud Drive", systemImage: "icloud.fill")
                        .foregroundColor(.themeAccent)
                } else {
                    Label("iCloud Drive is not available. Files are stored locally.", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
                
                Text("You can access your recordings in the Files app under:")
                    .font(.subheadline)
                    .foregroundColor(.themeSecondaryLabel)
                
                Text("iCloud Drive → Claveo → Documents")
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.themeTertiaryBackground)
                    .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Storage Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

