//
//  RecordingActivityAttributes.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import ActivityKit
import Foundation

struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isRecording: Bool
        var finalDuration: TimeInterval?
    }

    var title: String
    var startedAt: Date
}
