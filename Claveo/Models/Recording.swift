//
//  Recording.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation
import UniformTypeIdentifiers
import SwiftUI

enum RecordingStorageLocation: String, Codable, Sendable {
    case device
    case iCloud
}

struct Recording: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    let fileName: String
    var createdAt: Date
    var duration: TimeInterval
    var lastModified: Date
    var storageLocation: RecordingStorageLocation?
    var isDeleted: Bool
    var keepDownloaded: Bool
    
    // Metadata fields
    var name: String
    var tags: [String]
    var piece: String?
    var measureStart: Int?
    var measureEnd: Int?
    var notes: String // Practice session notes/comments
    
    // Trim history (non-destructive editing)
    var originalFileName: String? // Backup of original file before trimming
    var originalDuration: TimeInterval? // Original duration before trimming
    
    enum CodingKeys: String, CodingKey {
        case id, fileName, createdAt, duration, lastModified, storageLocation, isDeleted, keepDownloaded, name, tags, piece, measureStart, measureEnd, notes, originalFileName, originalDuration
    }
    
    init(id: UUID = UUID(), fileName: String, createdAt: Date = Date(), duration: TimeInterval, name: String = "", tags: [String] = [], piece: String? = nil, measureStart: Int? = nil, measureEnd: Int? = nil, notes: String = "", originalFileName: String? = nil, originalDuration: TimeInterval? = nil, lastModified: Date? = nil, storageLocation: RecordingStorageLocation? = nil, isDeleted: Bool = false, keepDownloaded: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.duration = duration
        self.lastModified = lastModified ?? createdAt
        self.storageLocation = storageLocation
        self.isDeleted = isDeleted
        self.keepDownloaded = keepDownloaded
        self.name = name
        self.tags = tags
        self.piece = piece
        self.measureStart = measureStart
        self.measureEnd = measureEnd
        self.notes = notes
        self.originalFileName = originalFileName
        self.originalDuration = originalDuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? createdAt
        storageLocation = try container.decodeIfPresent(RecordingStorageLocation.self, forKey: .storageLocation)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        keepDownloaded = try container.decodeIfPresent(Bool.self, forKey: .keepDownloaded) ?? false
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        piece = try container.decodeIfPresent(String.self, forKey: .piece)
        measureStart = try container.decodeIfPresent(Int.self, forKey: .measureStart)
        measureEnd = try container.decodeIfPresent(Int.self, forKey: .measureEnd)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? "" // Backward compatibility
        originalFileName = try container.decodeIfPresent(String.self, forKey: .originalFileName)
        originalDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .originalDuration)
    }
    
    var displayName: String {
        name.isEmpty ? String(localized: "Recording \(formattedDate)") : name
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var relativeDateString: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(createdAt) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: createdAt)
        } else if calendar.isDateInYesterday(createdAt) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return String(localized: "Yesterday, \(formatter.string(from: createdAt))")
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(createdAt) ?? false {
            // Show day name for this week
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: createdAt)
        } else {
            // Show full date for older recordings
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: createdAt)
        }
    }
    
    var shortDateString: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(createdAt) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: createdAt)
        } else if calendar.isDateInYesterday(createdAt) {
            return String(localized: "Yesterday")
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(createdAt) ?? false {
            // Show abbreviated day name for this week
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: createdAt)
        } else {
            // Show short date for older recordings
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("Md")
            return formatter.string(from: createdAt)
        }
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var measureRange: String? {
        guard let start = measureStart else { return nil }
        if let end = measureEnd, end != start {
            return String(localized: "mm. \(start)-\(end)")
        }
        return String(localized: "mm. \(start)")
    }

    /// Parses measure text from the detail editor. Returns nil for empty or invalid input.
    static func measureNumber(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    /// Applies parsed measure fields and normalizes end ≥ start when both are set.
    mutating func applyMeasureNumbers(startText: String, endText: String) {
        measureStart = Self.measureNumber(from: startText)
        measureEnd = Self.measureNumber(from: endText)

        if let start = measureStart, let end = measureEnd, end < start {
            measureEnd = start
        }
    }
    
    var fileURL: URL {
        iCloudManager.shared.fileURL(
            fileName: fileName,
            pinnedLocation: storageLocation
        )
    }
    
    var originalFileURL: URL? {
        guard let originalFileName = originalFileName else { return nil }
        return iCloudManager.shared.fileURL(
            fileName: originalFileName,
            pinnedLocation: storageLocation
        )
    }
    
    var hasTrimHistory: Bool {
        return originalFileName != nil && originalDuration != nil
    }
    
    nonisolated static func sanitizedExportFileName(_ rawName: String) -> String {
        let sanitizedName = rawName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "*", with: "-")
            .replacingOccurrences(of: "?", with: "-")
            .replacingOccurrences(of: "\"", with: "-")
            .replacingOccurrences(of: "<", with: "-")
            .replacingOccurrences(of: ">", with: "-")
            .replacingOccurrences(of: "|", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitizedName.isEmpty ? "Recording" : sanitizedName
    }

    nonisolated func shareableFileURL(documentsBase: URL) throws -> URL {
        let originalURL = documentsBase.appendingPathComponent(fileName)
        let fileExtension = originalURL.pathExtension
        let shareableFileName = Self.sanitizedExportFileName(displayName)
        let exportFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(id.uuidString)", isDirectory: true)
        if FileManager.default.fileExists(atPath: exportFolder.path) {
            try FileManager.default.removeItem(at: exportFolder)
        }
        try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
        let tempURL = exportFolder.appendingPathComponent(
            fileExtension.isEmpty ? shareableFileName : "\(shareableFileName).\(fileExtension)"
        )
        try FileManager.default.copyItem(at: originalURL, to: tempURL)
        return tempURL
    }

    @MainActor
    func shareableFileURL() throws -> URL {
        let sourceURL = fileURL
        return try shareableFileURL(documentsBase: sourceURL.deletingLastPathComponent())
    }

    var resolvedStorageLocation: RecordingStorageLocation {
        if let storageLocation { return storageLocation }
        if FileManager.default.isUbiquitousItem(at: fileURL) {
            return .iCloud
        }
        return iCloudManager.shared.storageLocation(containing: fileName, preferred: nil) ?? .device
    }

    var isStoredIniCloud: Bool {
        resolvedStorageLocation == .iCloud || FileManager.default.isUbiquitousItem(at: fileURL)
    }

    var isUbiquitousFileDownloaded: Bool {
        let values = try? fileURL.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ])
        guard values?.isUbiquitousItem == true else { return true }
        return values?.ubiquitousItemDownloadingStatus != .some(.notDownloaded)
    }

    var storageSystemImage: String {
        if isStoredIniCloud {
            return isUbiquitousFileDownloaded ? "icloud" : "icloud.and.arrow.down"
        }
        return "folder"
    }

    var storageAccessibilityLabel: String {
        if isStoredIniCloud {
            return isUbiquitousFileDownloaded
                ? String(localized: "Stored in iCloud")
                : String(localized: "Stored in iCloud, not downloaded")
        }
        return String(localized: "Stored on this device")
    }
}

struct RecordingFileTransferable: Transferable {
    let recording: Recording

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: UTType.audio) { transferable in
            let shareableURL = try await MainActor.run {
                try transferable.recording.shareableFileURL()
            }
            return SentTransferredFile(shareableURL)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(received.file.lastPathComponent)
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            let placeholderRecording = await MainActor.run {
                Recording(
                    fileName: tempURL.lastPathComponent,
                    createdAt: Date(),
                    duration: 0
                )
            }
            return RecordingFileTransferable(recording: placeholderRecording)
        }
    }
}

enum RecordingTag: String, CaseIterable {
    case practice = "Practice"
    case concert = "Concert"
    case rehearsal = "Rehearsal"
    case lesson = "Lesson"
    case audition = "Audition"
    case performance = "Performance"
    case warmup = "Warm-up"
    case other = "Other"

    var localizedName: String {
        switch self {
        case .practice: return String(localized: "Practice")
        case .concert: return String(localized: "Concert")
        case .rehearsal: return String(localized: "Rehearsal")
        case .lesson: return String(localized: "Lesson")
        case .audition: return String(localized: "Audition")
        case .performance: return String(localized: "Performance")
        case .warmup: return String(localized: "Warm-up")
        case .other: return String(localized: "Other")
        }
    }

    static func localizedName(for rawValue: String) -> String {
        RecordingTag(rawValue: rawValue)?.localizedName ?? rawValue
    }
}

