import Foundation

enum PieceService {
    private static let fileName = "pieces.json"
    private static let cacheKey = "pieces_cache"

    static func load() -> [Piece] {
        var loaded: [Piece] = []

        for root in iCloudManager.shared.knownStorageRoots().values {
            let fileURL = root.appendingPathComponent(fileName)
            if let persisted = decode(readCoordinated(from: fileURL)) {
                loaded = merge(loaded, with: persisted)
            } else if let persisted = decode(try? Data(contentsOf: fileURL)) {
                loaded = merge(loaded, with: persisted)
            }
        }

        if !loaded.isEmpty {
            cache(loaded)
            return sorted(loaded)
        }

        return sorted(decode(UserDefaults.standard.data(forKey: cacheKey)) ?? [])
    }

    @discardableResult
    static func upsert(_ piece: Piece) throws -> [Piece] {
        let pieces = merge(load(), with: [piece])
        try persist(pieces)
        return pieces
    }

    @discardableResult
    static func delete(id: UUID) throws -> [Piece] {
        var pieces = load()
        pieces.removeAll { $0.id == id }
        try persist(pieces)
        return sorted(pieces)
    }

    /// Full-snapshot persist. Prefer `upsert` / `delete` for incremental UI edits.
    @discardableResult
    static func replace(with pieces: [Piece]) throws -> [Piece] {
        let resolved = sorted(pieces)
        try persist(resolved)
        return resolved
    }

    static func merge(_ lhs: [Piece], with rhs: [Piece]) -> [Piece] {
        var byID: [UUID: Piece] = [:]
        for piece in lhs + rhs {
            guard let existing = byID[piece.id] else {
                byID[piece.id] = piece
                continue
            }
            if piece.lastModified >= existing.lastModified {
                byID[piece.id] = piece
            }
        }
        return sorted(Array(byID.values))
    }

    private static func persist(_ pieces: [Piece]) throws {
        let normalized = sorted(pieces)
        let encoded = try JSONEncoder().encode(normalized)
        let fileURL = iCloudManager.shared.getDocumentsURL().appendingPathComponent(fileName)

        do {
            try iCloudManager.shared.writeFile(data: encoded, to: fileURL)
        } catch {
            try encoded.write(to: fileURL, options: .atomic)
        }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }

    private static func readCoordinated(from url: URL) -> Data? {
        try? iCloudManager.shared.readFile(from: url)
    }

    private static func decode(_ data: Data?) -> [Piece]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([Piece].self, from: data)
    }

    private static func cache(_ pieces: [Piece]) {
        guard let encoded = try? JSONEncoder().encode(pieces) else { return }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }

    private static func sorted(_ pieces: [Piece]) -> [Piece] {
        pieces.sorted {
            let comparison = $0.name.localizedCaseInsensitiveCompare($1.name)
            return comparison == .orderedSame
                ? $0.id.uuidString < $1.id.uuidString
                : comparison == .orderedAscending
        }
    }
}
