//
//  SettingsView.swift
//  Claveo
//
//  Dedicated settings tab consolidating all app-wide settings.
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @Environment(\.openURL) private var openURL
    @ObservedObject private var syncEngine = SyncEngine.shared
    @State private var manualFrequencyText = ""
    /// Grows with Dynamic Type so the Hz value is never clipped.
    @ScaledMetric(relativeTo: .body) private var frequencyFieldWidth: CGFloat = 76
    @FocusState private var isFrequencyFieldFocused: Bool
    @State private var practiceMaximum: Int = SettingsManager.shared.settings.maximumPracticeMinutes
    @State private var practiceDefaultTime: Int = SettingsManager.shared.settings.defaultPracticeTime
    @State private var practiceDurationOptions: [Int] = PracticeDuration.sanitizedOptions(
        SettingsManager.shared.settings.practiceDurationOptions,
        maximum: SettingsManager.shared.settings.maximumPracticeMinutes
    )
    @State private var showingResetSettingsAlert = false
    @State private var storageLocationText = iCloudManager.shared.getStorageLocation()
    @State private var storageUsesiCloud = iCloudManager.shared.isAvailable
    @State private var recordingInputs: [RecordingInputChoice] = []
    @State private var selectedRecordingInputID = ""
    @State private var isRecordingInputListActive = false

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
            settingsForm
        }
        .onAppear {
            manualFrequencyText = String(format: "%.1f", settingsManager.settings.a4ReferenceFrequency)
            practiceMaximum = settingsManager.settings.maximumPracticeMinutes
            practiceDefaultTime = settingsManager.settings.defaultPracticeTime
            practiceDurationOptions = PracticeDuration.sanitizedOptions(
                settingsManager.settings.practiceDurationOptions,
                maximum: settingsManager.settings.maximumPracticeMinutes
            )
            refreshStorageDisplay()
            isRecordingInputListActive = true
            Task { await refreshRecordingInputs() }
        }
        .onDisappear {
            isRecordingInputListActive = false
            AudioRecorder.shared.endInputPreviewIfIdle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .claveoStorageLocationDidChange)) { _ in
            refreshStorageDisplay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .claveoSelectedTabChanged)) { notification in
            guard let index = notification.userInfo?["index"] as? Int else { return }
            let showingSettings = index == 6
            isRecordingInputListActive = showingSettings
            if showingSettings {
                Task { await refreshRecordingInputs() }
            } else {
                AudioRecorder.shared.endInputPreviewIfIdle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
            guard isRecordingInputListActive else { return }
            Task { await refreshRecordingInputs() }
        }
        .onChange(of: practiceMaximum) { _, _ in commitPracticeDurations() }
        .onChange(of: practiceDefaultTime) { _, _ in commitPracticeDurations() }
        .onChange(of: practiceDurationOptions) { _, _ in commitPracticeDurations() }
        .alert("Reset Settings?", isPresented: $showingResetSettingsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("This restores app preferences to their defaults. Your recordings, pieces, and practice history will not be deleted.")
        }
    }

    private var settingsForm: some View {
        Form {
            appearanceSection
            tabsSection
            metronomeSection
            tunerSection
            practiceSection
            recordingSection
            storageSection
            resetSection
            aboutSection
            contactSection
        }
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .moreTabBackButton(for: 6)
    }

    private func commitPracticeDurations() {
        let maximum = PracticeDuration.clampMaximum(practiceMaximum)
        let defaultTime = PracticeDuration.clamp(practiceDefaultTime, maximum: maximum)
        let options = PracticeDuration.sanitizedOptions(practiceDurationOptions, maximum: maximum)
        if practiceMaximum != maximum { practiceMaximum = maximum }
        if practiceDefaultTime != defaultTime { practiceDefaultTime = defaultTime }
        if practiceDurationOptions != options { practiceDurationOptions = options }
        let settings = settingsManager.settings
        guard settings.maximumPracticeMinutes != maximum
                || settings.defaultPracticeTime != defaultTime
                || settings.practiceDurationOptions != options else { return }
        settingsManager.updatePracticeDurations(
            maximum: maximum,
            defaultMinutes: defaultTime,
            options: options
        )
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

        }
    }

    // MARK: - Tabs

    var tabsSection: some View {
        Section("Tabs") {
            if UIDevice.current.userInterfaceIdiom == .phone {
                Toggle("Show Tab Bar Labels", isOn: Binding(
                    get: { settingsManager.settings.showTabBarText },
                    set: { settingsManager.update(\.showTabBarText, value: $0) }
                ))
            }

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
                        .frame(width: frequencyFieldWidth)
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
            PracticeDurationControls(
                title: String(localized: "Maximum Duration"),
                minutes: $practiceMaximum,
                maximum: PracticeDuration.absoluteMaximum
            )
            .padding(.vertical, 4)

            PracticeDurationControls(
                title: String(localized: "Default Duration"),
                minutes: $practiceDefaultTime,
                maximum: practiceMaximum
            )
            .padding(.vertical, 4)

            QuickDurationOptionsEditor(options: $practiceDurationOptions, maximum: practiceMaximum)
                .padding(.vertical, 4)
        }
    }

    private var stereoCaptureAvailable: Bool {
        recordingInputs.contains(where: \.supportsStereo)
    }

    // MARK: - Recording

    var recordingSection: some View {
        let quality = settingsManager.settings.recordingQuality
        let micMode = settingsManager.settings.recordingMicMode
        let size = quality.approxMegabytesPerMinute(channelCount: micMode.channelCount)
        return Section {
            Picker("Quality", selection: Binding(
                get: { settingsManager.settings.recordingQuality },
                set: { settingsManager.update(\.recordingQuality, value: $0) }
            )) {
                ForEach(RecordingQuality.allCases) { option in
                    Text(option.localizedName).tag(option)
                }
            }

            if stereoCaptureAvailable {
                Picker("Microphone", selection: Binding(
                    get: { settingsManager.settings.recordingMicMode },
                    set: { settingsManager.update(\.recordingMicMode, value: $0) }
                )) {
                    ForEach(RecordingMicMode.allCases) { option in
                        Text(option.localizedName).tag(option)
                    }
                }
            }

            Toggle("Bluetooth Headset Microphone", isOn: Binding(
                get: { settingsManager.settings.allowBluetoothHeadsetMic },
                set: { enabled in
                    settingsManager.update(\.allowBluetoothHeadsetMic, value: enabled)
                    Task { await refreshRecordingInputs() }
                }
            ))

            if recordingInputs.isEmpty {
                LabeledContent("Input") {
                    Text("No input detected")
                        .foregroundStyle(.secondary)
                }
            } else {
                Picker("Input", selection: Binding(
                    get: { selectedRecordingInputID },
                    set: { newValue in
                        guard newValue != selectedRecordingInputID else { return }
                        selectedRecordingInputID = newValue
                        guard let choice = recordingInputs.first(where: { $0.id == newValue }) else { return }
                        RecordingInputPreferenceStore.save(
                            RecordingInputPreference(portUID: choice.portUID, dataSourceID: choice.dataSourceID)
                        )
                    }
                )) {
                    ForEach(recordingInputs) { choice in
                        Text(choice.name).tag(choice.id)
                    }
                }
            }
        } header: {
            Text("Recording")
        } footer: {
            Text("\(quality.detail) About \(size.formatted(.number.precision(.fractionLength(1)))) MB per minute. \(micMode.detail) Lossless and Uncompressed keep the full range; use them for auditions and excerpts. Choose a connected USB audio interface under Input. A Bluetooth headset microphone uses the call path and lowers quality.")
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

            LabeledContent("Sync") {
                Text(syncEngine.status.title)
                    .foregroundStyle(.secondary)
            }

            if let lastSyncedAt = syncEngine.lastSyncedAt {
                LabeledContent("Last Synced") {
                    Text(lastSyncedAt, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }

            if case .error = syncEngine.status {
                Button("Retry Sync") {
                    syncEngine.retry()
                }
            }

            LabeledContent("Files") {
                Text(iCloudManager.shared.filesAppLocationLabel())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
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
        } header: {
            Text("Storage")
        } footer: {
            Text("iCloud Drive is the default when available. Files sync to the Apple ID signed in on this device, in the Files app under iCloud Drive → Claveo. Turn it off to keep recordings and app data on this device only. Changing this affects where new files are saved; existing files stay where they were created.")
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
        storageUsesiCloud = !settingsManager.settings.storeFilesOnDeviceOnly && iCloudManager.shared.isAvailable
    }

    private func refreshRecordingInputs(forceResolve: Bool = false) async {
        guard isRecordingInputListActive else { return }
        let choices = await AudioRecorder.shared.loadRecordingInputChoices()
        guard isRecordingInputListActive else {
            AudioRecorder.shared.endInputPreviewIfIdle()
            return
        }
        recordingInputs = choices
        if forceResolve || !choices.contains(where: { $0.id == selectedRecordingInputID }) {
            selectedRecordingInputID = RecordingInputSelection.resolved(
                available: choices,
                saved: RecordingInputPreferenceStore.load()
            )?.id ?? ""
        }
    }

    private func resetSettings() {
        settingsManager.resetSettings()
        manualFrequencyText = String(format: "%.1f", settingsManager.settings.a4ReferenceFrequency)
        practiceMaximum = settingsManager.settings.maximumPracticeMinutes
        practiceDefaultTime = settingsManager.settings.defaultPracticeTime
        practiceDurationOptions = settingsManager.settings.practiceDurationOptions
        Task {
            await iCloudManager.shared.warmUpIfNeeded()
            await MainActor.run {
                refreshStorageDisplay()
            }
            await refreshRecordingInputs(forceResolve: true)
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

            if let keysCreditURL = URL(string: "https://freesound.org/s/85688/") {
                Link(destination: keysCreditURL) {
                    LabeledContent("Keys click") {
                        Text("tmkappelt, Freesound")
                            .foregroundStyle(.secondary)
                    }
                }
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
        .environmentObject(SettingsManager.shared)
}
