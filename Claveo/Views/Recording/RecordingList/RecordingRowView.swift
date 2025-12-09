//
//  RecordingRowView.swift
//  Claveo
//
//  Extracted from RecordingListView to keep that file smaller.
//

import SwiftUI

struct RecordingRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let recording: Recording
    let isExpanded: Bool
    let isPlaying: Bool
    let currentTime: TimeInterval?
    let duration: TimeInterval
    let playbackRate: Float
    let onExpand: () -> Void
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSpeedChange: (Float) -> Void
    let onSkipBackward: () -> Void
    let onSkipForward: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onExpand) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recording.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(recording.relativeDateString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if let piece = recording.piece {
                                Text("•")
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text(piece)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    Text(recording.formattedDuration)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(recording.displayName), \(recording.formattedDuration)")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")

            // Playback controls (shown when expanded)
            if isExpanded {
                VStack(spacing: 16) {
                    // Progress Bar
                    GeometryReader { geometry in
                        let availableWidth = geometry.size.width
                        ZStack(alignment: .leading) {
                            // Background
                            Capsule()
                                .fill(Color(.systemGray4))
                                .frame(height: 3)

                            // Progress
                            Capsule()
                                .fill(themeManager.accentColor)
                                .frame(width: availableWidth * CGFloat((currentTime ?? 0) / max(duration, 1)), height: 3)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let percentage = min(max(0, value.location.x / availableWidth), 1)
                                    let newTime = TimeInterval(percentage) * duration
                                    onSeek(newTime)
                                }
                        )
                    }
                    .frame(height: 3)

                    // Time (right under progress bar)
                    HStack {
                        Text(formatTime(currentTime ?? 0))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(isPlaying ? "-\(formatTime(max(0, duration - (currentTime ?? 0))))" : formatTime(duration))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    // Controls
                    HStack {
                        // Edit button
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit Recording")

                        Spacer()

                        // Skip Backward
                        Button(action: onSkipBackward) {
                            Image(systemName: "gobackward.15")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Skip Backward 15 Seconds")

                        Spacer()
                            .frame(width: 50)

                        // Play/Pause
                        Button(action: onPlayPause) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPlaying ? "Pause" : "Play")

                        Spacer()
                            .frame(width: 50)

                        // Skip Forward
                        Button(action: onSkipForward) {
                            Image(systemName: "goforward.15")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Skip Forward 15 Seconds")

                        Spacer()

                        // Delete button
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete Recording")
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Color.themeBackground)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


