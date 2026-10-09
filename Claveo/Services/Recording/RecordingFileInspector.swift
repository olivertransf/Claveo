// Copyright (c) 2025 Oliver Tran

import Foundation

nonisolated struct RecordingFileStatus: Sendable, Equatable {
    var isLocallyAvailable: Bool
    var storageLocation: RecordingStorageLocation?
}

nonisolated enum RecordingFileInspector {
    /// Stats one audio file. Starts an iCloud download only when asked, and only for that file.
    static func inspect(
        fileName: String,
        pinnedLocation: RecordingStorageLocation?,
        roots: [RecordingStorageLocation: URL],
        defaultRoot: URL,
        startDownloadIfMissing: Bool
    ) -> RecordingFileStatus {
        let location = pinnedLocation ?? locatedRoot(for: fileName, roots: roots)
        let root = location.flatMap { roots[$0] } ?? defaultRoot
        let url = root.appendingPathComponent(fileName)
        let available = isLocallyAvailable(
            at: url,
            startDownloadIfMissing: startDownloadIfMissing
        )
        return RecordingFileStatus(isLocallyAvailable: available, storageLocation: location)
    }

    private static func locatedRoot(
        for fileName: String,
        roots: [RecordingStorageLocation: URL]
    ) -> RecordingStorageLocation? {
        roots.keys
            .sorted { $0.rawValue < $1.rawValue }
            .first { location in
                guard let root = roots[location] else { return false }
                return FileManager.default.fileExists(
                    atPath: root.appendingPathComponent(fileName).path
                )
            }
    }

    private static func isLocallyAvailable(at url: URL, startDownloadIfMissing: Bool) -> Bool {
        let values = try? url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ])
        if values?.isUbiquitousItem == true {
            let downloaded = values?.ubiquitousItemDownloadingStatus != .some(.notDownloaded)
            if !downloaded, startDownloadIfMissing {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
            return downloaded
        }
        return FileManager.default.fileExists(atPath: url.path)
    }
}

/// Serializes file stats so visible rows are checked one at a time, off the main actor.
actor RecordingVisibilityLoader {
    static let shared = RecordingVisibilityLoader()

    func inspect(
        fileName: String,
        pinnedLocation: RecordingStorageLocation?,
        roots: [RecordingStorageLocation: URL],
        defaultRoot: URL,
        startDownloadIfMissing: Bool
    ) async -> RecordingFileStatus? {
        guard !Task.isCancelled else { return nil }
        return RecordingFileInspector.inspect(
            fileName: fileName,
            pinnedLocation: pinnedLocation,
            roots: roots,
            defaultRoot: defaultRoot,
            startDownloadIfMissing: startDownloadIfMissing
        )
    }
}
