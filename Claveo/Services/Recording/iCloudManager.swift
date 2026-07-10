//
//  iCloudManager.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

extension Notification.Name {
    static let claveoStorageLocationDidChange = Notification.Name("claveoStorageLocationDidChange")
}

private let storeFilesOnDeviceOnlyUserDefaultsKey = "storeFilesOnDeviceOnly"

/// Manages iCloud Drive sync for recordings and metadata.
/// Returns local Documents immediately; resolves the ubiquity container on a background task.
final class iCloudManager: @unchecked Sendable {
    nonisolated static let shared = iCloudManager()

    private let containerIdentifier = "iCloud.com.olivertran.Claveo"
    private nonisolated(unsafe) let fileCoordinator = NSFileCoordinator()
    private let localDocumentsURL: URL
    private nonisolated(unsafe) var resolvedDocumentsURL: URL?
    private nonisolated(unsafe) var warmUpTask: Task<Void, Never>?
    private let lock = NSLock()

    nonisolated private init() {
        localDocumentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if prefersDeviceOnlyStorage {
            resolvedDocumentsURL = localDocumentsURL
        }
    }

    nonisolated var prefersDeviceOnlyStorage: Bool {
        UserDefaults.standard.bool(forKey: storeFilesOnDeviceOnlyUserDefaultsKey)
    }

    nonisolated func setStoreFilesOnDeviceOnly(_ enabled: Bool) {
        let current = UserDefaults.standard.bool(forKey: storeFilesOnDeviceOnlyUserDefaultsKey)
        UserDefaults.standard.set(enabled, forKey: storeFilesOnDeviceOnlyUserDefaultsKey)

        if enabled {
            lock.lock()
            resolvedDocumentsURL = localDocumentsURL
            warmUpTask = nil
            lock.unlock()
            notifyStorageLocationDidChange()
            return
        }

        lock.lock()
        let stuckOnLocal = resolvedDocumentsURL == nil || resolvedDocumentsURL == localDocumentsURL
        let preferenceChanged = current != enabled
        lock.unlock()

        if preferenceChanged {
            lock.lock()
            resolvedDocumentsURL = nil
            warmUpTask = nil
            lock.unlock()
            warmUp()
            return
        }

        if stuckOnLocal {
            lock.lock()
            warmUpTask = nil
            lock.unlock()
            warmUp()
        }
    }

    /// Non-blocking. Starts background ubiquity resolution if needed.
    nonisolated func warmUp() {
        lock.lock()
        if warmUpTask != nil {
            lock.unlock()
            return
        }
        if prefersDeviceOnlyStorage {
            resolvedDocumentsURL = localDocumentsURL
            let localURL = localDocumentsURL
            warmUpTask = Task.detached(priority: .utility) {
                iCloudManager.shared.storeResolvedURL(localURL, iCloudActive: false)
            }
            lock.unlock()
            return
        }
        let containerId = containerIdentifier
        let coordinator = fileCoordinator
        let localURL = localDocumentsURL
        warmUpTask = Task.detached(priority: .utility) {
            let iCloudURL = Self.resolveUbiquityDocumentsURL(
                containerIdentifier: containerId,
                fileCoordinator: coordinator
            )
            let resolved = iCloudURL ?? localURL
             iCloudManager.shared.storeResolvedURL(resolved, iCloudActive: iCloudURL != nil)
        }
        lock.unlock()
    }

    /// Awaits background ubiquity resolution started by `warmUp()`.
    nonisolated func warmUpIfNeeded() async {
        warmUp()
        let task = copyWarmUpTask()
        await task?.value
    }

    nonisolated private func copyWarmUpTask() -> Task<Void, Never>? {
        lock.lock()
        defer { lock.unlock() }
        return warmUpTask
    }

    nonisolated private func storeResolvedURL(_ url: URL, iCloudActive: Bool) {
        lock.lock()
        if prefersDeviceOnlyStorage {
            resolvedDocumentsURL = localDocumentsURL
        } else {
            resolvedDocumentsURL = iCloudActive ? url : localDocumentsURL
        }
        lock.unlock()
        #if DEBUG
        let usingiCloud = iCloudActive && !prefersDeviceOnlyStorage
        print("📁 Documents ready: \(usingiCloud ? "iCloud Drive" : "Local") — \(url.path)")
        #endif
        notifyStorageLocationDidChange()
    }

    nonisolated private func notifyStorageLocationDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .claveoStorageLocationDidChange, object: nil)
        }
    }

    /// Immediate URL for reads/writes (local until iCloud path is resolved).
    nonisolated func getDocumentsURL() -> URL {
        lock.lock()
        defer { lock.unlock() }
        if prefersDeviceOnlyStorage {
            return localDocumentsURL
        }
        return resolvedDocumentsURL ?? localDocumentsURL
    }

    nonisolated var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        if prefersDeviceOnlyStorage { return false }
        guard let resolved = resolvedDocumentsURL else { return false }
        return resolved != localDocumentsURL
    }

    nonisolated func writeFile(data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?

        fileCoordinator.coordinate(writingItemAt: url, options: [], error: &coordinationError) { writingURL in
            do {
                try data.write(to: writingURL, options: [.atomic])
            } catch {
                writeError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let writeError {
            throw writeError
        }
    }

    nonisolated func readFile(from url: URL) throws -> Data {
        var coordinationError: NSError?
        var readError: Error?
        var fileData: Data?

        fileCoordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readingURL in
            do {
                fileData = try Data(contentsOf: readingURL)
            } catch {
                readError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let readError {
            throw readError
        }

        guard let fileData else {
            throw NSError(domain: "iCloudManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read file"])
        }

        return fileData
    }

    nonisolated func getStorageLocation() -> String {
        if prefersDeviceOnlyStorage {
            return String(localized: "On This iPhone")
        }
        return isAvailable ? String(localized: "iCloud Drive") : String(localized: "Local Storage")
    }

    nonisolated func getStoragePath() -> String {
        getDocumentsURL().path
    }

    nonisolated private static func resolveUbiquityDocumentsURL(
        containerIdentifier: String,
        fileCoordinator: NSFileCoordinator
    ) -> URL? {
        guard let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            return nil
        }
        let documentsURL = ubiquityURL.appendingPathComponent("Documents")

        var coordinationError: NSError?
        fileCoordinator.coordinate(writingItemAt: documentsURL, options: [], error: &coordinationError) { writingURL in
            if !FileManager.default.fileExists(atPath: writingURL.path) {
                try? FileManager.default.createDirectory(at: writingURL, withIntermediateDirectories: true)
            }
        }

        if coordinationError != nil {
            return nil
        }

        return documentsURL
    }
}
