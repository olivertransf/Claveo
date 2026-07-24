//
//  RecordingActivityAttributes.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import ActivityKit
import Foundation

struct RecordingActivityAttributes: ActivityAttributes {
    static let schemaVersion = 2

    struct ContentState: Codable, Hashable {
        var isRecording: Bool
        var finalDuration: TimeInterval?
        /// When set, the Live Activity timer counts from this date (capture-time aligned after pauses).
        var timerAnchor: Date?
    }

    var title: String
    var startedAt: Date
}
