//
//  RecordingRowView.swift
//  Claveo
//
//  Extracted from RecordingListView to keep that file smaller.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct RecordingRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let recording: Recording
    @Binding var isExpanded: Bool
    let isPlaying: Bool
    let currentTime: TimeInterval?
    let duration: TimeInterval
    let playbackRate: Float
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSpeedChange: (Float) -> Void
    let onSkipBackward: () -> Void
    let onSkipForward: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTrim: () -> Void
    let onExport: () -> Void
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
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

    private let transportButtonSize: CGFloat = 44
    private let playButtonSize: CGFloat = 52

    private var rowSubtitle: String {
        var parts: [String] = [recording.relativeDateString]
        if let piece = recording.piece, !piece.isEmpty {
            parts.append(piece)
        }
        return parts.joined(separator: " · ")
    }
    
    @ViewBuilder
    private var rowSummaryLabel: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(recording.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? 2 : 1)

                Text(rowSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if isExpanded, !recording.tags.isEmpty {
                    Text(recording.tags.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(recording.formattedDuration)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isPlaying ? themeManager.accentColor : .secondary)
                    .monospacedDigit()

                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeManager.accentColor)
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isPlaying)
                }
            }
        }
        .padding(.vertical, isExpanded ? 4 : 6)
    }
    
    var body: some View {
        Group {
            if isSelectionMode {
                Button(action: { onToggleSelection?() }) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(isSelected ? themeManager.accentColor : Color.secondary)
                        rowSummaryLabel
                    }
                    .contentShape(Rectangle())
                }
            } else {
                VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
                    rowSummaryLabel
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticFeedback.lightImpact()
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isExpanded.toggle()
                            }
                        }

                    if isExpanded {
                        playerPanel
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .claveoListRowChrome(hideSeparator: isExpanded, showsBackground: false)
        .modifier(RecordingRowBackgroundModifier(
            isPlaying: isPlaying,
            isExpanded: isExpanded,
            fillColor: rowFillColor
        ))
    }

    private var rowFillColor: Color {
        if isPlaying {
            return themeManager.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1)
        }
        if isExpanded {
            return Color(.secondarySystemGroupedBackground)
        }
        return .clear
    }

    private var transportButtonFill: Color {
        if isExpanded || isPlaying {
            return colorScheme == .dark
                ? Color(.systemBackground).opacity(0.55)
                : Color(.secondarySystemGroupedBackground)
        }
        return Color(.tertiarySystemFill)
    }

    private var playerPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            waveformScrubber
                .frame(maxWidth: .infinity)

            timelineLabels

            playerControls
        }
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var waveformScrubber: some View {
        Group {
            if FileManager.default.fileExists(atPath: recording.fileURL.path) {
                WaveformView(
                    recording: recording,
                    currentTime: currentDisplayTime,
                    duration: duration,
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
                .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
            } else {
                Slider(
                    value: playbackPositionBinding,
                    in: 0...max(duration, 0.1)
                )
                .tint(themeManager.accentColor)
                .frame(height: 32)
            }
        }
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(formatTime(currentDisplayTime)) of \(formatTime(duration))")
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
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            let remaining = max(0, duration - currentDisplayTime)
            Text(isPlaying ? "-\(formatTime(remaining))" : formatTime(duration))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var playerControls: some View {
        HStack(spacing: 0) {
            moreActionsMenu

            Spacer(minLength: 12)

            HStack(spacing: 22) {
                transportCircleButton(
                    systemImage: "gobackward.15",
                    accessibilityLabel: "Back 15 seconds",
                    action: onSkipBackward
                )

                Button {
                    HapticFeedback.lightImpact()
                    onPlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .offset(x: isPlaying ? 0 : 2)
                        .frame(width: playButtonSize, height: playButtonSize)
                        .background(themeManager.accentColor, in: Circle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                transportCircleButton(
                    systemImage: "goforward.15",
                    accessibilityLabel: "Forward 15 seconds",
                    action: onSkipForward
                )
            }

            Spacer(minLength: 12)

            transportCircleButton(
                systemImage: "trash",
                accessibilityLabel: "Delete",
                foregroundColor: .red,
                role: .destructive,
                action: onDelete
            )
        }
        .padding(.top, 8)
    }

    private var moreActionsMenu: some View {
        Menu {
            Menu("Playback Speed") {
                speedMenuButton(rate: 0.75, label: "0.75×")
                speedMenuButton(rate: 1.0, label: "1×")
                speedMenuButton(rate: 1.25, label: "1.25×")
                speedMenuButton(rate: 1.5, label: "1.5×")
            }

            Divider()

            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                onTrim()
            } label: {
                Label("Trim", systemImage: "scissors")
            }

            Button {
                onExport()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(!FileManager.default.fileExists(atPath: recording.fileURL.path))
        } label: {
            transportButtonLabel(systemImage: "ellipsis")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("More recording actions")
    }

    private func transportButtonLabel(systemImage: String, foregroundColor: Color = .primary) -> some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .frame(width: transportButtonSize, height: transportButtonSize)
            .background(transportButtonFill, in: Circle())
    }

    private func transportCircleButton(
        systemImage: String,
        accessibilityLabel: String,
        foregroundColor: Color = .primary,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role) {
            HapticFeedback.lightImpact()
            action()
        } label: {
            transportButtonLabel(systemImage: systemImage, foregroundColor: foregroundColor)
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

private struct RecordingRowBackgroundModifier: ViewModifier {
    let isPlaying: Bool
    let isExpanded: Bool
    let fillColor: Color

    func body(content: Content) -> some View {
        content.listRowBackground(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                if isPlaying || isExpanded {
                    fillColor
                }
            }
        )
    }
}

