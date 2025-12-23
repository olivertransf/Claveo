//
//  PracticeService.swift
//  Claveo
//
//  Created by Oliver Tran on 12/22/25.
//

import Foundation
import Combine
import UIKit

@MainActor
class PracticeService: ObservableObject {
    static let shared = PracticeService()

    @Published var practiceEntries: [PracticeEntry] = [] {
        didSet {
            // Debounce saves to prevent too frequent iCloud writes
            saveTask?.cancel()
            saveTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                if !Task.isCancelled {
                    saveEntries()
                }
            }
        }
    }

    private let entriesKey = "practiceEntries"
    private let entriesFileName = "practiceEntries.json"
    private var entriesURL: URL {
        iCloudManager.shared.getDocumentsURL().appendingPathComponent(entriesFileName)
    }
    private var saveTask: Task<Void, Never>?
    private var isSyncing = false

    init() {
        loadEntries()
        
        // Listen for app becoming active to sync entries
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncFromiCloud()
            }
        }
        
        // Also listen for when app becomes active (not just foreground)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncFromiCloud()
            }
        }
    }

    // MARK: - CRUD Operations

    func addEntry(_ entry: PracticeEntry) {
        practiceEntries.append(entry)
        practiceEntries.sort { $0.date > $1.date } // Most recent first
    }

    func updateEntry(_ entry: PracticeEntry) {
        if let index = practiceEntries.firstIndex(where: { $0.id == entry.id }) {
            practiceEntries[index] = entry
        }
    }

    func deleteEntry(_ entry: PracticeEntry) {
        practiceEntries.removeAll { $0.id == entry.id }
    }

    // MARK: - Statistics

    var totalPracticeTime: Int {
        practiceEntries.reduce(0) { $0 + $1.duration }
    }

    var totalPracticeDays: Int {
        let uniqueDates = Set(practiceEntries.map { Calendar.current.startOfDay(for: $0.date) })
        return uniqueDates.count
    }

    var currentStreak: Int {
        calculateCurrentStreak()
    }

    var longestStreak: Int {
        calculateLongestStreak()
    }

    var averageSessionLength: Double {
        guard !practiceEntries.isEmpty else { return 0 }
        return Double(totalPracticeTime) / Double(practiceEntries.count)
    }

    var thisWeekPracticeTime: Int {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return practiceEntries.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.duration }
    }

    var thisMonthPracticeTime: Int {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        return practiceEntries.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Streak Calculations

    private func calculateCurrentStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today

        // Check if practiced today
        let todayEntries = practiceEntries.filter { calendar.isDate($0.date, inSameDayAs: today) }
        if todayEntries.isEmpty {
            // If no practice today, check yesterday
            checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
        }

        while true {
            let dayEntries = practiceEntries.filter { calendar.isDate($0.date, inSameDayAs: checkDate) }
            if dayEntries.isEmpty {
                break
            }
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }

    private func calculateLongestStreak() -> Int {
        guard !practiceEntries.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedDates = practiceEntries
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()
            .reduce(into: [Date: Bool]()) { result, date in
                result[date] = true
            }

        let uniqueDates = sortedDates.keys.sorted()
        var longestStreak = 0
        var currentStreak = 0
        var previousDate: Date?

        for date in uniqueDates {
            if let prevDate = previousDate,
               let nextDay = calendar.date(byAdding: .day, value: 1, to: prevDate),
               calendar.isDate(date, inSameDayAs: nextDay) {
                currentStreak += 1
            } else {
                longestStreak = max(longestStreak, currentStreak)
                currentStreak = 1
            }
            previousDate = date
        }

        longestStreak = max(longestStreak, currentStreak)
        return longestStreak
    }

    // MARK: - Persistence

    private func saveEntries() {
        guard !isSyncing else { return } // Prevent save during sync
        
        // Save to both iCloud and UserDefaults
        saveToUserDefaults()
        saveToiCloud()
    }

    private func saveToiCloud() {
        guard let encoded = try? JSONEncoder().encode(practiceEntries) else {
            #if DEBUG
            print("❌ Failed to encode practice entries")
            #endif
            return
        }
        
        do {
            try iCloudManager.shared.writeFile(data: encoded, to: entriesURL)
            #if DEBUG
            print("✅ Saved practice entries to iCloud: \(entriesURL.path)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save practice entries to iCloud: \(error.localizedDescription)")
            print("   Attempting fallback write...")
            #endif
            // Fallback to direct write if coordination fails
            do {
                try encoded.write(to: entriesURL, options: [.atomic])
                #if DEBUG
                print("✅ Fallback write succeeded")
                #endif
            } catch {
                #if DEBUG
                print("❌ Fallback write also failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func saveToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(practiceEntries)
            UserDefaults.standard.set(data, forKey: entriesKey)
        } catch {
            print("Error saving practice entries to UserDefaults: \(error)")
        }
    }

    private func loadEntries() {
        // Try to load from iCloud first
        if let iCloudEntries = loadFromiCloud() {
            practiceEntries = iCloudEntries
            practiceEntries.sort { $0.date > $1.date } // Most recent first
            // Update local cache
            saveToUserDefaults()
        } else {
            // Fall back to UserDefaults (local cache)
            loadFromUserDefaults()
        }
    }

    private func loadFromiCloud() -> [PracticeEntry]? {
        do {
            let data = try iCloudManager.shared.readFile(from: entriesURL)
            if let decoded = try? JSONDecoder().decode([PracticeEntry].self, from: data) {
                #if DEBUG
                print("✅ Loaded \(decoded.count) practice entries from iCloud")
                #endif
                return decoded
            } else {
                #if DEBUG
                print("❌ Failed to decode practice entries from iCloud")
                #endif
            }
        } catch {
            #if DEBUG
            print("⚠️ Could not load from iCloud (file may not exist yet): \(error.localizedDescription)")
            #endif
            // File doesn't exist or can't be read - that's okay, use UserDefaults
        }
        return nil
    }

    private func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: entriesKey) else { return }

        do {
            practiceEntries = try JSONDecoder().decode([PracticeEntry].self, from: data)
            practiceEntries.sort { $0.date > $1.date } // Most recent first
        } catch {
            print("Error loading practice entries from UserDefaults: \(error)")
        }
    }

    // MARK: - iCloud Sync

    func syncFromiCloud() {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        #if DEBUG
        print("🔄 Syncing practice entries from iCloud...")
        #endif
        
        // When coming back online, sync from iCloud
        if let iCloudEntries = loadFromiCloud() {
            // Merge with local entries, using most recent modification
            let localEntries = practiceEntries
            var mergedEntries: [PracticeEntry] = []
            var entryMap: [UUID: PracticeEntry] = [:]
            
            // Create map of local entries
            for entry in localEntries {
                entryMap[entry.id] = entry
            }
            
            // Merge iCloud entries (they take precedence if they exist)
            for iCloudEntry in iCloudEntries {
                // Entry exists in both - prefer iCloud version
                // Remove from map to track which local entries are new
                entryMap.removeValue(forKey: iCloudEntry.id)
                mergedEntries.append(iCloudEntry)
            }
            
            // Add remaining local entries that aren't in iCloud
            for (_, localEntry) in entryMap {
                mergedEntries.append(localEntry)
            }
            
            let oldCount = practiceEntries.count
            practiceEntries = mergedEntries
            practiceEntries.sort { $0.date > $1.date }
            
            #if DEBUG
            print("✅ Sync complete: \(oldCount) → \(practiceEntries.count) entries")
            #endif
            
            // Save merged result back to both locations
            saveToUserDefaults()
            saveToiCloud()
        } else {
            // If iCloud file doesn't exist, ensure local changes are synced to iCloud
            // This handles the case where user made changes offline
            #if DEBUG
            print("⚠️ No iCloud file found, uploading local entries...")
            #endif
            saveToiCloud()
        }
    }

    func refreshFromiCloud() async {
        // Refresh from iCloud (for pull-to-refresh)
        await MainActor.run {
            syncFromiCloud()
        }
    }
    
    // Force a sync and save - useful for debugging
    func forceSync() {
        syncFromiCloud()
    }

    // MARK: - Helper Methods

    func entriesForDate(_ date: Date) -> [PracticeEntry] {
        let calendar = Calendar.current
        return practiceEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func hasPracticeOnDate(_ date: Date) -> Bool {
        return !entriesForDate(date).isEmpty
    }

    func averageRating() -> Double? {
        let ratedEntries = practiceEntries.compactMap { $0.rating }
        guard !ratedEntries.isEmpty else { return nil }
        return Double(ratedEntries.reduce(0, +)) / Double(ratedEntries.count)
    }
}
