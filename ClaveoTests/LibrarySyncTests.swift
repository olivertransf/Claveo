import XCTest
@testable import Claveo

final class LibrarySyncTests: XCTestCase {
    func testLegacyRecordingJSONMigratesIntoSidecars() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let recording = Recording(fileName: "take.m4a", duration: 3, name: "Take")
        let legacy = try JSONEncoder().encode([recording])
        try legacy.write(to: root.appendingPathComponent("recordings.json"))

        let imported = LibraryFiles.readLegacy(Recording.self, fileName: "recordings.json", roots: [root])
        try LibraryFiles.write(imported, collection: .recordings, root: root)

        let sidecars = LibraryFiles.read(Recording.self, collection: .recordings, roots: [root])
        XCTAssertEqual(sidecars.map(\.id), [recording.id])
        XCTAssertEqual(sidecars.first?.name, "Take")
    }

    func testNewerSidecarWinsAndTombstoneWins() {
        let id = UUID()
        let older = Recording(id: id, fileName: "a.m4a", duration: 1, name: "Old", lastModified: Date(timeIntervalSince1970: 10))
        var newer = older
        newer.name = "New"
        newer.lastModified = Date(timeIntervalSince1970: 20)
        var tombstone = newer
        tombstone.isDeleted = true
        tombstone.lastModified = Date(timeIntervalSince1970: 30)

        let merged = AudioRecorder.mergeRecordings([older, newer], with: [tombstone])
        XCTAssertEqual(merged.count, 1)
        XCTAssertTrue(merged[0].isDeleted)
        XCTAssertEqual(merged[0].name, "New")
    }

    func testPieceSoftDeleteBeatsOlderLiveCopy() {
        let id = UUID()
        let live = Piece(id: id, name: "Etude", lastModified: Date(timeIntervalSince1970: 10))
        let deleted = Piece(id: id, name: "Etude", lastModified: Date(timeIntervalSince1970: 20), isDeleted: true)
        let merged = PieceService.merge([live], with: [deleted])
        XCTAssertEqual(merged.count, 1)
        XCTAssertTrue(merged[0].isDeleted)
    }

    func testTombstoneGCCutoff() {
        let stale = Recording(
            fileName: "old.m4a",
            duration: 1,
            lastModified: Date().addingTimeInterval(-(LibraryFiles.tombstoneRetention + 60)),
            isDeleted: true
        )
        let fresh = Recording(
            fileName: "new.m4a",
            duration: 1,
            lastModified: Date(),
            isDeleted: true
        )
        let live = Recording(fileName: "live.m4a", duration: 1)
        let kept = LibraryFiles.keepingLive([stale, fresh, live])
        XCTAssertEqual(Set(kept.map(\.fileName)), Set(["new.m4a", "live.m4a"]))
    }

    func testExpiredTombstoneRemovesOrphanAudio() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let audioURL = root.appendingPathComponent("gone.wav")
        try Data("audio".utf8).write(to: audioURL)
        let recording = Recording(
            fileName: "gone.wav",
            duration: 1,
            lastModified: Date().addingTimeInterval(-(LibraryFiles.tombstoneRetention + 60)),
            isDeleted: true
        )
        try LibraryFiles.write([recording], collection: .recordings, root: root)
        try await LibraryStore.shared.replace(
            payloads: [],
            removingIDs: [recording.id],
            audioFileNames: [recording.fileName],
            collection: .recordings,
            root: root
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
        XCTAssertTrue(LibraryFiles.read(Recording.self, collection: .recordings, roots: [root]).isEmpty)
    }

    func testConflictWinnerIsNewestModification() {
        let id = UUID()
        let older = Piece(id: id, name: "A", lastModified: Date(timeIntervalSince1970: 5))
        let newer = Piece(id: id, name: "B", lastModified: Date(timeIntervalSince1970: 9))
        XCTAssertEqual(LibraryFiles.newest([older, newer])?.name, "B")
        XCTAssertEqual(LibraryFiles.newest([newer, older])?.name, "B")
    }
}
