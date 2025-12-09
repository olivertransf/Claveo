//
//  RecordingListPreview.swift
//  Claveo
//
//  Preview-only helpers extracted from RecordingListView.
//

import SwiftUI

#Preview("Empty State") {
    RecordingListView()
        .environmentObject(ThemeManager.shared)
}

#Preview("With Recordings") {
    // Add sample recordings
    let sampleRecordings = [
        Recording(
            fileName: "recording1.m4a",
            createdAt: Date(),
            duration: 125.5,
            name: "Run through",
            tags: ["Practice"]
        ),
        Recording(
            fileName: "recording2.m4a",
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            duration: 3.2,
            name: "New Recording 72",
            tags: []
        ),
        Recording(
            fileName: "recording3.m4a",
            createdAt: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            duration: 45.8,
            name: "891 26th Ave 11",
            tags: ["Lesson"],
            piece: "Grieg Concerto"
        ),
        Recording(
            fileName: "recording4.m4a",
            createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            duration: 90.0,
            name: "Grieg whole section",
            tags: ["Practice"]
        )
    ]

    PreviewRecordingListView(recordings: sampleRecordings)
        .environmentObject(ThemeManager.shared)
}

#Preview("Active Recording") {
    PreviewRecordingListView(isRecording: true, recordingTime: 45.3)
        .environmentObject(ThemeManager.shared)
}


