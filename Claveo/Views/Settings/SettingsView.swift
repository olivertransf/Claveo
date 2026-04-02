//
//  SettingsView.swift
//  Claveo
//
//  Dedicated settings tab consolidating all app-wide settings.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var manualFrequencyText = ""
    @FocusState private var isFrequencyFieldFocused: Bool
    @State private var practiceDefaultTime: Int = SettingsManager.shared.settings.defaultPracticeTime
    @State private var practiceDurationOptions: [Int] = {
        let opts = SettingsManager.shared.settings.practiceDurationOptions.filter { $0 >= 5 && $0 <= 480 }.sorted()
        return opts.isEmpty ? [15, 30, 45, 60] : opts
    }()

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
            Form {
                appearanceSection
                tabsSection
                metronomeSection
                tunerSection
                practiceSection
                storageSection
                aboutSection
                contactSection
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            manualFrequencyText = String(format: "%.1f", settingsManager.settings.a4ReferenceFrequency)
            practiceDefaultTime = settingsManager.settings.defaultPracticeTime
            let opts = settingsManager.settings.practiceDurationOptions.filter { $0 >= 5 && $0 <= 480 }.sorted()
            practiceDurationOptions = opts.isEmpty ? [15, 30, 45, 60] : opts
        }
        .onChange(of: practiceDefaultTime) { _, newValue in
            settingsManager.update(\.defaultPracticeTime, value: newValue)
        }
        .onChange(of: practiceDurationOptions) { _, newValue in
            let cleaned = newValue.filter { $0 >= 5 && $0 <= 480 }.sorted()
            settingsManager.update(\.practiceDurationOptions, value: cleaned.isEmpty ? [15, 30, 45, 60] : cleaned)
        }
    }

    // MARK: - Appearance

    var appearanceSection: some View {
        Section("Appearance") {
            Picker("Color Scheme", selection: $themeManager.colorSchemeOption) {
                ForEach(ColorSchemeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
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

            if UIDevice.current.userInterfaceIdiom == .phone {
                Toggle("Show Tab Bar Labels", isOn: Binding(
                    get: { settingsManager.settings.showTabBarText },
                    set: { settingsManager.update(\.showTabBarText, value: $0) }
                ))
            }
        }
    }

    // MARK: - Tabs

    var tabsSection: some View {
        Section("Tabs") {
            NavigationLink {
                TabBarOrderSettingsView()
            } label: {
                Label("Customize tab order", systemImage: "arrow.up.arrow.down.square")
            }
        }
    }

    // MARK: - Metronome

    var metronomeSection: some View {
        Section("Metronome") {
            Picker("Emphasized Sound", selection: Binding(
                get: { settingsManager.metronomeEmphasizedSoundEnum },
                set: { settingsManager.setMetronomeEmphasizedSound($0) }
            )) {
                ForEach(MetronomeSound.allCases, id: \.self) { sound in
                    Text(sound.rawValue).tag(sound)
                }
            }

            Picker("Non-Emphasized Sound", selection: Binding(
                get: { settingsManager.metronomeNonEmphasizedSoundEnum },
                set: { settingsManager.setMetronomeNonEmphasizedSound($0) }
            )) {
                ForEach(MetronomeSound.allCases, id: \.self) { sound in
                    Text(sound.rawValue).tag(sound)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                    Spacer()
                    Text("\(Int(settingsManager.settings.metronomeVolume * 100))%")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                Slider(
                    value: Binding(
                        get: { settingsManager.settings.metronomeVolume },
                        set: { settingsManager.update(\.metronomeVolume, value: $0) }
                    ),
                    in: 0.0...1.0,
                    step: 0.05
                )
                HStack {
                    Text("Quiet").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("Loud").font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)

            Toggle("Haptic Feedback", isOn: Binding(
                get: { settingsManager.settings.metronomeHapticEnabled },
                set: { settingsManager.update(\.metronomeHapticEnabled, value: $0) }
            ))

            Toggle("Auto-stop when switching tabs", isOn: Binding(
                get: { settingsManager.settings.metronomeAutoStopOnTabSwitch },
                set: { settingsManager.update(\.metronomeAutoStopOnTabSwitch, value: $0) }
            ))

            Toggle("Stop tone when leaving Metronome", isOn: Binding(
                get: { settingsManager.settings.stopToneWhenLeavingMetronomeTab },
                set: { settingsManager.update(\.stopToneWhenLeavingMetronomeTab, value: $0) }
            ))
        }
    }

    // MARK: - Tuner

    var tunerSection: some View {
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
                                manualFrequencyText = String(format: "%.1f", settingsManager.settings.a4ReferenceFrequency)
                            }
                            isFrequencyFieldFocused = false
                        }
                        .onChange(of: settingsManager.settings.a4ReferenceFrequency) { _, newValue in
                            if !isFrequencyFieldFocused {
                                manualFrequencyText = String(format: "%.1f", newValue)
                            }
                        }
                }
            }
            .padding(.vertical, 4)

            Picker("Preset Frequencies", selection: Binding(
                get: { selectedPreset },
                set: { preset in
                    if let frequency = preset.frequency {
                        settingsManager.update(\.a4ReferenceFrequency, value: frequency)
                    }
                }
            )) {
                ForEach(FrequencyPreset.allCases, id: \.self) { preset in
                    if preset == .custom {
                        Text(preset.displayName).tag(preset)
                    } else {
                        Text(preset.fullName).tag(preset)
                    }
                }
            }

            Toggle("Show Frequency Display", isOn: Binding(
                get: { settingsManager.settings.showFrequencyDisplay },
                set: { settingsManager.update(\.showFrequencyDisplay, value: $0) }
            ))
        }
    }

    // MARK: - Practice

    var practiceSection: some View {
        Section("Practice") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Default Duration")
                    Spacer()
                    Text("\(practiceDefaultTime) min")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                Slider(
                    value: Binding(
                        get: { Double(practiceDefaultTime) },
                        set: { practiceDefaultTime = Int($0) }
                    ),
                    in: 5...180,
                    step: 5
                )
                HStack {
                    ForEach([15, 30, 45, 60, 90], id: \.self) { mins in
                        Button {
                            practiceDefaultTime = mins
                        } label: {
                            Text("\(mins)")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(practiceDefaultTime == mins ? .white : themeManager.accentColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(practiceDefaultTime == mins ? themeManager.accentColor : themeManager.accentColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Duration Options")
                    .font(.subheadline)
                Text("Tap active options to remove, tap grayed ones to add")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    ForEach(practiceDurationOptions, id: \.self) { option in
                        Button {
                            practiceDurationOptions.removeAll { $0 == option }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(option)")
                                    .font(.subheadline)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .foregroundColor(themeManager.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(themeManager.accentColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if practiceDurationOptions.count < 6 {
                    HStack {
                        ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { mins in
                            if !practiceDurationOptions.contains(mins) {
                                Button {
                                    if !practiceDurationOptions.contains(mins) {
                                        practiceDurationOptions.append(mins)
                                        practiceDurationOptions.sort()
                                    }
                                } label: {
                                    Text("+\(mins)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Storage

    var storageSection: some View {
        Section("Storage") {
            HStack {
                Text("Storage Location")
                Spacer()
                Text(iCloudManager.shared.getStorageLocation())
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            if iCloudManager.shared.isAvailable {
                Label("iCloud Drive Enabled", systemImage: "icloud.fill")
                    .foregroundColor(themeManager.accentColor)
            } else {
                Label("Using Local Storage", systemImage: "folder.fill")
                    .foregroundColor(.themeSecondaryLabel)
            }

            Text(iCloudManager.shared.getStoragePath())
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - About

    var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundColor(.secondary)
            }
        }
    }

    /// Marketing site (contact, privacy, support). Update if the canonical URL changes.
    private static let claveoWebsiteURL = URL(string: "https://claveo.app")!

    var contactSection: some View {
        Section {
            Link(destination: Self.claveoWebsiteURL) {
                Label("Website & contact", systemImage: "safari")
            }
        } footer: {
            Text("Visit claveo.app for help, feedback, and product updates.")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager.shared)
}
