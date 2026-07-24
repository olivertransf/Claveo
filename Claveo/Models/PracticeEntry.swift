//
//  PracticeEntry.swift
//  Claveo
//
//  Created by Oliver Tran on 12/22/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

struct PracticeEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var duration: Int // in minutes
    var notes: String? // optional journal entry
    var linkedRecordingIds: [UUID] = [] // IDs of linked recordings
    var rating: Int? // 1-5 stars, optional
    var lastModified: Date = Date()
    var isDeleted: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, date, duration, notes, linkedRecordingIds, rating, lastModified, isDeleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let decodedID = try c.decodeIfPresent(UUID.self, forKey: .id) else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: c,
                debugDescription: "PracticeEntry requires a stable id"
            )
        }
        id = decodedID
        date = try c.decode(Date.self, forKey: .date)
        duration = try c.decode(Int.self, forKey: .duration)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        linkedRecordingIds = try c.decodeIfPresent([UUID].self, forKey: .linkedRecordingIds) ?? []
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        lastModified = try c.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }

    // Computed properties
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var formattedDuration: String {
        if duration < 60 {
            return "\(duration) min"
        } else {
            let hours = duration / 60
            let minutes = duration % 60
            if minutes == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(minutes) min"
            }
        }
    }

    var ratingStars: String {
        guard let rating = rating else { return "" }
        return String(repeating: "★", count: rating)
    }

    // Initialize with current date
    init(date: Date = Date(), duration: Int, notes: String? = nil, linkedRecordingIds: [UUID] = [], rating: Int? = nil, lastModified: Date = Date(), isDeleted: Bool = false) {
        self.date = date
        self.duration = duration
        self.notes = notes
        self.linkedRecordingIds = linkedRecordingIds
        self.rating = rating
        self.lastModified = lastModified
        self.isDeleted = isDeleted
    }
}
