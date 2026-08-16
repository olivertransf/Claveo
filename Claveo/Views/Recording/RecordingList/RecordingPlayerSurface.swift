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
    @State private var displayTime: TimeInterval = 0
    @State private var seekTask: Task<Void, Never>?
    @State private var lastUpdateTime: Date?
    @State private var lastKnownTime: TimeInterval = 0
    @State private var smoothUpdateTimer: Timer?
    @State private var seekDelayTask: Task<Void, Never>?

    private var currentDisplayTime: TimeInterval {
        isDragging ? dragValue : displayTime
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
            waveformScrubber
                .frame(maxWidth: .infinity)

            timelineLabels

            playerControls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var waveformScrubber: some View {
        Group {
            if recording.isLocallyAvailable {
                WaveformView(
                    recording: recording,
                    currentTime: currentDisplayTime,
                    duration: duration,
                    height: waveformHeight,
                    onSeek: { time in
                        dragValue = time
                        displayTime = time
                        lastKnownTime = time
                        lastUpdateTime = Date()
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
                                if isPlaying {
                                    startSmoothTimer()
                                }
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
        .accessibilityValue(String(localized: "\(formatTime(currentDisplayTime)) of \(formatTime(duration))"))
        .onChange(of: currentTime) { _, newValue in
            handleCurrentTimeChange(newValue)
        }
        .onChange(of: isPlaying) { _, playing in
            if playing, let current = currentTime {
                lastKnownTime = current
                lastUpdateTime = Date()
                startSmoothTimer()
            } else {
                stopSmoothTimer()
            }
        }
        .onAppear {
            let initial = currentTime ?? 0
            displayTime = initial
            dragValue = initial
            lastKnownTime = initial
            lastUpdateTime = Date()
            if isPlaying {
                startSmoothTimer()
            }
        }
        .onDisappear {
            stopSmoothTimer()
        }
    }

    private var playbackPositionBinding: Binding<TimeInterval> {
        Binding(
            get: {
                if isDragging {
                    return dragValue
                }
                return displayTime
            },
            set: { newValue in
                dragValue = newValue
                displayTime = newValue
                lastKnownTime = newValue
                lastUpdateTime = Date()
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
                displayTime = newValue
                lastKnownTime = newValue
                lastUpdateTime = Date()

                seekDelayTask?.cancel()
                seekDelayTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if !Task.isCancelled && isPlaying {
                        startSmoothTimer()
                    }
                }
            }
        } else {
            displayTime = newValue
            dragValue = newValue
            lastKnownTime = newValue
            lastUpdateTime = Date()
        }
    }

    private var timelineLabels: some View {
        HStack {
            Text(formatTime(currentDisplayTime))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            let remaining = max(0, duration - currentDisplayTime)
            Text("-\(formatTime(remaining))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
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

    private func startSmoothTimer() {
        stopSmoothTimer()
        guard isPlaying, !isDragging else { return }
        let newTimer = Timer(timeInterval: 0.1, repeats: true) { timer in
            guard self.isPlaying, !self.isDragging, let lastUpdate = self.lastUpdateTime else {
                timer.invalidate()
                self.smoothUpdateTimer = nil
                return
            }
            let elapsed = Date().timeIntervalSince(lastUpdate)
            let interpolated = self.lastKnownTime + (elapsed * Double(self.playbackRate))
            self.displayTime = min(interpolated, self.duration)
        }
        RunLoop.main.add(newTimer, forMode: .common)
        smoothUpdateTimer = newTimer
    }

    private func stopSmoothTimer() {
        smoothUpdateTimer?.invalidate()
        smoothUpdateTimer = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
