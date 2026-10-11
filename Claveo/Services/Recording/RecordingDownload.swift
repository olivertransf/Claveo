//
//  RecordingDownload.swift
//  Claveo
//
//  Copyright (c) 2026 Oliver Tran

import Foundation

nonisolated enum RecordingTransferPolicy {
    /// Audio leaves iCloud only when the user plays, trims, exports, or keeps that file.
    static func shouldStartDownload(userRequested: Bool, isPlaceholder: Bool) -> Bool {
        userRequested && isPlaceholder
    }
}

nonisolated enum RecordingDownload {
    static func isPlaceholder(at url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ])
        return values?.isUbiquitousItem == true
            && values?.ubiquitousItemDownloadingStatus == .notDownloaded
    }

    static func percentDownloaded(at url: URL) -> Double {
        DownloadPercentQuery.percent(for: url.lastPathComponent) ?? (isLocal(at: url) ? 100 : 0)
    }

    static func isLocal(at url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ])
        if values?.isUbiquitousItem == true {
            return values?.ubiquitousItemDownloadingStatus != .some(.notDownloaded)
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    @discardableResult
    static func waitUntilLocal(
        at url: URL,
        timeout: TimeInterval = 120,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async -> Bool {
        if isLocal(at: url) {
            onProgress(1)
            return true
        }
        if !isPlaceholder(at: url), !FileManager.default.fileExists(atPath: url.path) {
            return false
        }
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        } catch {
            return false
        }
        let watcher = DownloadPercentQuery(fileName: url.lastPathComponent)
        await MainActor.run { watcher.start() }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Task.isCancelled {
                await MainActor.run { watcher.stop() }
                return false
            }
            let fraction = min(max(watcher.percent / 100, 0), 1)
            onProgress(fraction)
            if isLocal(at: url) {
                onProgress(1)
                await MainActor.run { watcher.stop() }
                return true
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        await MainActor.run { watcher.stop() }
        return isLocal(at: url)
    }
}

/// One-file metadata query. Percent downloaded is not available on `URLResourceValues` for iOS.
nonisolated private final class DownloadPercentQuery: NSObject, @unchecked Sendable {
    private static let lock = NSLock()
    private static var latest: [String: Double] = [:]

    let fileName: String
    private let query = NSMetadataQuery()
    private var observers: [NSObjectProtocol] = []
    var percent: Double {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return Self.latest[fileName] ?? 0
    }

    init(fileName: String) {
        self.fileName = fileName
    }

    static func percent(for fileName: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        return latest[fileName]
    }

    func start() {
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, fileName)
        let center = NotificationCenter.default
        for name: Notification.Name in [.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(center.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                self?.read()
            })
        }
        query.start()
    }

    func stop() {
        query.stop()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func read() {
        query.disableUpdates()
        defer { query.enableUpdates() }
        guard let item = query.results.first as? NSMetadataItem else { return }
        let value = (item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.doubleValue ?? 0
        Self.lock.lock()
        Self.latest[fileName] = value
        Self.lock.unlock()
    }
}
