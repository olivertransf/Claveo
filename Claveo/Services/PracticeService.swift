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

    private var hasPerformedInitialCloudSync = false

    init() {
        allEntries = loadFromUserDefaultsReturning()

        // Listen for app becoming active to sync entries
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncFromiCloudIfReady()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncFromiCloudIfReady()
            }
        }
    }

    func performInitialCloudSync() async {
        guard !hasPerformedInitialCloudSync else { return }
        hasPerformedInitialCloudSync = true
        await iCloudManager.shared.warmUpIfNeeded()
        syncFromiCloud()
    }

    private func syncFromiCloudIfReady() async {
        await iCloudManager.shared.warmUpIfNeeded()
        syncFromiCloud()
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

    func removeRecordingReferences(to recordingID: UUID) {
        let updated = Self.removingRecordingID(recordingID, from: allEntries)
        guard updated != allEntries else { return }
        allEntries = updated
        scheduleSave()
    }

    static func removingRecordingID(
        _ recordingID: UUID,
        from entries: [PracticeEntry],
        modifiedAt: Date = Date()
    ) -> [PracticeEntry] {
        entries.map { entry in
            guard entry.linkedRecordingIds.contains(recordingID) else { return entry }
            var updated = entry
            updated.linkedRecordingIds.removeAll { $0 == recordingID }
            updated.lastModified = max(modifiedAt, entry.lastModified.addingTimeInterval(0.001))
            return updated
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
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return 0
        }
        return practiceEntries.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.duration }
    }

    var thisMonthPracticeTime: Int {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            return 0
        }
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

    /// Last-modified-wins merge (same rules as sync).
    private func mergeEntries(local: [PracticeEntry], cloud: [PracticeEntry]) -> [PracticeEntry] {
        var map: [UUID: PracticeEntry] = [:]
        for e in local { map[e.id] = e }
        for cloudEntry in cloud {
            if let localEntry = map[cloudEntry.id] {
                if cloudEntry.lastModified > localEntry.lastModified {
                    map[cloudEntry.id] = cloudEntry
                }
            } else {
                map[cloudEntry.id] = cloudEntry
            }
        }
        // Stable order so an unchanged merge compares equal and skips a rewrite.
        return map.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func loadFromUserDefaultsReturning() -> [PracticeEntry] {
        guard let data = UserDefaults.standard.data(forKey: entriesKey) else { return [] }
        do {
            return try JSONDecoder().decode([PracticeEntry].self, from: data)
        } catch {
            #if DEBUG
            print("Error loading practice entries from UserDefaults: \(error)")
            #endif
            return []
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
            let merged = mergeEntries(local: allEntries, cloud: iCloudEntries)
            if merged != allEntries {
                allEntries = merged
                #if DEBUG
                print("✅ Sync complete: merged cloud. Total: \(allEntries.count) (including deleted)")
                #endif
                saveToUserDefaults()
            } else {
                #if DEBUG
                print("✅ Sync complete: No changes from cloud needed.")
                #endif
            }
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
        await syncFromiCloudIfReady()
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
