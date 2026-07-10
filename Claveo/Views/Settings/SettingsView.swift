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
    @Environment(\.openURL) private var openURL
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var manualFrequencyText = ""
    @FocusState private var isFrequencyFieldFocused: Bool
    @State private var practiceDefaultTime: Int = SettingsManager.shared.settings.defaultPracticeTime
    @State private var practiceDurationOptions: [Int] = {
        let opts = SettingsManager.shared.settings.practiceDurationOptions.filter { $0 >= 5 && $0 <= 480 }.sorted()
        return opts.isEmpty ? [15, 30, 45, 60] : opts
    }()
    @State private var showingResetSettingsAlert = false
    @State private var storageLocationText = iCloudManager.shared.getStorageLocation()
    @State private var storagePathText = iCloudManager.shared.getStoragePath()
    @State private var storageUsesiCloud = iCloudManager.shared.isAvailable

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
                resetSection
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
            refreshStorageDisplay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .claveoStorageLocationDidChange)) { _ in
            refreshStorageDisplay()
        }
        .onChange(of: practiceDefaultTime) { _, newValue in
            settingsManager.update(\.defaultPracticeTime, value: newValue)
        }
        .onChange(of: practiceDurationOptions) { _, newValue in
            let cleaned = newValue.filter { $0 >= 5 && $0 <= 480 }.sorted()
            settingsManager.update(\.practiceDurationOptions, value: cleaned.isEmpty ? [15, 30, 45, 60] : cleaned)
        }
        .alert("Reset Settings?", isPresented: $showingResetSettingsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("This restores app preferences to their defaults. Your recordings, pieces, and practice history will not be deleted.")
        }
    }

    // MARK: - Appearance

    var appearanceSection: some View {
        Section("Appearance") {
            Picker("Color Scheme", selection: $themeManager.colorSchemeOption) {
                ForEach(ColorSchemeOption.allCases) { option in
                    Text(option.localizedName).tag(option)
                }
            }

            Picker("Accent Color", selection: $themeManager.accentColorOption) {
                ForEach(AccentColorOption.allCases) { option in
                    HStack {
                        Circle()
                            .fill(option.color)
                            .frame(width: 20, height: 20)
                        Text(option.localizedName)
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
        MetronomeSettingsSection()
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
                        .frame(width: 76)
                        .textFieldStyle(.claveoCompact)
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
        Section {
            Toggle("Use iCloud Drive", isOn: Binding(
                get: { !settingsManager.settings.storeFilesOnDeviceOnly },
                set: { useiCloud in
                    settingsManager.update(\.storeFilesOnDeviceOnly, value: !useiCloud)
                    Task {
                        await iCloudManager.shared.warmUpIfNeeded()
                        await MainActor.run {
                            refreshStorageDisplay()
                        }
                        await AudioRecorder.shared.reloadRecordingsFromDisk(force: true)
                        await PracticeService.shared.refreshFromiCloud()
                    }
                }
            ))

            HStack {
                Text("Storage Location")
                Spacer()
                Text(storageLocationText)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            if settingsManager.settings.storeFilesOnDeviceOnly {
                Label("Files stay on this device", systemImage: "iphone")
                    .foregroundColor(.themeSecondaryLabel)
            } else if storageUsesiCloud {
                Label("iCloud Drive Enabled", systemImage: "icloud.fill")
                    .foregroundColor(themeManager.accentColor)
            } else {
                Label("Using Local Storage", systemImage: "folder.fill")
                    .foregroundColor(.themeSecondaryLabel)
            }

            Text(storagePathText)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        } header: {
            Text("Storage")
        } footer: {
            Text("iCloud Drive is the default when available. Turn it off to keep recordings and app data on this iPhone only without syncing. Changing this affects where new files are saved; existing files stay where they were created.")
        }
    }

    // MARK: - Reset

    var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showingResetSettingsAlert = true
            } label: {
                Label {
                    Text("Reset Settings")
                } icon: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.red)
                }
                .foregroundStyle(.red)
            }
        } footer: {
            Text("Restores app preferences only. Recordings and saved music data stay untouched.")
        }
    }

    private func refreshStorageDisplay() {
        storageLocationText = iCloudManager.shared.getStorageLocation()
        storagePathText = iCloudManager.shared.getStoragePath()
        storageUsesiCloud = !settingsManager.settings.storeFilesOnDeviceOnly && iCloudManager.shared.isAvailable
    }

    private func resetSettings() {
        settingsManager.resetSettings()
        manualFrequencyText = String(format: "%.1f", settingsManager.settings.a4ReferenceFrequency)
        practiceDefaultTime = settingsManager.settings.defaultPracticeTime
        practiceDurationOptions = settingsManager.settings.practiceDurationOptions
        Task {
            await iCloudManager.shared.warmUpIfNeeded()
            await MainActor.run {
                refreshStorageDisplay()
            }
        }
    }

    // MARK: - About

    private static let appStoreReviewURL = URL(string: "https://apps.apple.com/app/id6755795790?action=write-review")!

    var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundColor(.secondary)
            }

            Button {
                openAppStoreReview()
            } label: {
                Label("Leave a Review", systemImage: "star")
            }
        }
    }

    private func openAppStoreReview() {
        openURL(Self.appStoreReviewURL)
    }

    /// Marketing site (contact, privacy, support). Update if the canonical URL changes.
    private static let claveoWebsiteURL = URL(string: "https://claveo-app.vercel.app/")!

    var contactSection: some View {
        Section {
            Link(destination: Self.claveoWebsiteURL) {
                Label("Website & contact", systemImage: "safari")
            }
        } footer: {
            Text("Visit https://claveo-app.vercel.app/ for help, feedback, and product updates.")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager.shared)
}
