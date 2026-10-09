import Foundation

enum PieceService {
    private static let fileName = "pieces.json"
    private static let cacheKey = "pieces_cache"

    static func load() -> [Piece] {
        sorted(loadAll().filter { !$0.isDeleted })
    }

    static func loadAll() -> [Piece] {
        let roots = Array(iCloudManager.shared.knownStorageRoots().values)
        var loaded = LibraryFiles.read(Piece.self, collection: .pieces, roots: roots)
        loaded = merge(loaded, with: LibraryFiles.readLegacy(Piece.self, fileName: fileName, roots: roots))

        if loaded.isEmpty {
            loaded = decode(UserDefaults.standard.data(forKey: cacheKey)) ?? []
        }
        let kept = LibraryFiles.keepingLive(loaded)
        if !kept.isEmpty {
            cache(kept)
        }
        return sorted(kept)
    }

    @discardableResult
    static func upsert(_ piece: Piece) throws -> [Piece] {
        let pieces = merge(load(), with: [piece])
        try persist(pieces)
        return pieces
    }

    @discardableResult
    static func delete(id: UUID) throws -> [Piece] {
        var pieces = loadAll()
        guard let index = pieces.firstIndex(where: { $0.id == id }) else {
            return load()
        }
        pieces[index].isDeleted = true
        pieces[index].lastModified = Date()
        try persist(pieces)
        return load()
    }

    /// Full-snapshot persist. Prefer `upsert` / `delete` for incremental UI edits.
    @discardableResult
    static func replace(with pieces: [Piece]) throws -> [Piece] {
        let tombstones = loadAll().filter(\.isDeleted)
        let resolved = merge(tombstones, with: pieces)
        try persist(resolved)
        return resolved.filter { !$0.isDeleted }
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
        let root = iCloudManager.shared.getDocumentsURL()
        for piece in LibraryFiles.expired(pieces) {
            LibraryFiles.remove(id: piece.id, collection: .pieces, root: root)
        }
        let normalized = LibraryFiles.keepingLive(sorted(pieces))
        try LibraryFiles.write(normalized, collection: .pieces, root: root)
        cache(normalized)
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
