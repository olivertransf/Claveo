//
//  SettingsManager.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import Foundation
import Combine
import UIKit

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var settings = AppSettings()
    
    private let settingsFileName = "settings.json"
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
        // Try to load from iCloud first
        if let iCloudSettings = loadFromiCloud() {
            settings = iCloudSettings
            // Update local cache
            saveToUserDefaults()
        } else {
            // Fall back to UserDefaults (local cache)
            loadFromUserDefaults()
        }
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
    }
    
    // MARK: - Save Settings
    
    func saveSettings() {
        // Save to both iCloud and UserDefaults
        saveToiCloud()
        saveToUserDefaults()
    }
    
    private func saveToiCloud() {
        guard let encoded = try? JSONEncoder().encode(settings) else { return }
        
        do {
            try iCloudManager.shared.writeFile(data: encoded, to: settingsURL)
        } catch {
            #if DEBUG
            print("Failed to save settings to iCloud: \(error.localizedDescription)")
            #endif
            // Fallback to direct write if coordination fails
            try? encoded.write(to: settingsURL, options: [.atomic])
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
    }
    
    // MARK: - Sync
    
    func syncFromiCloud() {
        // When coming back online, sync from iCloud
        // This ensures offline changes are preserved (they're already in UserDefaults)
        // and iCloud changes are merged in
        if let iCloudSettings = loadFromiCloud() {
            // For now, iCloud takes precedence when syncing
            // Offline changes are already saved to UserDefaults and will be synced to iCloud
            settings = iCloudSettings
            saveToUserDefaults()
        } else {
            // If iCloud file doesn't exist, ensure local changes are synced to iCloud
            // This handles the case where user made changes offline
            saveToiCloud()
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

