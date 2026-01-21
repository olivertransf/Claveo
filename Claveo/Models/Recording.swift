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

struct Recording: Identifiable, Codable {
    var id: UUID
    let fileName: String
    var createdAt: Date
    var duration: TimeInterval
    
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
        case id, fileName, createdAt, duration, name, tags, piece, measureStart, measureEnd, notes, originalFileName, originalDuration
    }
    
    init(id: UUID = UUID(), fileName: String, createdAt: Date = Date(), duration: TimeInterval, name: String = "", tags: [String] = [], piece: String? = nil, measureStart: Int? = nil, measureEnd: Int? = nil, notes: String = "", originalFileName: String? = nil, originalDuration: TimeInterval? = nil) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.duration = duration
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
        name.isEmpty ? "Recording \(formattedDate)" : name
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
            return "Yesterday, \(formatter.string(from: createdAt))"
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
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(createdAt) ?? false {
            // Show abbreviated day name for this week
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: createdAt)
        } else {
            // Show short date for older recordings
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
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
            return "mm. \(start)-\(end)"
        }
        return "mm. \(start)"
    }
    
    var fileURL: URL {
        return iCloudManager.shared.getDocumentsURL().appendingPathComponent(fileName)
    }
    
    var originalFileURL: URL? {
        guard let originalFileName = originalFileName else { return nil }
        return iCloudManager.shared.getDocumentsURL().appendingPathComponent(originalFileName)
    }
    
    var hasTrimHistory: Bool {
        return originalFileName != nil && originalDuration != nil
    }
    
    func shareableFileURL() throws -> URL {
        let originalURL = fileURL
        let fileExtension = originalURL.pathExtension
        
        let sanitizedName = displayName
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
        
        let shareableFileName = sanitizedName.isEmpty ? "Recording" : sanitizedName
        let tempFileName = "\(shareableFileName).\(fileExtension)"
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(tempFileName)
        
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
        }
        
        try FileManager.default.copyItem(at: originalURL, to: tempURL)
        
        return tempURL
    }
}

struct RecordingFileTransferable: Transferable {
    let recording: Recording
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: UTType.audio) { transferable in
            let shareableURL = try transferable.recording.shareableFileURL()
            return SentTransferredFile(shareableURL)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(received.file.lastPathComponent)
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            let placeholderRecording = Recording(
                fileName: tempURL.lastPathComponent,
                createdAt: Date(),
                duration: 0
            )
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
}

