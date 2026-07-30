//
//  SettingsManager.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation
import Combine
import UIKit

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var settings = AppSettings()
    
    private let settingsFileName = "settings.json"
    private let settingsLastModifiedKey = "settingsLastModified"
    private var settingsWriteTask: Task<Void, Never>?
    /// Bumped on every local save so in-flight iCloud syncs can abort.
    private var settingsGeneration = 0
    private var settingsURL: URL {
        iCloudManager.shared.getDocumentsURL().appendingPathComponent(settingsFileName)
    }

    private init() {
        loadSettings()
        
        // Listen for app becoming active to sync settings
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncFromiCloud()
            }
        }
    }
    
    // MARK: - Load Settings
    
    private func loadSettings() {
        loadFromUserDefaults()
        let localSettings = settings
        let localFavoritesBeforeSync = localSettings.favoriteTempos
        let localModified = UserDefaults.standard.object(forKey: settingsLastModifiedKey) as? Date
            ?? .distantPast

        if let remote = loadFromiCloud() {
            settings = Self.resolve(
                local: localSettings,
                localModified: localModified,
                remote: remote.settings,
                remoteModified: remote.lastModified
            )
            if remote.lastModified >= localModified {
                UserDefaults.standard.set(remote.lastModified, forKey: settingsLastModifiedKey)
            }
            saveToUserDefaults()
        }
        recoverFavoriteTemposIfNeeded(preserving: localFavoritesBeforeSync)
        // Device-local tab selection always wins over any cloud value.
        applyDeviceLocalTabSelection()
        migrateTabIndicesForExercisesTabIfNeeded()
        migrateStorageToiCloudDefaultIfNeeded()
        iCloudManager.shared.setStoreFilesOnDeviceOnly(settings.storeFilesOnDeviceOnly)
    }

    /// Pulls favorite tempos from every known Documents root so a thin cloud snapshot
    /// cannot permanently erase a richer local/other-root list.
    private func recoverFavoriteTemposIfNeeded(preserving localFavorites: [Int]) {
        var recovered = Set(settings.favoriteTempos)
        recovered.formUnion(localFavorites)

        for root in iCloudManager.shared.knownStorageRoots().values {
            let url = root.appendingPathComponent(settingsFileName)
            let data = (try? iCloudManager.shared.readFile(from: url))
                ?? (try? Data(contentsOf: url))
            guard let data,
                  let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
                continue
            }
            recovered.formUnion(decoded.favoriteTempos)
        }

        let merged = recovered.sorted()
        guard merged != settings.favoriteTempos else { return }
        settings.favoriteTempos = merged
        saveToUserDefaults()
    }

    private func applyDeviceLocalTabSelection() {
        let tab = UserDefaults.standard.integer(forKey: "lastSelectedTab")
        settings.lastSelectedTab = (0...7).contains(tab) ? tab : 0
    }

    /// iCloud Drive is the default; ensure installs without an explicit choice use it.
    private func migrateStorageToiCloudDefaultIfNeeded() {
        let migrationKey = "claveoStorageiCloudDefaultMigrated_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        if UserDefaults.standard.object(forKey: "storeFilesOnDeviceOnly") == nil {
            settings.storeFilesOnDeviceOnly = false
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// Remap legacy tab indices for pre-Exercises payloads and one-time local upgrades.
    private func migrateTabIndicesForExercisesTabIfNeeded() {
        let key = "claveoTabIndicesExercisesMigration_v1"

        if settings.tabSemanticsVersion < AppSettings.currentTabSemanticsVersion {
            let t = settings.lastSelectedTab
            if (4...6).contains(t) {
                settings.lastSelectedTab = t + 1
                UserDefaults.standard.set(settings.lastSelectedTab, forKey: "lastSelectedTab")
            }
            settings.tabSemanticsVersion = AppSettings.currentTabSemanticsVersion
            UserDefaults.standard.set(true, forKey: key)
            // Persist version bump without treating this as a full settings "user edit"
            // that should blindly overwrite cloud lists — saveSettings still uploads,
            // but resolve now unions favoriteTempos.
            saveSettings()
            return
        }

        guard !UserDefaults.standard.bool(forKey: key) else { return }
        // Local upgrade before `tabSemanticsVersion` existed — remap once from UserDefaults.
        let t = UserDefaults.standard.integer(forKey: "lastSelectedTab")
        if (4...6).contains(t) {
            let remapped = t + 1
            settings.lastSelectedTab = remapped
            UserDefaults.standard.set(remapped, forKey: "lastSelectedTab")
        }
        UserDefaults.standard.set(true, forKey: key)
    }
    
    private func loadFromiCloud() -> (settings: AppSettings, lastModified: Date)? {
        do {
            let data = try iCloudManager.shared.readFile(from: settingsURL)
            if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
                let attributes = try? FileManager.default.attributesOfItem(atPath: settingsURL.path)
                let modified = attributes?[.modificationDate] as? Date ?? .distantPast
                return (decoded, modified)
            }
        } catch {
            // File doesn't exist or can't be read - that's okay, use UserDefaults
        }
        return nil
    }
    
    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        // Tuner
        settings.a4ReferenceFrequency = defaults.double(forKey: "a4ReferenceFrequency") == 0 ? 440.0 : defaults.double(forKey: "a4ReferenceFrequency")
        settings.showFrequencyDisplay = defaults.object(forKey: "showFrequencyDisplay") as? Bool ?? true
        
        // Metronome
        settings.lastMetronomeTempo = defaults.integer(forKey: "lastMetronomeTempo") == 0 ? 120 : defaults.integer(forKey: "lastMetronomeTempo")
        settings.metronomeSound = defaults.string(forKey: "metronomeSound") ?? MetronomeSound.click.rawValue
        settings.metronomeEmphasizedSound = defaults.string(forKey: "metronomeEmphasizedSound") ?? MetronomeSound.tick.rawValue
        settings.metronomeNonEmphasizedSound = defaults.string(forKey: "metronomeNonEmphasizedSound") ?? MetronomeSound.click.rawValue
        settings.metronomeVolume = defaults.object(forKey: "metronomeVolume") as? Double ?? 1.0
        settings.metronomeHapticEnabled = defaults.object(forKey: "metronomeHapticEnabled") as? Bool ?? true
        settings.metronomeAutoStopOnTabSwitch = defaults.bool(forKey: "metronomeAutoStopOnTabSwitch")
        settings.stopToneWhenLeavingMetronomeTab = defaults.object(forKey: "stopToneWhenLeavingMetronomeTab") as? Bool ?? false
        
        // Custom time signature
        let customTop = defaults.integer(forKey: "customTimeSignatureTop")
        let customBottom = defaults.integer(forKey: "customTimeSignatureBottom")
        if customTop > 0 && customBottom > 0 {
            settings.customTimeSignatureTop = customTop
            settings.customTimeSignatureBottom = customBottom
        } else {
            settings.customTimeSignatureTop = nil
            settings.customTimeSignatureBottom = nil
        }
        
        // Favorite tempos
        if let data = defaults.data(forKey: "favoriteTempos"),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            settings.favoriteTempos = decoded
        }
        
        // Practice
        settings.defaultPracticeTime = defaults.integer(forKey: "defaultPracticeTime") == 0 ? 30 : defaults.integer(forKey: "defaultPracticeTime")
        if let data = defaults.data(forKey: "practiceDurationOptions"),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            settings.practiceDurationOptions = decoded
        }
        settings.practiceReminderEnabled = defaults.bool(forKey: "practiceReminderEnabled")
        if defaults.object(forKey: "practiceReminderHour") != nil {
            settings.practiceReminderHour = defaults.integer(forKey: "practiceReminderHour")
        }
        if defaults.object(forKey: "practiceReminderMinute") != nil {
            settings.practiceReminderMinute = defaults.integer(forKey: "practiceReminderMinute")
        }
        
        // Theme
        settings.accentColor = defaults.string(forKey: "accentColor") ?? AccentColorOption.blue.rawValue
        settings.colorScheme = defaults.string(forKey: "colorScheme") ?? ColorSchemeOption.system.rawValue
        // Default to showing tab bar text on iPad, hiding on iPhone
        if let savedValue = defaults.object(forKey: "showTabBarText") as? Bool {
            settings.showTabBarText = savedValue
        } else {
            // First launch: default based on device type
            settings.showTabBarText = UIDevice.current.userInterfaceIdiom == .pad
        }

        settings.storeFilesOnDeviceOnly = defaults.object(forKey: "storeFilesOnDeviceOnly") as? Bool ?? false

        // Navigation
        settings.lastSelectedTab = defaults.integer(forKey: "lastSelectedTab")
        if let data = defaults.data(forKey: "tabBarCustomizationOrder"),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            settings.tabBarCustomizationOrder = AppSettings.normalizedTabBarOrder(decoded)
        }

        // Metronome pattern
        settings.metronomeTimeSignature = defaults.string(forKey: "metronomeTimeSignature") ?? TimeSignature.fourFour.rawValue
        if let data = defaults.data(forKey: "metronomeBeatPattern"),
           let decoded = try? JSONDecoder().decode([Bool].self, from: data) {
            settings.metronomeBeatPattern = decoded
        }

        if let data = defaults.data(forKey: "noteIdentificationEnabledClefRawValues"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            settings.noteIdentificationEnabledClefRawValues = decoded
        }

        if let data = defaults.data(forKey: "keySignatureIdentificationEnabledModeRawValues"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            settings.keySignatureIdentificationEnabledModeRawValues = decoded
        }
    }
    
    // MARK: - Save Settings
    
    func saveSettings() {
        settingsGeneration &+= 1
        settings.tabSemanticsVersion = AppSettings.currentTabSemanticsVersion
        let modified = Date()
        UserDefaults.standard.set(modified, forKey: settingsLastModifiedKey)
        // UserDefaults is memory-mapped — fast, keep on main thread.
        saveToUserDefaults()
        iCloudManager.shared.setStoreFilesOnDeviceOnly(settings.storeFilesOnDeviceOnly)
        // iCloud uses NSFileCoordinator (blocking I/O) — always run off the main thread.
        // Omit device-local tab selection from the cloud payload.
        var snapshot = settings
        snapshot.lastSelectedTab = 0
        let url = settingsURL
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        let previousWrite = settingsWriteTask
        settingsWriteTask = Task.detached(priority: .utility) {
            await previousWrite?.value
            do {
                try iCloudManager.shared.writeFile(data: encoded, to: url)
            } catch {
                try? encoded.write(to: url, options: [.atomic])
            }
        }
    }
    
    private func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        
        // Tuner
        defaults.set(settings.a4ReferenceFrequency, forKey: "a4ReferenceFrequency")
        defaults.set(settings.showFrequencyDisplay, forKey: "showFrequencyDisplay")
        
        // Metronome
        defaults.set(settings.lastMetronomeTempo, forKey: "lastMetronomeTempo")
        defaults.set(settings.metronomeSound, forKey: "metronomeSound")
        defaults.set(settings.metronomeEmphasizedSound, forKey: "metronomeEmphasizedSound")
        defaults.set(settings.metronomeNonEmphasizedSound, forKey: "metronomeNonEmphasizedSound")
        defaults.set(settings.metronomeVolume, forKey: "metronomeVolume")
        defaults.set(settings.metronomeHapticEnabled, forKey: "metronomeHapticEnabled")
        defaults.set(settings.metronomeAutoStopOnTabSwitch, forKey: "metronomeAutoStopOnTabSwitch")
        defaults.set(settings.stopToneWhenLeavingMetronomeTab, forKey: "stopToneWhenLeavingMetronomeTab")
        
        // Custom time signature
        if let top = settings.customTimeSignatureTop, let bottom = settings.customTimeSignatureBottom {
            defaults.set(top, forKey: "customTimeSignatureTop")
            defaults.set(bottom, forKey: "customTimeSignatureBottom")
        } else {
            defaults.removeObject(forKey: "customTimeSignatureTop")
            defaults.removeObject(forKey: "customTimeSignatureBottom")
        }
        
        // Favorite tempos
        if let encoded = try? JSONEncoder().encode(settings.favoriteTempos) {
            defaults.set(encoded, forKey: "favoriteTempos")
        }
        
        // Practice
        defaults.set(settings.defaultPracticeTime, forKey: "defaultPracticeTime")
        if let encoded = try? JSONEncoder().encode(settings.practiceDurationOptions) {
            defaults.set(encoded, forKey: "practiceDurationOptions")
        }
        defaults.set(settings.practiceReminderEnabled, forKey: "practiceReminderEnabled")
        defaults.set(settings.practiceReminderHour, forKey: "practiceReminderHour")
        defaults.set(settings.practiceReminderMinute, forKey: "practiceReminderMinute")
        
        // Theme
        defaults.set(settings.accentColor, forKey: "accentColor")
        defaults.set(settings.colorScheme, forKey: "colorScheme")
        defaults.set(settings.showTabBarText, forKey: "showTabBarText")
        defaults.set(settings.storeFilesOnDeviceOnly, forKey: "storeFilesOnDeviceOnly")

        // Note: lastSelectedTab is written directly by ContentView to avoid @Published re-renders.

        if let encoded = try? JSONEncoder().encode(
            AppSettings.normalizedTabBarOrder(settings.tabBarCustomizationOrder)
        ) {
            defaults.set(encoded, forKey: "tabBarCustomizationOrder")
        }

        // Metronome pattern
        defaults.set(settings.metronomeTimeSignature, forKey: "metronomeTimeSignature")
        if let encoded = try? JSONEncoder().encode(settings.metronomeBeatPattern) {
            defaults.set(encoded, forKey: "metronomeBeatPattern")
        }

        if let encoded = try? JSONEncoder().encode(settings.noteIdentificationEnabledClefRawValues) {
            defaults.set(encoded, forKey: "noteIdentificationEnabledClefRawValues")
        }

        if let encoded = try? JSONEncoder().encode(settings.keySignatureIdentificationEnabledModeRawValues) {
            defaults.set(encoded, forKey: "keySignatureIdentificationEnabledModeRawValues")
        }
    }
    
    // MARK: - Sync
    
    func syncFromiCloud() {
        let url = settingsURL
        let generationAtStart = settingsGeneration
        let localModified = UserDefaults.standard.object(forKey: settingsLastModifiedKey) as? Date
            ?? .distantPast
        Task.detached(priority: .utility) {
            let data = try? iCloudManager.shared.readFile(from: url)
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let remoteModified = attributes?[.modificationDate] as? Date ?? .distantPast
            await MainActor.run { [weak self] in
                guard let self else { return }
                // Abort if the user saved settings while the cloud read was in flight.
                guard self.settingsGeneration == generationAtStart else { return }
                let currentLocalModified = UserDefaults.standard.object(forKey: self.settingsLastModifiedKey) as? Date
                    ?? .distantPast
                guard currentLocalModified == localModified else { return }

                if let data,
                   let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
                    let localFavorites = self.settings.favoriteTempos
                    var resolved = Self.resolve(
                        local: self.settings,
                        localModified: localModified,
                        remote: decoded,
                        remoteModified: remoteModified
                    )
                    // Preserve device-local tab; migrate legacy cloud payloads only.
                    if resolved.tabSemanticsVersion < AppSettings.currentTabSemanticsVersion {
                        let t = resolved.lastSelectedTab
                        if (4...6).contains(t) {
                            resolved.lastSelectedTab = t + 1
                        }
                        resolved.tabSemanticsVersion = AppSettings.currentTabSemanticsVersion
                    }
                    self.settings = resolved
                    self.recoverFavoriteTemposIfNeeded(preserving: localFavorites)
                    self.applyDeviceLocalTabSelection()
                    UserDefaults.standard.set(
                        max(localModified, remoteModified),
                        forKey: self.settingsLastModifiedKey
                    )
                    self.saveToUserDefaults()
                    if localModified > remoteModified {
                        self.saveSettings()
                    }
                } else {
                    self.saveSettings()
                }
            }
        }
    }

    static func resolve(
        local: AppSettings,
        localModified: Date,
        remote: AppSettings,
        remoteModified: Date
    ) -> AppSettings {
        var winner = localModified > remoteModified ? local : remote
        // Never let a newer-but-empty cloud list erase local favorites (or vice versa).
        winner.favoriteTempos = Array(Set(local.favoriteTempos).union(remote.favoriteTempos)).sorted()
        return winner
    }
    
    // MARK: - Property Updates
    
    func update<T>(_ keyPath: WritableKeyPath<AppSettings, T>, value: T) {
        settings[keyPath: keyPath] = value
        saveSettings()
    }

    /// Applies a value in memory without persisting it. Use while a control is
    /// being dragged, then call `update` once on release to write it out.
    func updateLive<T>(_ keyPath: WritableKeyPath<AppSettings, T>, value: T) {
        settings[keyPath: keyPath] = value
    }

    func resetSettings() {
        PracticeReminderNotificationService.cancel()
        let defaultShowTabBarText = UIDevice.current.userInterfaceIdiom == .pad
        var defaults = AppSettings()
        defaults.showTabBarText = defaultShowTabBarText
        settings = defaults
        removePersistedSettings()
        saveSettings()
    }

    private func removePersistedSettings() {
        let defaults = UserDefaults.standard
        [
            "a4ReferenceFrequency",
            "showFrequencyDisplay",
            "lastMetronomeTempo",
            "metronomeSound",
            "metronomeEmphasizedSound",
            "metronomeNonEmphasizedSound",
            "metronomeVolume",
            "metronomeHapticEnabled",
            "metronomeAutoStopOnTabSwitch",
            "stopToneWhenLeavingMetronomeTab",
            "customTimeSignatureTop",
            "customTimeSignatureBottom",
            "favoriteTempos",
            "defaultPracticeTime",
            "practiceDurationOptions",
            "practiceReminderEnabled",
            "practiceReminderHour",
            "practiceReminderMinute",
            "accentColor",
            "colorScheme",
            "showTabBarText",
            "storeFilesOnDeviceOnly",
            "lastSelectedTab",
            "tabBarCustomizationOrder",
            "metronomeTimeSignature",
            "metronomeBeatPattern",
            "noteIdentificationEnabledClefRawValues",
            "keySignatureIdentificationEnabledModeRawValues"
        ].forEach { defaults.removeObject(forKey: $0) }
        defaults.removeObject(forKey: settingsLastModifiedKey)
    }
    
    // MARK: - Computed Properties for Convenience
    
    var metronomeEmphasizedSoundEnum: MetronomeSound {
        MetronomeSound(rawValue: settings.metronomeEmphasizedSound) ?? .tick
    }

    var metronomeNonEmphasizedSoundEnum: MetronomeSound {
        MetronomeSound(rawValue: settings.metronomeNonEmphasizedSound) ?? .click
    }
    
    var accentColorOption: AccentColorOption {
        AccentColorOption(rawValue: settings.accentColor) ?? .blue
    }
    
    var colorSchemeOption: ColorSchemeOption {
        ColorSchemeOption(rawValue: settings.colorScheme) ?? .system
    }
    
    func setMetronomeEmphasizedSound(_ sound: MetronomeSound) {
        settings.metronomeEmphasizedSound = sound.rawValue
        saveSettings()
    }

    func setMetronomeNonEmphasizedSound(_ sound: MetronomeSound) {
        settings.metronomeNonEmphasizedSound = sound.rawValue
        saveSettings()
    }
    
    func setAccentColor(_ option: AccentColorOption) {
        settings.accentColor = option.rawValue
        saveSettings()
    }
    
    func setColorScheme(_ option: ColorSchemeOption) {
        settings.colorScheme = option.rawValue
        saveSettings()
    }
}

