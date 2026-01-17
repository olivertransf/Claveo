//
//  PracticeService.swift
//  Claveo
//
//  Created by Oliver Tran on 12/22/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation
import Combine
import UIKit

@MainActor
class PracticeService: ObservableObject {
    static let shared = PracticeService()

    @Published var practiceEntries: [PracticeEntry] = [] {
        didSet {
            // Only autosave if the change wasn't triggered by internal sync logic
            // We'll manage saving explicitly in add/update/delete/sync methods
            // to avoid infinite loops or unnecessary writes when just filtering.
        }
    }
    
    // The source of truth including deleted items
    private var allEntries: [PracticeEntry] = [] {
        didSet {
            // Update the UI-facing list whenever the source changes
            practiceEntries = allEntries
                .filter { !$0.isDeleted }
                .sorted { $0.date > $1.date }
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
        var newEntry = entry
        newEntry.lastModified = Date()
        allEntries.append(newEntry)
        scheduleSave()
    }

    func updateEntry(_ entry: PracticeEntry) {
        if let index = allEntries.firstIndex(where: { $0.id == entry.id }) {
            var updatedEntry = entry
            updatedEntry.lastModified = Date()
            allEntries[index] = updatedEntry
            scheduleSave()
        }
    }

    func deleteEntry(_ entry: PracticeEntry) {
        if let index = allEntries.firstIndex(where: { $0.id == entry.id }) {
            // Soft delete
            var deletedEntry = allEntries[index]
            deletedEntry.isDeleted = true
            deletedEntry.lastModified = Date()
            allEntries[index] = deletedEntry
            scheduleSave()
        }
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
    
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            if !Task.isCancelled {
                saveEntries()
            }
        }
    }

    private func saveEntries() {
        guard !isSyncing else { return } // Prevent save during sync
        
        // Save to both iCloud and UserDefaults
        saveToUserDefaults()
        saveToiCloud()
    }

    private func saveToiCloud() {
        // Encode allEntries (including deleted ones)
        guard let encoded = try? JSONEncoder().encode(allEntries) else {
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
            let data = try JSONEncoder().encode(allEntries)
            UserDefaults.standard.set(data, forKey: entriesKey)
        } catch {
            print("Error saving practice entries to UserDefaults: \(error)")
        }
    }

    private func loadEntries() {
        // Try to load from iCloud first
        if let iCloudEntries = loadFromiCloud() {
            allEntries = iCloudEntries
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
            allEntries = try JSONDecoder().decode([PracticeEntry].self, from: data)
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
            // Match Logic: Last Modified Wins
            // Merge cloud entries into local allEntries
            
            var entryMap: [UUID: PracticeEntry] = [:]
            
            // Start with local entries
            for entry in allEntries {
                entryMap[entry.id] = entry
            }
            
            // Merge iCloud entries
            var changeCount = 0
            
            for cloudEntry in iCloudEntries {
                if let localEntry = entryMap[cloudEntry.id] {
                    // Conflict resolution: prefer the one with later modification date
                    if cloudEntry.lastModified > localEntry.lastModified {
                        entryMap[cloudEntry.id] = cloudEntry
                        changeCount += 1
                    }
                    // Else: keep local version
                } else {
                    // New entry from cloud
                    entryMap[cloudEntry.id] = cloudEntry
                    changeCount += 1
                }
            }
            
            // No need to "Add remaining local entries" because we started with them in the map
            // and only updated or added to it.
            
            if changeCount > 0 {
                let mergedEntries = Array(entryMap.values)
                allEntries = mergedEntries
                
                #if DEBUG
                print("✅ Sync complete: Updated \(changeCount) entries from cloud. Total: \(allEntries.count) (including deleted)")
                #endif
                
                // Save merged result back to both locations to propagate merges
                saveToUserDefaults()
                saveToiCloud()
            } else {
                #if DEBUG
                print("✅ Sync complete: No changes from cloud needed.")
                #endif
                
                // If we have local changes that aren't in cloud (cloud count < local count or just different),
                // we should push them up.
                // Simple heuristic: if counts differ or we just feel like it, save to cloud to be safe.
                // Since efficient save checks are hard without diffing, we'll just save if we have any entries.
                saveToiCloud()
            }
            
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
