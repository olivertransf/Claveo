//
//  iCloudManager.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation
import UIKit

extension Notification.Name {
    static let claveoStorageLocationDidChange = Notification.Name("claveoStorageLocationDidChange")
}

nonisolated(unsafe) private let storeFilesOnDeviceOnlyUserDefaultsKey = "storeFilesOnDeviceOnly"

/// Manages iCloud Drive sync for recordings and metadata.
/// Returns local Documents immediately; resolves the ubiquity container on a background task.
final class iCloudManager: @unchecked Sendable {
    nonisolated static let shared = iCloudManager()

    private let containerIdentifier = "iCloud.com.olivertran.Claveo"
    private nonisolated(unsafe) let fileCoordinator = NSFileCoordinator()
    private let localDocumentsURL: URL
    private nonisolated(unsafe) var resolvedDocumentsURL: URL?
    private nonisolated(unsafe) var resolvedICloudDocumentsURL: URL?
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
            lock.unlock()
            notifyStorageLocationDidChange()
            return
        }

        lock.lock()
        if let cloudURL = resolvedICloudDocumentsURL {
            resolvedDocumentsURL = cloudURL
        }
        let stuckOnLocal = resolvedICloudDocumentsURL == nil
        let preferenceChanged = current != enabled
        lock.unlock()

        if preferenceChanged && !stuckOnLocal {
            notifyStorageLocationDidChange()
            return
        }

        if stuckOnLocal {
            lock.lock()
            warmUpTask = nil
            lock.unlock()
            warmUp()
        }
    }

    nonisolated func warmUp(force: Bool = false) {
        lock.lock()
        if warmUpTask != nil, !force {
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
    /// Retries when a prior resolve found no container (e.g. user signed into iCloud later).
    nonisolated func warmUpIfNeeded() async {
        let shouldRetry = shouldRetryUbiquityResolve()
        warmUp(force: shouldRetry)
        let task = copyWarmUpTask()
        await task?.value
    }

    nonisolated private func shouldRetryUbiquityResolve() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !prefersDeviceOnlyStorage && resolvedICloudDocumentsURL == nil
    }

    nonisolated private func copyWarmUpTask() -> Task<Void, Never>? {
        lock.lock()
        defer { lock.unlock() }
        return warmUpTask
    }

    nonisolated private func storeResolvedURL(_ url: URL, iCloudActive: Bool) {
        lock.lock()
        if iCloudActive {
            resolvedICloudDocumentsURL = url
        }
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

    nonisolated var activeStorageLocation: RecordingStorageLocation {
        getDocumentsURL() == localDocumentsURL ? .device : .iCloud
    }

    nonisolated func documentsURL(for location: RecordingStorageLocation) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        switch location {
        case .device:
            return localDocumentsURL
        case .iCloud:
            return resolvedICloudDocumentsURL
        }
    }

    nonisolated func knownStorageRoots() -> [RecordingStorageLocation: URL] {
        lock.lock()
        defer { lock.unlock() }
        var roots: [RecordingStorageLocation: URL] = [.device: localDocumentsURL]
        if let resolvedICloudDocumentsURL {
            roots[.iCloud] = resolvedICloudDocumentsURL
        }
        return roots
    }

    nonisolated func fileURL(
        fileName: String,
        pinnedLocation: RecordingStorageLocation?
    ) -> URL {
        Self.resolvedFileURL(
            fileName: fileName,
            pinnedLocation: pinnedLocation,
            roots: knownStorageRoots(),
            defaultRoot: getDocumentsURL()
        )
    }

    nonisolated static func resolvedFileURL(
        fileName: String,
        pinnedLocation: RecordingStorageLocation?,
        roots: [RecordingStorageLocation: URL],
        defaultRoot: URL
    ) -> URL {
        if let pinnedLocation, let pinnedRoot = roots[pinnedLocation] {
            return pinnedRoot.appendingPathComponent(fileName)
        }
        if let existing = existingFileURL(
            fileName: fileName,
            pinnedLocation: nil,
            roots: roots
        ) {
            return existing
        }
        return defaultRoot.appendingPathComponent(fileName)
    }

    nonisolated func storageLocation(
        containing fileName: String,
        preferred: RecordingStorageLocation?
    ) -> RecordingStorageLocation? {
        let roots = knownStorageRoots()
        if let preferred,
           let root = roots[preferred],
           FileManager.default.fileExists(atPath: root.appendingPathComponent(fileName).path) {
            return preferred
        }
        return roots.keys
            .sorted { $0.rawValue < $1.rawValue }
            .first { location in
                guard let root = roots[location] else { return false }
                return FileManager.default.fileExists(
                    atPath: root.appendingPathComponent(fileName).path
                )
            }
    }

    nonisolated static func existingFileURL(
        fileName: String,
        pinnedLocation: RecordingStorageLocation?,
        roots: [RecordingStorageLocation: URL]
    ) -> URL? {
        var locations: [RecordingStorageLocation] = []
        if let pinnedLocation {
            locations.append(pinnedLocation)
        }
        locations.append(contentsOf: roots.keys.sorted { $0.rawValue < $1.rawValue })

        for location in locations {
            guard let root = roots[location] else { continue }
            let candidate = root.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    @discardableResult
    nonisolated static func copyFileIfDestinationMissing(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws -> Bool {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return false
        }
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            return false
        }
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return true
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
            return UIDevice.current.userInterfaceIdiom == .pad
                ? String(localized: "On This iPad")
                : String(localized: "On This iPhone")
        }
        return isAvailable ? String(localized: "iCloud Drive") : String(localized: "Local Storage")
    }

    nonisolated func getStoragePath() -> String {
        getDocumentsURL().path
    }

    nonisolated func startKeepingDownloaded(at url: URL) throws {
        guard FileManager.default.isUbiquitousItem(at: url) else { return }
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    nonisolated func removeLocalDownload(at url: URL) throws {
        guard FileManager.default.isUbiquitousItem(at: url) else { return }
        try FileManager.default.evictUbiquitousItem(at: url)
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
