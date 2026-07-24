import XCTest
@testable import Claveo

final class DataIntegrityTests: XCTestCase {
    func testLegacyPieceDecodingUsesCreationDateAsModificationDate() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let data = try JSONSerialization.data(withJSONObject: [
            "id": id.uuidString,
            "name": "Prelude",
            "createdAt": ISO8601DateFormatter().string(from: createdAt)
        ])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let piece = try decoder.decode(Piece.self, from: data)

        XCTAssertEqual(piece.lastModified, createdAt)
    }

    func testPieceMergeKeepsNewestVersionAndIndependentPieces() {
        let sharedID = UUID()
        let old = Piece(
            id: sharedID,
            name: "Old title",
            createdAt: Date(timeIntervalSince1970: 100),
            lastModified: Date(timeIntervalSince1970: 200)
        )
        let new = Piece(
            id: sharedID,
            name: "New title",
            createdAt: Date(timeIntervalSince1970: 100),
            lastModified: Date(timeIntervalSince1970: 300)
        )
        let independent = Piece(name: "Independent")

        let merged = PieceService.merge([old, independent], with: [new])

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first(where: { $0.id == sharedID })?.name, "New title")
        XCTAssertTrue(merged.contains(where: { $0.id == independent.id }))
    }

    func testSettingsResolutionUsesNewestSnapshot() {
        var local = AppSettings()
        local.defaultPracticeTime = 20
        var remote = AppSettings()
        remote.defaultPracticeTime = 45

        let resolved = SettingsManager.resolve(
            local: local,
            localModified: Date(timeIntervalSince1970: 200),
            remote: remote,
            remoteModified: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(resolved.defaultPracticeTime, 20)
    }

    func testSettingsResolveUnionsFavoriteTempos() {
        var local = AppSettings()
        local.favoriteTempos = [60, 120]
        local.defaultPracticeTime = 20
        var remote = AppSettings()
        remote.favoriteTempos = [90]
        remote.defaultPracticeTime = 45

        let remoteWins = SettingsManager.resolve(
            local: local,
            localModified: Date(timeIntervalSince1970: 100),
            remote: remote,
            remoteModified: Date(timeIntervalSince1970: 200)
        )
        XCTAssertEqual(remoteWins.defaultPracticeTime, 45)
        XCTAssertEqual(remoteWins.favoriteTempos, [60, 90, 120])

        var emptyRemote = AppSettings()
        emptyRemote.favoriteTempos = []
        emptyRemote.defaultPracticeTime = 45
        let preserved = SettingsManager.resolve(
            local: local,
            localModified: Date(timeIntervalSince1970: 100),
            remote: emptyRemote,
            remoteModified: Date(timeIntervalSince1970: 200)
        )
        XCTAssertEqual(preserved.favoriteTempos, [60, 120])
    }

    func testMissingTabSemanticsVersionDecodesAsLegacy() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "a4ReferenceFrequency": 440.0,
            "defaultPracticeTime": 30
        ])
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.tabSemanticsVersion, 1)
    }

    func testTrimViewUsesAtomicReplace() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Claveo/Views/Recording/RecordingTrimView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("replaceItemAt("))
        XCTAssertFalse(source.contains("removeItem(at: recording.fileURL)"))
    }

    func testPracticeEntryRejectsMissingID() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "date": Date().timeIntervalSinceReferenceDate,
            "duration": 15
        ])
        XCTAssertThrowsError(try JSONDecoder().decode(PracticeEntry.self, from: data))
    }

    func testLiveActivityAttributeSchemasStayInSync() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: root.appendingPathComponent("Claveo/LiveActivities/RecordingActivityAttributes.swift"),
            encoding: .utf8
        )
        let widgetSource = try String(
            contentsOf: root.appendingPathComponent("ClaveoRecordingActivityWidget/RecordingActivityWidget.swift"),
            encoding: .utf8
        )

        XCTAssertEqual(
            try activityAttributeDeclaration(in: appSource),
            try activityAttributeDeclaration(in: widgetSource)
        )
    }

    func testMusicScannerContainsNoCrashOnlyImageCreation() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Claveo/Services/OMR/MusicScannerModel.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("fatalError("))
        XCTAssertFalse(source.contains("context.makeImage()!"))
    }

    private func activityAttributeDeclaration(in source: String) throws -> String {
        let marker = "struct RecordingActivityAttributes: ActivityAttributes"
        guard let markerRange = source.range(of: marker),
              let openingBrace = source[markerRange.lowerBound...].firstIndex(of: "{") else {
            throw NSError(domain: "DataIntegrityTests", code: 1)
        }

        var depth = 0
        var closingBrace: String.Index?
        for index in source.indices[openingBrace...] {
            switch source[index] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    closingBrace = index
                    break
                }
            default:
                break
            }
        }
        guard let closingBrace else {
            throw NSError(domain: "DataIntegrityTests", code: 2)
        }

        return source[markerRange.lowerBound...closingBrace]
            .filter { !$0.isWhitespace }
    }
}
