import Foundation
import XCTest
@testable import Claveo

final class RecordingReliabilityTests: XCTestCase {
    func testLegacyRecordingDecodesWithoutStorageAndUsesCreatedDateAsModificationDate() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let legacy: [String: Any] = [
            "id": id.uuidString,
            "fileName": "legacy.m4a",
            "createdAt": createdAt.timeIntervalSinceReferenceDate,
            "duration": 12.0
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)

        let recording = try JSONDecoder().decode(Recording.self, from: data)

        XCTAssertNil(recording.storageLocation)
        XCTAssertFalse(recording.keepDownloaded)
        XCTAssertEqual(recording.lastModified, createdAt)
    }

    func testRecordingStorageLocationRoundTrips() throws {
        let recording = Recording(
            fileName: "pinned.m4a",
            createdAt: Date(timeIntervalSince1970: 100),
            duration: 2,
            storageLocation: .device
        )

        let decoded = try JSONDecoder().decode(
            Recording.self,
            from: JSONEncoder().encode(recording)
        )

        XCTAssertEqual(decoded.storageLocation, .device)
        XCTAssertFalse(decoded.keepDownloaded)
    }

    func testKeepDownloadedRoundTrips() throws {
        let recording = Recording(
            fileName: "pinned.m4a",
            createdAt: Date(timeIntervalSince1970: 100),
            duration: 2,
            storageLocation: .iCloud,
            keepDownloaded: true
        )

        let decoded = try JSONDecoder().decode(
            Recording.self,
            from: JSONEncoder().encode(recording)
        )

        XCTAssertTrue(decoded.keepDownloaded)
        XCTAssertEqual(decoded.storageLocation, .iCloud)
    }

    func testShareableFileUsesRecordingDisplayName() throws {
        let documents = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: documents) }

        let source = documents.appendingPathComponent("uuid-on-disk.m4a")
        try Data("audio".utf8).write(to: source)

        let recording = Recording(
            fileName: "uuid-on-disk.m4a",
            createdAt: Date(timeIntervalSince1970: 100),
            duration: 2,
            name: "Etude / Op. 10"
        )
        let url = try recording.shareableFileURL(documentsBase: documents)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        XCTAssertEqual(url.lastPathComponent, "Etude - Op. 10.m4a")
    }

    @MainActor
    func testNewestModifiedMergeIsOrderIndependent() {
        let id = UUID()
        let old = Recording(
            id: id,
            fileName: "same.m4a",
            createdAt: Date(timeIntervalSince1970: 10),
            duration: 1,
            name: "Old",
            lastModified: Date(timeIntervalSince1970: 20)
        )
        let newest = Recording(
            id: id,
            fileName: "same.m4a",
            createdAt: Date(timeIntervalSince1970: 10),
            duration: 1,
            name: "Newest",
            lastModified: Date(timeIntervalSince1970: 30)
        )

        let forward = AudioRecorder.mergeRecordings([old], with: [newest])
        let reverse = AudioRecorder.mergeRecordings([newest], with: [old])

        XCTAssertEqual(forward.first?.name, "Newest")
        XCTAssertEqual(reverse.first?.name, "Newest")
    }

    @MainActor
    func testEqualModificationDateMergeIsDeterministic() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 20)
        let alpha = Recording(
            id: id,
            fileName: "same.m4a",
            createdAt: date,
            duration: 1,
            name: "Alpha",
            lastModified: date
        )
        let beta = Recording(
            id: id,
            fileName: "same.m4a",
            createdAt: date,
            duration: 1,
            name: "Beta",
            lastModified: date
        )

        XCTAssertEqual(
            AudioRecorder.mergeRecordings([alpha], with: [beta]),
            AudioRecorder.mergeRecordings([beta], with: [alpha])
        )
    }

    @MainActor
    func testNewerDeletionTombstonePreventsReloadResurrection() {
        let id = UUID()
        let live = Recording(
            id: id,
            fileName: "deleted.m4a",
            createdAt: Date(timeIntervalSince1970: 10),
            duration: 1,
            lastModified: Date(timeIntervalSince1970: 20)
        )
        let tombstone = Recording(
            id: id,
            fileName: "deleted.m4a",
            createdAt: Date(timeIntervalSince1970: 10),
            duration: 1,
            lastModified: Date(timeIntervalSince1970: 30),
            isDeleted: true
        )

        let merged = AudioRecorder.mergeRecordings([live], with: [tombstone])

        XCTAssertEqual(merged.count, 1)
        XCTAssertTrue(merged[0].isDeleted)
    }

    func testPinnedRootLookupFallsBackWithoutLosingTheFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let device = root.appendingPathComponent("device", isDirectory: true)
        let cloud = root.appendingPathComponent("cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: device, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let cloudFile = cloud.appendingPathComponent("recording.m4a")
        try Data("audio".utf8).write(to: cloudFile)

        let found = iCloudManager.existingFileURL(
            fileName: "recording.m4a",
            pinnedLocation: .device,
            roots: [.device: device, .iCloud: cloud]
        )

        XCTAssertEqual(found, cloudFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cloudFile.path))
    }

    func testSafeMigrationNeverOverwritesOrDeletesSource() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.m4a")
        let destination = root.appendingPathComponent("destination.m4a")
        try Data("source".utf8).write(to: source)
        try Data("destination".utf8).write(to: destination)

        let result = try iCloudManager.copyFileIfDestinationMissing(
            from: source,
            to: destination
        )

        XCTAssertFalse(result)
        XCTAssertEqual(try Data(contentsOf: source), Data("source".utf8))
        XCTAssertEqual(try Data(contentsOf: destination), Data("destination".utf8))
    }

    func testAtomicReplacePreservesDestinationOnFailure() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let original = root.appendingPathComponent("recording.m4a")
        let trimmed = root.appendingPathComponent("trimmed.m4a")
        try Data("original-audio".utf8).write(to: original)
        try Data("trimmed-audio".utf8).write(to: trimmed)

        _ = try FileManager.default.replaceItemAt(original, withItemAt: trimmed)
        XCTAssertEqual(try Data(contentsOf: original), Data("trimmed-audio".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: trimmed.path))
    }

    func testTrimBackupCleanupRemovesBackup() throws {
        let backup = FileManager.default.temporaryDirectory
            .appendingPathComponent("original_\(UUID().uuidString).m4a")
        try Data("backup".utf8).write(to: backup)

        try RecordingTrimmer.deleteBackup(at: backup)

        XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path))
    }

    @MainActor
    func testRemovingRecordingScrubsDanglingPracticeLinks() {
        let removedID = UUID()
        let retainedID = UUID()
        let entry = PracticeEntry(
            duration: 10,
            linkedRecordingIds: [removedID, retainedID],
            lastModified: Date(timeIntervalSince1970: 10)
        )

        let scrubbed = PracticeService.removingRecordingID(removedID, from: [entry])

        XCTAssertEqual(scrubbed[0].linkedRecordingIds, [retainedID])
        XCTAssertGreaterThan(scrubbed[0].lastModified, entry.lastModified)
    }

    @MainActor
    func testSeekBeforePlayRemembersPosition() {
        let player = AudioPlayer()
        let recording = Recording(
            fileName: "missing-for-seek-test.m4a",
            createdAt: Date(timeIntervalSince1970: 1),
            duration: 40
        )

        player.seek(recording, to: 12.5)

        XCTAssertEqual(player.currentTime, 12.5, accuracy: 0.001)
        XCTAssertFalse(player.isPlaying)
    }
}
