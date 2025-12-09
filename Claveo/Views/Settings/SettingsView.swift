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
    @State private var manualFrequencyText = ""
    @FocusState private var isFrequencyFieldFocused: Bool
    
    private var selectedPreset: FrequencyPreset {
        FrequencyPreset.preset(for: settingsManager.settings.a4ReferenceFrequency)
    }
    
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
    
    private var showTabBarText: Binding<Bool> {
        Binding(
            get: { settingsManager.settings.showTabBarText },
            set: { settingsManager.update(\.showTabBarText, value: $0) }
        )
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
                            TextField("Hz", text: $manualFrequencyText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                                .textFieldStyle(.roundedBorder)
                                .focused($isFrequencyFieldFocused)
                                .onSubmit {
                                    if let value = Double(manualFrequencyText), value >= 400 && value <= 480 {
                                        settingsManager.update(\.a4ReferenceFrequency, value: value)
                                    } else {
                                        // Reset to current value if invalid
                                        manualFrequencyText = String(format: "%.1f", settingsManager.settings.a4ReferenceFrequency)
                                    }
                                    isFrequencyFieldFocused = false
                                }
                                .onChange(of: settingsManager.settings.a4ReferenceFrequency) { _, newValue in
                                    // Only update if user isn't actively editing the field
                                    if !isFrequencyFieldFocused {
                                        manualFrequencyText = String(format: "%.1f", newValue)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                    .onAppear {
                        manualFrequencyText = String(format: "%.1f", settingsManager.settings.a4ReferenceFrequency)
                    }
                    
                    // Preset frequencies
                    Menu {
                        ForEach(FrequencyPreset.allCases) { preset in
                            Button(action: {
                                if let frequency = preset.frequency {
                                    settingsManager.update(\.a4ReferenceFrequency, value: frequency)
                                }
                            }) {
                                HStack {
                                    if preset == .custom {
                                        Text(preset.displayName)
                                    } else {
                                        Text(preset.fullName)
                                    }
                                    if selectedPreset == preset {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                }
                            }
                        }
                    } label: {
                        Text("Preset Frequencies")
                    }
                    
                    Toggle("Show Frequency Display", isOn: showFrequencyDisplay)
                }
                
                // Metronome Settings
                Section("Metronome") {
                    HStack {
                        Text("Default Tempo")
                        Spacer()
                        TextField("BPM", value: defaultMetronomeTempo, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: settingsManager.settings.defaultMetronomeTempo) { _, newValue in
                                // Clamp to valid range
                                if newValue < 20 {
                                    settingsManager.update(\.defaultMetronomeTempo, value: 20)
                                } else if newValue > 300 {
                                    settingsManager.update(\.defaultMetronomeTempo, value: 300)
                                }
                            }
                        Text("BPM")
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("Sound Type", selection: metronomeSound) {
                        ForEach(MetronomeSound.allCases, id: \.self) { sound in
                            Text(sound.rawValue).tag(sound)
                        }
                    }
                    
                    Toggle("Haptic Feedback", isOn: metronomeHapticEnabled)
                    
                    Toggle("Auto-stop when switching tabs", isOn: metronomeAutoStopOnTabSwitch)
                }
                
                // Dictionary Settings
                Section("Dictionary") {
                    Toggle("Show Advanced Symbols & Terms", isOn: showAdvancedDictionaryItems)
                        .help("Hide specialized and lesser-known musical symbols and terms")
                }
                
                // Appearance Settings
                Section("Appearance") {
                    Picker("Color Scheme", selection: $themeManager.colorSchemeOption) {
                        ForEach(ColorSchemeOption.allCases) { option in
                            Text(option.rawValue)
                                .tag(option)
                        }
                    }
                    
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
                    
                    Toggle("Show Tab Bar Text", isOn: showTabBarText)
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
                            .foregroundColor(themeManager.accentColor)
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
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
            .accentColor(themeManager.accentColor)
            .id(themeManager.accentColorOption)
            .sheet(isPresented: $showingStorageInfo) {
                StorageInfoView()
                    .environmentObject(themeManager)
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
    @EnvironmentObject var themeManager: ThemeManager
    
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
                        .foregroundColor(themeManager.accentColor)
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

