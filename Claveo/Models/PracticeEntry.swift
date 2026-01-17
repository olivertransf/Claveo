//
//  PracticeEntry.swift
//  Claveo
//
//  Created by Oliver Tran on 12/22/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

struct PracticeEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var duration: Int // in minutes
    var notes: String? // optional journal entry
    var linkedRecordingIds: [UUID] = [] // IDs of linked recordings
    var rating: Int? // 1-5 stars, optional
    var lastModified: Date = Date()
    var isDeleted: Bool = false

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
