//
//  RecordingListView+Layout.swift
//  Claveo
//
//  Layout and subviews extracted to keep RecordingListView small.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import UIKit

extension RecordingListView {
    func beginRecordingSelectionMode() {
        if player.isPlaying {
            player.pause()
        }
        if !usesSplitPlayback {
            expandedRecordingId = nil
        }
        isSelectingRecordings = true
        selectedRecordingIds.removeAll()
    }
    
    func exitRecordingSelectionMode() {
        isSelectingRecordings = false
        selectedRecordingIds.removeAll()
    }
    
    func toggleRecordingSelection(_ id: UUID) {
        if selectedRecordingIds.contains(id) {
            selectedRecordingIds.remove(id)
        } else {
            selectedRecordingIds.insert(id)
        }
    }
    
    func toggleKeepDownloaded(_ recording: Recording) {
        var updated = recording
        updated.keepDownloaded.toggle()
        if !updated.keepDownloaded {
            player.pauseIfPlaying(recording)
        }
        do {
            if updated.keepDownloaded {
                try iCloudManager.shared.startKeepingDownloaded(at: recording.fileURL)
                updated.isLocallyAvailable = true
            } else {
                try iCloudManager.shared.removeLocalDownload(at: recording.fileURL)
                updated.isLocallyAvailable = false
            }
        } catch {
            #if DEBUG
            print("Failed to update iCloud download: \(error)")
            #endif
        }
        recorder.updateRecording(updated)
    }

    func exportSelectedRecordings() {
        let recordings = filteredRecordings.filter { selectedRecordingIds.contains($0.id) }
        var urls: [URL] = []
        for recording in recordings {
            guard FileManager.default.fileExists(atPath: recording.fileURL.path) else { continue }
            guard let url = try? recording.shareableFileURL() else { continue }
            urls.append(url)
        }
        guard !urls.isEmpty else { return }
        bulkShareSession = RecordingListView.BulkShareSession(urls: urls)
    }
    
    @ViewBuilder
    var mainContentView: some View {
        if recorder.isLoadingRecordings && recorder.recordings.isEmpty {
            ProgressView("Loading recordings…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if shouldShowEmptyState {
            emptyStateView
        } else {
            recordingsList
        }
    }
    
    var shouldShowEmptyState: Bool {
        guard !recorder.isRecording else { return false }
        if recorder.isLoadingRecordings && recorder.recordings.isEmpty { return false }

        let hasRecordings = !recorder.recordings.isEmpty
        if !hasRecordings {
            return true
        }
        
        let hasActiveFilters = !searchText.isEmpty || selectedTag != nil || selectedPiece != nil
        if hasActiveFilters && filteredRecordings.isEmpty {
            return true
        }
        
        return false
    }

    var recordingsList: some View {
        List {
            Section {
                ForEach(filteredRecordings) { recording in
                    recordingRow(for: recording)
                }
            }
        }
        .claveoInsetGroupedListStyle()
    }
    
    @ViewBuilder
    func recordingRow(for recording: Recording) -> some View {
        let isExpandedBinding = Binding<Bool>(
            get: { expandedRecordingId == recording.id },
            set: { newValue in
                if newValue {
                    if let current = player.currentRecording, current.id != recording.id {
                        player.pause()
                    }
                    expandedRecordingId = recording.id
                } else {
                    player.pauseIfPlaying(recording)
                    if expandedRecordingId == recording.id {
                        expandedRecordingId = nil
                    }
                }
            }
        )

        let observesPlayback = !usesSplitPlayback && expandedRecordingId == recording.id
        let row = Group {
            if observesPlayback {
                PlaybackObservingRecordingRow(
                    recording: recording,
                    player: player,
                    isExpanded: isExpandedBinding,
                    onPlayPause: { playPause(recording) },
                    onSeek: { player.seek(recording, to: $0) },
                    onSpeedChange: { player.playbackRate = $0 },
                    onSkipBackward: { player.skipBackward(seconds: 15) },
                    onSkipForward: { player.skipForward(seconds: 15) },
                    onEdit: { selectedRecording = recording },
                    onDelete: {
                        recordingToDelete = recording
                        showingDeleteAlert = true
                    },
                    onTrim: {
                        if player.currentRecording?.id == recording.id {
                            player.stop()
                        }
                        recordingToTrim = recording
                    },
                    onExport: { recordingToShare = recording },
                    onToggleKeepDownloaded: { toggleKeepDownloaded(recording) },
                    isSelectionMode: isSelectingRecordings,
                    isSelected: selectedRecordingIds.contains(recording.id),
                    onToggleSelection: { toggleRecordingSelection(recording.id) }
                )
            } else {
                RecordingRowView(
                    recording: recording,
                    isExpanded: isExpandedBinding,
                    isPlaying: false,
                    currentTime: nil,
                    duration: recording.duration,
                    playbackRate: 1,
                    onPlayPause: { playPause(recording) },
                    onSeek: { player.seek(recording, to: $0) },
                    onSpeedChange: { player.playbackRate = $0 },
                    onSkipBackward: { player.skipBackward(seconds: 15) },
                    onSkipForward: { player.skipForward(seconds: 15) },
                    onEdit: { selectedRecording = recording },
                    onDelete: {
                        recordingToDelete = recording
                        showingDeleteAlert = true
                    },
                    onTrim: {
                        if player.currentRecording?.id == recording.id {
                            player.stop()
                        }
                        recordingToTrim = recording
                    },
                    onExport: { recordingToShare = recording },
                    onToggleKeepDownloaded: { toggleKeepDownloaded(recording) },
                    isSelectionMode: isSelectingRecordings,
                    isSelected: selectedRecordingIds.contains(recording.id),
                    onToggleSelection: { toggleRecordingSelection(recording.id) },
                    allowsInlineExpansion: !usesSplitPlayback,
                    isSplitFocused: usesSplitPlayback && expandedRecordingId == recording.id
                )
            }
        }
        
        if isSelectingRecordings {
            row
        } else {
            row
                .contextMenu {
                    Button {
                        selectedRecording = recording
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        if player.currentRecording?.id == recording.id {
                            player.stop()
                        }
                        recordingToTrim = recording
                    } label: {
                        Label("Trim", systemImage: "scissors")
                    }
                    
                    if recording.isLocallyAvailable {
                        ShareLink(
                            item: RecordingFileTransferable(recording: recording),
                            preview: SharePreview(recording.displayName, icon: Image(systemName: "waveform"))
                        ) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }

                    if recording.isStoredIniCloud {
                        Button {
                            toggleKeepDownloaded(recording)
                        } label: {
                            if recording.keepDownloaded {
                                Label("Remove Download", systemImage: "icloud.and.arrow.down")
                            } else {
                                Label("Keep Downloaded", systemImage: "arrow.down.circle")
                            }
                        }
                    }
                    
                    Button(role: .destructive) {
                        recordingToDelete = recording
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        recordingToDelete = recording
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    if recording.isLocallyAvailable {
                        Button {
                            recordingToShare = recording
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .tint(.green)
                    }

                    Button {
                        if player.currentRecording?.id == recording.id {
                            player.stop()
                        }
                        recordingToTrim = recording
                    } label: {
                        Label("Trim", systemImage: "scissors")
                    }
                    .tint(.orange)
                    
                    Button {
                        selectedRecording = recording
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
        }
    }
    
    func playPause(_ recording: Recording) {
        if player.currentRecording?.id == recording.id {
            if player.isPlaying {
                player.pause()
            } else {
                player.play(recording)
            }
        } else {
            if !usesSplitPlayback {
                expandedRecordingId = recording.id
            }
            player.play(recording)
        }
    }

    @ViewBuilder
    var splitDetailColumn: some View {
        if recorder.isRecording {
            LiveRecordingSplitCard(meter: recorder.meter, isRecording: true)
        } else if let recording = focusedRecording {
            RecordingSplitDetailView(
                recording: recording,
                player: player,
                onPlayPause: { playPause(recording) },
                onSeek: { player.seek(recording, to: $0) },
                onSpeedChange: { player.playbackRate = $0 },
                onSkipBackward: { player.skipBackward(seconds: 15) },
                onSkipForward: { player.skipForward(seconds: 15) },
                onEdit: { selectedRecording = recording },
                onTrim: {
                    if player.currentRecording?.id == recording.id {
                        player.stop()
                    }
                    recordingToTrim = recording
                },
                onExport: { recordingToShare = recording },
                onDelete: {
                    recordingToDelete = recording
                    showingDeleteAlert = true
                },
                onToggleKeepDownloaded: { toggleKeepDownloaded(recording) }
            )
            .id(recording.id)
        } else {
            ContentUnavailableView {
                Label("Select a Recording", systemImage: "waveform")
            } description: {
                Text("Choose a recording from the list to play or edit it.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.themeGroupedBackground)
        }
    }

    func detailSheet(for recording: Recording) -> some View {
        NavigationStack {
            RecordingDetailView(
                recording: recording,
                onSave: { updatedRecording in
                    recorder.updateRecording(updatedRecording)
                    selectedRecording = nil
                }
            )
            .environmentObject(themeManager)
        }
    }
    
    var filterSheet: some View {
        RecordingFilterSheet(
            selectedTag: $selectedTag,
            selectedPiece: $selectedPiece,
            availablePieces: loadAvailablePieces()
        )
    }
}

private struct PlaybackObservingRecordingRow: View {
    let recording: Recording
    @ObservedObject var player: AudioPlayer
    @Binding var isExpanded: Bool
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

    var body: some View {
        RecordingRowView(
            recording: recording,
            isExpanded: $isExpanded,
            isPlaying: player.isPlaying && player.currentRecording?.id == recording.id,
            currentTime: player.currentRecording?.id == recording.id ? player.currentTime : nil,
            duration: recording.duration,
            playbackRate: player.playbackRate,
            onPlayPause: onPlayPause,
            onSeek: onSeek,
            onSpeedChange: onSpeedChange,
            onSkipBackward: onSkipBackward,
            onSkipForward: onSkipForward,
            onEdit: onEdit,
            onDelete: onDelete,
            onTrim: onTrim,
            onExport: onExport,
            onToggleKeepDownloaded: onToggleKeepDownloaded,
            isSelectionMode: isSelectionMode,
            isSelected: isSelected,
            onToggleSelection: onToggleSelection,
            allowsInlineExpansion: true,
            isSplitFocused: false
        )
    }
}

private struct LiveRecordingSplitCard: View {
    @ObservedObject var meter: RecordingMeter
    let isRecording: Bool

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(isRecording ? 1 : 0.45)
                    .symbolEffect(.pulse, options: .repeating, isActive: isRecording)

                Text(Self.formatTime(meter.recordingTime))
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            GeometryReader { geometry in
                let barPitch: CGFloat = 5.5
                let maxBars = max(80, Int(geometry.size.width / barPitch))
                LiveWaveformView(
                    audioLevels: meter.waveformLevels,
                    maxBars: maxBars,
                    barColor: .primary
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(height: 88)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.themeSecondaryGroupedBackground)
        }
        .splitDetailCardChrome()
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


