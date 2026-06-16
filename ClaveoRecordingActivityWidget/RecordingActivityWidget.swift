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
    struct ContentState: Codable, Hashable {
        var isRecording: Bool
        var finalDuration: TimeInterval?
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
                    Label("Recording", systemImage: "waveform")
                        .font(.caption)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    RecordingElapsedTimeView(context: context)
                        .font(.headline.monospacedDigit())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.title)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "waveform")
                    .foregroundStyle(.red)
            } compactTrailing: {
                RecordingElapsedTimeView(context: context)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 46)
            } minimal: {
                Image(systemName: "waveform")
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
                Image(systemName: "waveform")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(context.state.isRecording ? "Recording" : "Saved")
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
            Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                .monospacedDigit()
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
