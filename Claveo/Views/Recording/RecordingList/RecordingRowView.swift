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
    @Environment(\.colorScheme) var colorScheme
    @State private var isDragging = false
    @State private var dragValue: TimeInterval = 0
    @State private var displayTime: TimeInterval = 0
    @State private var seekTask: Task<Void, Never>?
    @State private var lastUpdateTime: Date?
    @State private var lastKnownTime: TimeInterval = 0
    @State private var smoothUpdateTimer: Timer?
    @State private var seekDelayTask: Task<Void, Never>?
    
    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    private var buttonSize: CGFloat {
        isPhone ? 46 : 60
    }
    
    private var buttonSpacing: CGFloat {
        isPhone ? 2 : 8
    }
    
    private var iconSize: CGFloat {
        isPhone ? 20 : 28
    }
    
    private var playIconSize: CGFloat {
        isPhone ? 22 : 30
    }
    
    private var horizontalPadding: CGFloat {
        isPhone ? 8 : 16
    }
    
    var body: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 8) {
                            Slider(
                                value: Binding(
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
                                ),
                                in: 0...max(duration, 0.1)
                            )
                            .tint(themeManager.accentColor)
                            .onChange(of: currentTime) { _, newValue in
                                guard let newValue = newValue else { return }
                                
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
                            
                            HStack {
                                Text(formatTime(isDragging ? dragValue : displayTime))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                let remaining = max(0, duration - (isDragging ? dragValue : displayTime))
                                Text(isPlaying ? "-\(formatTime(remaining))" : formatTime(duration))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Picker("Speed", selection: Binding(
                            get: { playbackRate },
                            set: { newValue in
                                onSpeedChange(newValue)
                            }
                        )) {
                            Text("0.75x").tag(0.75 as Float)
                            Text("1x").tag(1.0 as Float)
                            Text("1.25x").tag(1.25 as Float)
                            Text("1.5x").tag(1.5 as Float)
                        }
                        .pickerStyle(.segmented)
                        .tint(themeManager.accentColor)
                    }
                    .padding(.vertical, 8)
                    
                    GeometryReader { geometry in
                        let screenWidth = geometry.size.width
                        let padding = horizontalPadding * 2
                        let availableWidth = screenWidth - padding
                        
                        let minWidthForAllButtons: CGFloat = 650
                        let showTrimAndExport = availableWidth >= minWidthForAllButtons
                        
                        let totalButtons = showTrimAndExport ? 7 : 5
                        let spacingCount = CGFloat(totalButtons - 1)
                        let totalSpacing = spacingCount * buttonSpacing
                        let maxButtonSize: CGFloat = isPhone ? 48 : 60
                        let buttonSpace = availableWidth - totalSpacing
                        let buttonSpacePerButton = buttonSpace / CGFloat(totalButtons)
                        let calculatedButtonSize = min(maxButtonSize, buttonSpacePerButton)
                        let actualButtonSize = max(40, calculatedButtonSize)
                        
                        HStack(spacing: buttonSpacing) {
                            HStack(spacing: buttonSpacing) {
                                Button(action: onEdit) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: iconSize))
                                }
                                .buttonStyle(.plain)
                                .frame(width: actualButtonSize, height: actualButtonSize)
                                
                                if showTrimAndExport {
                                    Button(action: onTrim) {
                                        Image(systemName: "scissors")
                                            .font(.system(size: iconSize))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: actualButtonSize, height: actualButtonSize)
                                }
                            }
                            
                            Spacer(minLength: 0)
                            
                            HStack(spacing: buttonSpacing) {
                                Button(action: onSkipBackward) {
                                    Image(systemName: "gobackward.15")
                                        .font(.system(size: iconSize))
                                }
                                .buttonStyle(.plain)
                                .frame(width: actualButtonSize, height: actualButtonSize)
                                
                                Button(action: onPlayPause) {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: playIconSize))
                                }
                                .buttonStyle(.plain)
                                .frame(width: actualButtonSize, height: actualButtonSize)
                                
                                Button(action: onSkipForward) {
                                    Image(systemName: "goforward.15")
                                        .font(.system(size: iconSize))
                                }
                                .buttonStyle(.plain)
                                .frame(width: actualButtonSize, height: actualButtonSize)
                            }
                            
                            Spacer(minLength: 0)
                            
                            HStack(spacing: buttonSpacing) {
                                if showTrimAndExport {
                                    Button(action: onExport) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: iconSize))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: actualButtonSize, height: actualButtonSize)
                                    .disabled(!FileManager.default.fileExists(atPath: recording.fileURL.path))
                                }
                                
                                Button(role: .destructive, action: onDelete) {
                                    Image(systemName: "trash")
                                        .font(.system(size: iconSize - 3))
                                }
                                .buttonStyle(.plain)
                                .frame(width: actualButtonSize, height: actualButtonSize)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                    .frame(height: buttonSize)
                }
                .frame(maxWidth: .infinity)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recording.displayName)
                            .font(.headline)
                            .lineLimit(2)
                        
                        // Date and piece on one row
                        HStack(spacing: 8) {
                            // Date
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(recording.shortDateString)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            
                            // Piece
                            if let piece = recording.piece {
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Image(systemName: "music.note")
                                        .font(.caption2)
                                    Text(piece)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        
                        // Tags on separate row
                        if !recording.tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(recording.tags.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.secondary)
                                        .cornerRadius(6)
                                }
                                if recording.tags.count > 3 {
                                    Text("+\(recording.tags.count - 3)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(recording.formattedDuration)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .monospacedDigit()
                        
                        if isPlaying {
                            Image(systemName: "waveform")
                                .foregroundColor(themeManager.accentColor)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                Task {
                    _ = try? await WaveformExtractor.extractBars(from: recording.fileURL, bars: 220)
                }
            }
        }
    }

    private func startSmoothTimer() {
        stopSmoothTimer()
        guard isPlaying, !isDragging else { return }
        smoothUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            guard self.isPlaying, !self.isDragging, let lastUpdate = self.lastUpdateTime else {
                timer.invalidate()
                self.smoothUpdateTimer = nil
                return
            }
            let elapsed = Date().timeIntervalSince(lastUpdate)
            let interpolated = self.lastKnownTime + (elapsed * Double(self.playbackRate))
            self.displayTime = min(interpolated, self.duration)
        }
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


