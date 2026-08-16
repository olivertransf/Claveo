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
    var onToggleKeepDownloaded: (() -> Void)? = nil
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)? = nil
    var allowsInlineExpansion: Bool = true
    var isSplitFocused: Bool = false

    private let transportHitSize: CGFloat = 44

    private var listDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: recording.createdAt)
    }

    private var hasNotes: Bool {
        !recording.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var rowHeader: some View {
        HStack(alignment: showsInlinePlayer ? .top : .firstTextBaseline, spacing: 12) {
            headerText
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: handleRowTap)
                .allowsHitTesting(!isSelectionMode)

            if showsInlinePlayer {
                moreActionsMenu
            } else {
                Text(recording.formattedDuration)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: handleRowTap)
                    .allowsHitTesting(!isSelectionMode)
            }
        }
        .padding(.vertical, 2)
    }

    private var showsInlinePlayer: Bool {
        allowsInlineExpansion && isExpanded
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(recording.displayName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(showsInlinePlayer ? 2 : 1)

            HStack(alignment: .center, spacing: 5) {
                Text(listDateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Image(systemName: recording.storageSystemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(recording.storageAccessibilityLabel)

                if hasNotes {
                    Image(systemName: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "Has notes"))
                }

                if let piece = recording.piece, !piece.isEmpty {
                    Text("·")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Text(piece)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .lineLimit(1)

            if showsInlinePlayer, !recording.tags.isEmpty {
                Text(recording.tags.map { RecordingTag.localizedName(for: $0) }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private func handleRowTap() {
        HapticFeedback.lightImpact()
        if allowsInlineExpansion {
            withAnimation(.easeInOut(duration: 0.22)) {
                isExpanded.toggle()
            }
        } else if !isExpanded {
            isExpanded = true
        }
    }

    var body: some View {
        Group {
            if isSelectionMode {
                Button(action: { onToggleSelection?() }) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(isSelected ? themeManager.accentColor : Color.secondary)
                        rowHeader
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: showsInlinePlayer ? 4 : 0) {
                    rowHeader

                    if showsInlinePlayer {
                        RecordingPlayerSurface(
                            recording: recording,
                            isPlaying: isPlaying,
                            currentTime: currentTime,
                            duration: duration,
                            playbackRate: playbackRate,
                            onPlayPause: onPlayPause,
                            onSeek: onSeek,
                            onSpeedChange: onSpeedChange,
                            onSkipBackward: onSkipBackward,
                            onSkipForward: onSkipForward,
                            onDelete: onDelete
                        )
                        .padding(.horizontal, 4)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .claveoListRowChrome(hideSeparator: false, showsBackground: false)
        .listRowBackground(rowBackground)
        .listRowInsets(splitRowInsets)
    }

    private var splitRowInsets: EdgeInsets {
        if allowsInlineExpansion {
            return EdgeInsets(top: 16, leading: 24, bottom: showsInlinePlayer ? 20 : 16, trailing: 22)
        }
        return EdgeInsets(top: 14, leading: 22, bottom: 14, trailing: 20)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if allowsInlineExpansion {
            Color(.systemBackground)
        } else {
            ZStack {
                Color(.systemBackground)
                if isSplitFocused {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(themeManager.accentColor.opacity(0.16))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                }
            }
        }
    }

    private var moreActionsMenu: some View {
        Menu {
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

            if recording.isStoredIniCloud, onToggleKeepDownloaded != nil {
                Divider()
                Button {
                    onToggleKeepDownloaded?()
                } label: {
                    if recording.keepDownloaded {
                        Label("Remove Download", systemImage: "icloud.and.arrow.down")
                    } else {
                        Label("Keep Downloaded", systemImage: "arrow.down.circle")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(themeManager.accentColor)
                .frame(width: transportHitSize, height: transportHitSize, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(String(localized: "More recording actions"))
    }
}
