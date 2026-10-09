//
//  RecordingPlayerSurface.swift
//  Claveo
//
//  Shared waveform, times, and transport for list and iPad detail.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct RecordingPlayerSurface: View {
    @EnvironmentObject var themeManager: ThemeManager
    let recording: Recording
    let isPlaying: Bool
    let currentTime: TimeInterval?
    let duration: TimeInterval
    let playbackRate: Float
    var waveformHeight: CGFloat = 50
    var showsDeleteInTransport: Bool = true
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSpeedChange: (Float) -> Void
    let onSkipBackward: () -> Void
    let onSkipForward: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var isDragging = false
    @State private var dragValue: TimeInterval = 0
    @State private var anchorTime: TimeInterval = 0
    @State private var anchorDate = Date()
    @State private var seekTask: Task<Void, Never>?
    @State private var seekDelayTask: Task<Void, Never>?

    private func playbackTime(at date: Date) -> TimeInterval {
        if isDragging { return dragValue }
        guard isPlaying else { return anchorTime }
        let elapsed = date.timeIntervalSince(anchorDate)
        return min(max(duration, 0), max(0, anchorTime + elapsed * Double(playbackRate)))
    }

    private func resetAnchor(to time: TimeInterval) {
        anchorTime = time
        anchorDate = Date()
        dragValue = time
    }

    private let transportHitSize: CGFloat = 44
    private let playButtonSize: CGFloat = 52

    private var speedLabel: String {
        if playbackRate.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f×", playbackRate)
        }
        return String(format: "%g×", playbackRate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying || isDragging)) { context in
                let time = playbackTime(at: context.date)
                VStack(alignment: .leading, spacing: 10) {
                    waveformScrubber(at: time)
                        .frame(maxWidth: .infinity)
                    timelineLabels(time: time)
                }
            }

            playerControls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: currentTime) { _, newValue in
            handleCurrentTimeChange(newValue)
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                resetAnchor(to: currentTime ?? anchorTime)
            } else if let currentTime {
                resetAnchor(to: currentTime)
            }
        }
        .onAppear {
            resetAnchor(to: currentTime ?? 0)
        }
    }

    private func waveformScrubber(at time: TimeInterval) -> some View {
        Group {
            if recording.isLocallyAvailable {
                WaveformView(
                    recording: recording,
                    currentTime: time,
                    duration: duration,
                    height: waveformHeight,
                    onSeek: { time in
                        dragValue = time
                        isDragging = true

                        seekTask?.cancel()
                        seekTask = Task {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            if !Task.isCancelled {
                                onSeek(time)
                            }
                        }

                        seekDelayTask?.cancel()
                        seekDelayTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            if !Task.isCancelled {
                                isDragging = false
                                resetAnchor(to: dragValue)
                            }
                        }
                    }
                )
                .frame(maxWidth: .infinity, minHeight: waveformHeight, maxHeight: waveformHeight)
            } else {
                Slider(
                    value: playbackPositionBinding,
                    in: 0...max(duration, 0.1)
                )
                .tint(themeManager.accentColor)
                .frame(height: 32)
            }
        }
        .accessibilityLabel(String(localized: "Playback position"))
        .accessibilityValue(String(localized: "\(formatTime(time)) of \(formatTime(duration))"))
    }

    private var playbackPositionBinding: Binding<TimeInterval> {
        Binding(
            get: {
                isDragging ? dragValue : anchorTime
            },
            set: { newValue in
                dragValue = newValue
                if !isDragging {
                    isDragging = true
                }

                seekTask?.cancel()
                seekTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if !Task.isCancelled {
                        onSeek(newValue)
                    }
                }
            }
        )
    }

    private func handleCurrentTimeChange(_ newValue: TimeInterval?) {
        guard let newValue else { return }

        if isDragging {
            if abs(newValue - dragValue) < 0.3 {
                isDragging = false
                resetAnchor(to: newValue)
            }
        } else {
            resetAnchor(to: newValue)
        }
    }

    private func timelineLabels(time: TimeInterval) -> some View {
        HStack {
            Text(formatTime(time))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())

            Spacer()

            let remaining = max(0, duration - time)
            Text("-\(formatTime(remaining))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private var playerControls: some View {
        HStack(spacing: 0) {
            speedMenu
                .frame(width: transportHitSize, alignment: .leading)

            Spacer(minLength: 8)

            HStack(spacing: 28) {
                transportIconButton(
                    systemImage: "gobackward.15",
                    font: .title2,
                    accessibilityLabel: String(localized: "Back 15 seconds"),
                    action: onSkipBackward
                )

                Button {
                    HapticFeedback.lightImpact()
                    onPlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(.primary)
                        .offset(x: isPlaying ? 0 : 2)
                        .symbolEffect(.replace, value: isPlaying)
                        .frame(width: playButtonSize, height: playButtonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isPlaying ? String(localized: "Pause") : String(localized: "Play"))

                transportIconButton(
                    systemImage: "goforward.15",
                    font: .title2,
                    accessibilityLabel: String(localized: "Forward 15 seconds"),
                    action: onSkipForward
                )
            }

            Spacer(minLength: 8)

            if showsDeleteInTransport, let onDelete {
                transportIconButton(
                    systemImage: "trash",
                    font: .body.weight(.medium),
                    accessibilityLabel: String(localized: "Delete"),
                    foregroundColor: themeManager.accentColor,
                    action: onDelete
                )
                .frame(width: transportHitSize, alignment: .trailing)
            } else {
                Color.clear
                    .frame(width: transportHitSize, height: transportHitSize)
            }
        }
        .padding(.top, 6)
    }

    private var speedMenu: some View {
        Menu {
            speedMenuButton(rate: 0.75, label: "0.75×")
            speedMenuButton(rate: 1.0, label: "1×")
            speedMenuButton(rate: 1.25, label: "1.25×")
            speedMenuButton(rate: 1.5, label: "1.5×")
        } label: {
            Text(speedLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.accentColor)
                .frame(width: transportHitSize, height: transportHitSize, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(String(localized: "Playback Speed"))
        .accessibilityValue(speedLabel)
    }

    private func transportIconButton(
        systemImage: String,
        font: Font,
        accessibilityLabel: String,
        foregroundColor: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticFeedback.lightImpact()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(font)
                .foregroundStyle(foregroundColor)
                .frame(width: transportHitSize, height: transportHitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }

    private func speedMenuButton(rate: Float, label: String) -> some View {
        Button {
            onSpeedChange(rate)
        } label: {
            if abs(playbackRate - rate) < 0.01 {
                Label(label, systemImage: "checkmark")
            } else {
                Text(label)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
