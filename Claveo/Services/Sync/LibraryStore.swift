import Foundation

protocol TombstonedRecord: Codable, Identifiable where ID == UUID {
    var isDeleted: Bool { get }
    var lastModified: Date { get }
}

extension Recording: TombstonedRecord {}
extension PracticeEntry: TombstonedRecord {}
extension Piece: TombstonedRecord {}

enum LibraryCollection: String, Sendable {
    case recordings
    case practice
    case pieces
}

enum LibraryFiles {
    nonisolated static let tombstoneRetention: TimeInterval = 30 * 24 * 60 * 60
    static let migrationDefaultsKey = "claveo.metadataSidecarsMigrated"

    nonisolated static func metadataDirectory(root: URL, collection: LibraryCollection) -> URL {
        root
            .appendingPathComponent("Metadata", isDirectory: true)
            .appendingPathComponent(collection.rawValue, isDirectory: true)
    }

    static func directory(root: URL, collection: LibraryCollection) -> URL {
        metadataDirectory(root: root, collection: collection)
    }

    nonisolated static func writePayloads(
        _ files: [(id: UUID, data: Data)],
        collection: LibraryCollection,
        root: URL
    ) throws {
        let directory = metadataDirectory(root: root, collection: collection)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for file in files {
            let url = directory.appendingPathComponent("\(file.id.uuidString).json")
            try iCloudManager.shared.writeFile(data: file.data, to: url)
        }
    }

    nonisolated static func removePayload(id: UUID, collection: LibraryCollection, root: URL) {
        let url = metadataDirectory(root: root, collection: collection)
            .appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated static func readPayloads(collection: LibraryCollection, roots: [URL]) -> [Data] {
        roots.flatMap { root in
            let directory = metadataDirectory(root: root, collection: collection)
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
            return files.compactMap { url -> Data? in
                guard url.pathExtension == "json" else { return nil }
                return try? iCloudManager.shared.readFile(from: url)
            }
        }
    }

    static func write<T: Encodable & Identifiable>(
        _ items: [T],
        collection: LibraryCollection,
        root: URL
    ) throws where T.ID == UUID {
        let directory = directory(root: root, collection: collection)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        for item in items {
            let data = try encoder.encode(item)
            let url = directory.appendingPathComponent("\(item.id.uuidString).json")
            try iCloudManager.shared.writeFile(data: data, to: url)
        }
    }

    static func remove(id: UUID, collection: LibraryCollection, root: URL) {
        let url = directory(root: root, collection: collection)
            .appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    static func read<T: Decodable>(
        _ type: T.Type,
        collection: LibraryCollection,
        roots: [URL]
    ) -> [T] {
        roots.flatMap { root in
            let directory = directory(root: root, collection: collection)
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
            return files.compactMap { url -> T? in
                guard url.pathExtension == "json" else { return nil }
                guard let data = try? iCloudManager.shared.readFile(from: url) else { return nil }
                return try? JSONDecoder().decode(T.self, from: data)
            }
        }
    }

    static func readLegacy<T: Decodable>(_ type: T.Type, fileName: String, roots: [URL]) -> [T] {
        roots.flatMap { root -> [T] in
            let url = root.appendingPathComponent(fileName)
            guard let data = try? iCloudManager.shared.readFile(from: url) else { return [] }
            return (try? JSONDecoder().decode([T].self, from: data)) ?? []
        }
    }

    static func expired<T: TombstonedRecord>(_ items: [T], now: Date = Date()) -> [T] {
        let cutoff = now.addingTimeInterval(-tombstoneRetention)
        return items.filter { $0.isDeleted && $0.lastModified < cutoff }
    }

    static func keepingLive<T: TombstonedRecord>(_ items: [T], now: Date = Date()) -> [T] {
        let expiredIDs = Set(expired(items, now: now).map(\.id))
        return items.filter { !expiredIDs.contains($0.id) }
    }

    /// Picks the newest `lastModified`. Equal timestamps keep the later candidate, which is the current item when it is passed last.
    static func newest<T: TombstonedRecord>(_ versions: [T]) -> T? {
        versions.max { lhs, rhs in
            if lhs.lastModified == rhs.lastModified {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.lastModified < rhs.lastModified
        }
    }

    nonisolated static func resolveConflicts(at url: URL) {
        let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
        guard !conflicts.isEmpty else { return }
        guard let current = NSFileVersion.currentVersionOfItem(at: url) else { return }

        let candidates = ([current] + conflicts).compactMap { version -> (version: NSFileVersion, modified: Date)? in
            let versionURL = version.url
            guard let data = try? Data(contentsOf: versionURL),
                  let modified = modificationDate(in: data) else {
                return nil
            }
            return (version, modified)
        }
        guard let winner = candidates.max(by: { $0.modified < $1.modified }) else { return }
        if winner.version != current {
            _ = try? winner.version.replaceItem(at: url, options: [])
        }
        current.isResolved = true
        for conflict in conflicts {
            conflict.isResolved = true
        }
        try? NSFileVersion.removeOtherVersionsOfItem(at: url)
    }

    private nonisolated static func modificationDate(in data: Data) -> Date? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let seconds = object["lastModified"] as? TimeInterval {
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        if let text = object["lastModified"] as? String {
            return ISO8601DateFormatter().date(from: text)
        }
        return nil
    }
}

actor LibraryStore {
    static let shared = LibraryStore()

    func replace(
        payloads: [(id: UUID, data: Data)],
        removingIDs: [UUID],
        audioFileNames: [String],
        collection: LibraryCollection,
        root: URL
    ) throws {
        for id in removingIDs {
            LibraryFiles.removePayload(id: id, collection: collection, root: root)
        }
        for name in audioFileNames where !name.isEmpty {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(name))
        }
        try LibraryFiles.writePayloads(payloads, collection: collection, root: root)
    }
}
