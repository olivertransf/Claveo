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
    @Environment(\.colorScheme) var colorScheme
    @State private var isDragging = false
    @State private var dragValue: TimeInterval = 0
    
    var body: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: { isDragging ? dragValue : (currentTime ?? 0) },
                                    set: { newValue in
                                        dragValue = newValue
                                        if !isDragging {
                                            isDragging = true
                                        }
                                        onSeek(newValue)
                                    }
                                ),
                                in: 0...max(duration, 0.1)
                            )
                            .tint(themeManager.accentColor)
                            .onChange(of: currentTime) { _, newValue in
                                guard let newValue = newValue else { return }
                                
                                if isDragging {
                                    // If currentTime updates close to dragValue, seek completed
                                    if abs(newValue - dragValue) < 0.5 {
                                        isDragging = false
                                    }
                                } else {
                                    // Update dragValue to match currentTime when not dragging
                                    dragValue = newValue
                                }
                            }
                            
                            HStack {
                                Text(formatTime(isDragging ? dragValue : (currentTime ?? 0)))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                let remaining = max(0, duration - (isDragging ? dragValue : (currentTime ?? 0)))
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
                    
                    HStack(spacing: 0) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        
                        Button(action: onSkipBackward) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        
                        Button(action: onPlayPause) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        
                        Button(action: onSkipForward) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .padding(.horizontal, -20)
                }
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
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


