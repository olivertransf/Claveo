//
//  RecordingLiveActivityManager.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import ActivityKit
import Foundation

@MainActor
final class RecordingLiveActivityManager {
    static let shared = RecordingLiveActivityManager()

    private var activity: Activity<RecordingActivityAttributes>?

    private init() {}

    func startRecordingActivity(startedAt: Date, title: String = "Recording") {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if activity != nil {
            endRecordingActivity(finalDuration: 0, dismissalPolicy: .immediate)
        }

        let attributes = RecordingActivityAttributes(title: title, startedAt: startedAt)
        let state = RecordingActivityAttributes.ContentState(isRecording: true, finalDuration: nil)

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(
                    state: state,
                    staleDate: startedAt.addingTimeInterval(12 * 60 * 60),
                    relevanceScore: 100
                ),
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("Failed to start recording Live Activity: \(error)")
            #endif
        }
    }

    func endRecordingActivity(finalDuration: TimeInterval, dismissalPolicy: ActivityUIDismissalPolicy = .default) {
        guard let activity else { return }
        self.activity = nil

        let state = RecordingActivityAttributes.ContentState(
            isRecording: false,
            finalDuration: finalDuration
        )

        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: dismissalPolicy
            )
        }
    }
}
