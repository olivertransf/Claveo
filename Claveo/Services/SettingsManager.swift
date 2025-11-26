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
            self?.syncFromiCloud()
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
        settings.defaultMetronomeTempo = defaults.integer(forKey: "defaultMetronomeTempo") == 0 ? 120 : defaults.integer(forKey: "defaultMetronomeTempo")
        settings.metronomeSound = defaults.string(forKey: "metronomeSound") ?? MetronomeSound.click.rawValue
        settings.metronomeHapticEnabled = defaults.object(forKey: "metronomeHapticEnabled") as? Bool ?? true
        settings.metronomeAutoStopOnTabSwitch = defaults.bool(forKey: "metronomeAutoStopOnTabSwitch")
        
        // Favorite tempos
        if let data = defaults.data(forKey: "favoriteTempos"),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            settings.favoriteTempos = decoded
        }
        
        // Dictionary
        settings.showAdvancedDictionaryItems = defaults.object(forKey: "showAdvancedDictionaryItems") as? Bool ?? true
        
        // Theme
        settings.accentColor = defaults.string(forKey: "accentColor") ?? AccentColorOption.blue.rawValue
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
        defaults.set(settings.defaultMetronomeTempo, forKey: "defaultMetronomeTempo")
        defaults.set(settings.metronomeSound, forKey: "metronomeSound")
        defaults.set(settings.metronomeHapticEnabled, forKey: "metronomeHapticEnabled")
        defaults.set(settings.metronomeAutoStopOnTabSwitch, forKey: "metronomeAutoStopOnTabSwitch")
        
        // Favorite tempos
        if let encoded = try? JSONEncoder().encode(settings.favoriteTempos) {
            defaults.set(encoded, forKey: "favoriteTempos")
        }
        
        // Dictionary
        defaults.set(settings.showAdvancedDictionaryItems, forKey: "showAdvancedDictionaryItems")
        
        // Theme
        defaults.set(settings.accentColor, forKey: "accentColor")
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
    
    var accentColorOption: AccentColorOption {
        AccentColorOption(rawValue: settings.accentColor) ?? .blue
    }
    
    func setMetronomeSound(_ sound: MetronomeSound) {
        settings.metronomeSound = sound.rawValue
        saveSettings()
    }
    
    func setAccentColor(_ option: AccentColorOption) {
        settings.accentColor = option.rawValue
        saveSettings()
    }
}

