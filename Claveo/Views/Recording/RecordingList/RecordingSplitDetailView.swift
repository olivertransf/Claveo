//
//  RecordingSplitDetailView.swift
//  Claveo
//
//  Voice Memos-style iPad detail player with a wide edit bar.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct RecordingSplitDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let recording: Recording
    @ObservedObject var player: AudioPlayer
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSpeedChange: (Float) -> Void
    let onSkipBackward: () -> Void
    let onSkipForward: () -> Void
    let onEdit: () -> Void
    let onTrim: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    var onToggleKeepDownloaded: (() -> Void)? = nil

    private var isPlaying: Bool {
        player.isPlaying && player.currentRecording?.id == recording.id
    }

    private var currentTime: TimeInterval? {
        player.currentRecording?.id == recording.id ? player.currentTime : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)

            Spacer(minLength: 8)

            RecordingPlayerSurface(
                recording: recording,
                isPlaying: isPlaying,
                currentTime: currentTime,
                duration: recording.duration,
                playbackRate: player.playbackRate,
                waveformHeight: 168,
                showsDeleteInTransport: false,
                onPlayPause: onPlayPause,
                onSeek: onSeek,
                onSpeedChange: onSpeedChange,
                onSkipBackward: onSkipBackward,
                onSkipForward: onSkipForward
            )
            .frame(maxWidth: .infinity)

            Spacer(minLength: 8)

            editActionBar
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.themeSecondaryGroupedBackground)
        }
        .splitDetailCardChrome()
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(recording.displayName)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Text(recording.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Image(systemName: recording.storageSystemImage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(recording.storageAccessibilityLabel)
            }

            if !recording.tags.isEmpty {
                Text(recording.tags.map { RecordingTag.localizedName(for: $0) }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var editActionBar: some View {
        HStack(spacing: 0) {
            editAction(
                title: String(localized: "Edit"),
                systemImage: "pencil",
                action: onEdit
            )
            editAction(
                title: String(localized: "Trim"),
                systemImage: "scissors",
                action: onTrim
            )
            editAction(
                title: String(localized: "Export"),
                systemImage: "square.and.arrow.up",
                enabled: recording.isLocallyAvailable,
                action: onExport
            )
            if recording.isStoredIniCloud, onToggleKeepDownloaded != nil {
                editAction(
                    title: recording.keepDownloaded
                        ? String(localized: "Remove Download")
                        : String(localized: "Keep Downloaded"),
                    systemImage: recording.keepDownloaded
                        ? "icloud.and.arrow.down"
                        : "arrow.down.circle",
                    action: { onToggleKeepDownloaded?() }
                )
            }
            editAction(
                title: String(localized: "Delete"),
                systemImage: "trash",
                role: .destructive,
                action: onDelete
            )
        }
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.themeTertiaryBackground)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Recording actions"))
    }

    private func editAction(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: {
            HapticFeedback.lightImpact()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(height: 24)
                Text(title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(role == .destructive ? Color.red : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(title)
    }
}
