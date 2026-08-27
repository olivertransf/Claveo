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
            applyActiveEntries(from: allEntries)
        }
    }

    private var entriesByDay: [Date: [PracticeEntry]] = [:]
    private var cachedCurrentStreak = 0
    private var cachedTotalPracticeDays = 0
    private var cachedThisWeekPracticeTime = 0
    private var cachedAverageRating: Double?

    /// Bumped on every local mutation so in-flight iCloud syncs can abort.
    private var entriesGeneration = 0

    private let entriesKey = "practiceEntries"
    private let entriesFileName = "practiceEntries.json"
    private var entriesURL: URL {
        iCloudManager.shared.getDocumentsURL().appendingPathComponent(entriesFileName)
    }
    private var saveTask: Task<Void, Never>?
    private var iCloudWriteTask: Task<Void, Never>?
    private var isSyncing = false
    private var syncGeneration = 0

    private var hasPerformedInitialCloudSync = false

    init() {
        let loaded = loadFromUserDefaultsReturning()
        allEntries = loaded
        applyActiveEntries(from: loaded)

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rebuildStatsCache()
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
        entriesGeneration &+= 1
        scheduleSave()
    }

    func updateEntry(_ entry: PracticeEntry) {
        if let index = allEntries.firstIndex(where: { $0.id == entry.id }) {
            var updatedEntry = entry
            updatedEntry.lastModified = Date()
            allEntries[index] = updatedEntry
            entriesGeneration &+= 1
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
            entriesGeneration &+= 1
            scheduleSave()
        }
    }

    func removeRecordingReferences(to recordingID: UUID) {
        let updated = Self.removingRecordingID(recordingID, from: allEntries)
        guard updated != allEntries else { return }
        allEntries = updated
        entriesGeneration &+= 1
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
        cachedTotalPracticeDays
    }

    var currentStreak: Int {
        cachedCurrentStreak
    }

    var longestStreak: Int {
        calculateLongestStreak()
    }

    var averageSessionLength: Double {
        guard !practiceEntries.isEmpty else { return 0 }
        return Double(totalPracticeTime) / Double(practiceEntries.count)
    }

    var thisWeekPracticeTime: Int {
        cachedThisWeekPracticeTime
    }

    var thisMonthPracticeTime: Int {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            return 0
        }
        return practiceEntries.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Streak Calculations

    private func applyActiveEntries(from entries: [PracticeEntry]) {
        practiceEntries = entries
            .filter { !$0.isDeleted }
            .sorted { $0.date > $1.date }
        rebuildStatsCache()
    }

    private func rebuildStatsCache() {
        let calendar = Calendar.current
        let now = Date()
        entriesByDay = Self.dayIndex(from: practiceEntries, calendar: calendar)
        cachedCurrentStreak = Self.currentStreak(dayIndex: entriesByDay, now: now, calendar: calendar)
        cachedTotalPracticeDays = entriesByDay.count
        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ) ?? calendar.startOfDay(for: now)
        cachedThisWeekPracticeTime = practiceEntries.reduce(0) { partial, entry in
            partial + (entry.date >= weekStart ? entry.duration : 0)
        }
        cachedAverageRating = Self.averageRating(from: practiceEntries)
    }

    static func dayIndex(
        from entries: [PracticeEntry],
        calendar: Calendar = .current
    ) -> [Date: [PracticeEntry]] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
    }

    static func currentStreak(
        dayIndex: [Date: [PracticeEntry]],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        var streak = 0
        var checkDate = today
        if dayIndex[today] == nil {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return 0
            }
            checkDate = yesterday
        }
        while dayIndex[checkDate] != nil {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previous
        }
        return streak
    }

    static func entries(
        on date: Date,
        dayIndex: [Date: [PracticeEntry]],
        calendar: Calendar = .current
    ) -> [PracticeEntry] {
        dayIndex[calendar.startOfDay(for: date)] ?? []
    }

    static func averageRating(from entries: [PracticeEntry]) -> Double? {
        let ratedEntries = entries.compactMap(\.rating)
        guard !ratedEntries.isEmpty else { return nil }
        return Double(ratedEntries.reduce(0, +)) / Double(ratedEntries.count)
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
        let entriesSnapshot = allEntries
        guard let encoded = try? JSONEncoder().encode(entriesSnapshot) else { return }
        let url = entriesURL
        let previousWrite = iCloudWriteTask

        iCloudWriteTask = Task.detached(priority: .utility) {
            await previousWrite?.value
            do {
                try iCloudManager.shared.writeFile(data: encoded, to: url)
            } catch {
                try? encoded.write(to: url, options: [.atomic])
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
    nonisolated private static func mergeEntries(local: [PracticeEntry], cloud: [PracticeEntry]) -> [PracticeEntry] {
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

    // MARK: - iCloud Sync

    func syncFromiCloud() {
        guard !isSyncing else { return }
        isSyncing = true
        syncGeneration &+= 1
        let generationAtStart = syncGeneration
        let url = entriesURL
        let localSnapshot = allEntries
        let entriesGenerationAtStart = entriesGeneration

        Task.detached(priority: .utility) {
            let cloudData = try? iCloudManager.shared.readFile(from: url)
            let cloudEntries = cloudData.flatMap { try? JSONDecoder().decode([PracticeEntry].self, from: $0) }
            let merged = cloudEntries.map { Self.mergeEntries(local: localSnapshot, cloud: $0) } ?? localSnapshot

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.isSyncing, self.syncGeneration == generationAtStart else { return }
                // Abort if the user changed entries while the cloud read was in flight.
                guard self.entriesGeneration == entriesGenerationAtStart else {
                    self.isSyncing = false
                    self.saveToiCloud()
                    return
                }

                if merged != self.allEntries {
                    self.allEntries = merged
                    self.saveToUserDefaults()
                }

                // Always write back our merged view so devices converge, but never block UI.
                self.saveToiCloud()
                self.isSyncing = false
            }
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
        Self.entries(on: date, dayIndex: entriesByDay)
    }

    func hasPracticeOnDate(_ date: Date) -> Bool {
        !entriesForDate(date).isEmpty
    }

    func averageRating() -> Double? {
        cachedAverageRating
    }
}
