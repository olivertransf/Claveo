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
    /// Cached URL — `getDocumentsURL()` calls `NSFileCoordinator` internally, so we only compute this once.
    private lazy var settingsURL: URL = {
        iCloudManager.shared.getDocumentsURL().appendingPathComponent(settingsFileName)
    }()

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
        // Try to load from iCloud first
        if let iCloudSettings = loadFromiCloud() {
            settings = iCloudSettings
            // Update local cache
            saveToUserDefaults()
        } else {
            // Fall back to UserDefaults (local cache)
            loadFromUserDefaults()
        }
        migrateTabIndicesForExercisesTabIfNeeded()
    }

    /// One-time remap after adding Exercises at index 4: old 4/5/6 (Dictionary/Settings/Chords) → 5/6/7.
    private func migrateTabIndicesForExercisesTabIfNeeded() {
        let key = "claveoTabIndicesExercisesMigration_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let t = settings.lastSelectedTab
        if (4...6).contains(t) {
            settings.lastSelectedTab = t + 1
            UserDefaults.standard.set(settings.lastSelectedTab, forKey: "lastSelectedTab")
        }
        UserDefaults.standard.set(true, forKey: key)
    }
    
    private func loadFromiCloud() -> AppSettings? {
        do {
            let data = try iCloudManager.shared.readFile(from: settingsURL)
            if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
                return decoded
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
        // UserDefaults is memory-mapped — fast, keep on main thread.
        saveToUserDefaults()
        // iCloud uses NSFileCoordinator (blocking I/O) — always run off the main thread.
        let snapshot = settings
        let url = settingsURL
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        Task.detached(priority: .utility) {
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
        
        // Theme
        defaults.set(settings.accentColor, forKey: "accentColor")
        defaults.set(settings.colorScheme, forKey: "colorScheme")
        defaults.set(settings.showTabBarText, forKey: "showTabBarText")

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
        let currentSettings = settings
        Task.detached(priority: .utility) {
            let data = try? iCloudManager.shared.readFile(from: url)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let data,
                   let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
                    self.settings = decoded
                    self.saveToUserDefaults()
                } else if let encoded = try? JSONEncoder().encode(currentSettings) {
                    try? iCloudManager.shared.writeFile(data: encoded, to: url)
                }
            }
        }
    }
    
    // MARK: - Property Updates
    
    func update<T>(_ keyPath: WritableKeyPath<AppSettings, T>, value: T) {
        settings[keyPath: keyPath] = value
        saveSettings()
    }
    
    // MARK: - Computed Properties for Convenience
    
    var metronomeSoundEnum: MetronomeSound {
        MetronomeSound(rawValue: settings.metronomeSound) ?? .click
    }

    var metronomeEmphasizedSoundEnum: MetronomeSound {
        MetronomeSound(rawValue: settings.metronomeEmphasizedSound) ?? .click
    }

    var metronomeNonEmphasizedSoundEnum: MetronomeSound {
        MetronomeSound(rawValue: settings.metronomeNonEmphasizedSound) ?? .tick
    }
    
    var accentColorOption: AccentColorOption {
        AccentColorOption(rawValue: settings.accentColor) ?? .blue
    }
    
    var colorSchemeOption: ColorSchemeOption {
        ColorSchemeOption(rawValue: settings.colorScheme) ?? .system
    }
    
    func setMetronomeSound(_ sound: MetronomeSound) {
        settings.metronomeSound = sound.rawValue
        saveSettings()
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

