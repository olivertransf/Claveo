//
//  RecordingActivityWidget.swift
//  ClaveoRecordingActivityWidget
//
//  Copyright (c) 2025 Oliver Tran

import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

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

struct RecordingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            RecordingActivityLockScreenView(context: context)
                .activityBackgroundTint(Color(.secondarySystemBackground))
                .activitySystemActionForegroundColor(.red)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Recording")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    RecordingElapsedTimeView(context: context)
                        .font(.headline.monospacedDigit())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text("Audio capture in progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            } compactTrailing: {
                RecordingElapsedTimeView(context: context)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 46)
            } minimal: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            }
            .keylineTint(.red)
        }
    }
}

private struct RecordingActivityLockScreenView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.16))
                Image(systemName: "mic.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("Recording")
                    .font(.headline)

                Text(context.attributes.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            RecordingElapsedTimeView(context: context)
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
}

private struct RecordingElapsedTimeView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        if context.state.isRecording {
            if let paused = context.state.finalDuration, context.state.timerAnchor == nil {
                Text(formatDuration(paused))
                    .monospacedDigit()
            } else {
                let anchor = context.state.timerAnchor ?? context.attributes.startedAt
                Text(timerInterval: anchor...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
            }
        } else {
            Text(formatDuration(context.state.finalDuration ?? 0))
                .monospacedDigit()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@main
struct ClaveoRecordingActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecordingActivityWidget()
    }
}
