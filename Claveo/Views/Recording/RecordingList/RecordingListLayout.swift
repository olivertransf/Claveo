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
            } else {
                try iCloudManager.shared.removeLocalDownload(at: recording.fileURL)
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

    @ViewBuilder
    var recordingsList: some View {
        let list = List {
            ForEach(filteredRecordings) { recording in
                recordingRow(for: recording)
            }
        }
        .claveoPlainListStyle()

        if usesSplitPlayback {
            list
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 6, for: .scrollContent)
                .contentMargins(.horizontal, 4, for: .scrollContent)
        } else {
            list
                .contentMargins(.vertical, 6, for: .scrollContent)
        }
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
        
        let row = RecordingRowView(
            recording: recording,
            isExpanded: isExpandedBinding,
            isPlaying: player.isPlaying && player.currentRecording?.id == recording.id,
            currentTime: player.currentRecording?.id == recording.id ? player.currentTime : nil,
            duration: recording.duration,
            playbackRate: player.playbackRate,
            onPlayPause: {
                playPause(recording)
            },
            onSeek: { time in
                player.seek(recording, to: time)
            },
            onSpeedChange: { speed in
                player.playbackRate = speed
            },
            onSkipBackward: {
                player.skipBackward(seconds: 15)
            },
            onSkipForward: {
                player.skipForward(seconds: 15)
            },
            onEdit: {
                selectedRecording = recording
            },
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
            onExport: {
                recordingToShare = recording
            },
            onToggleKeepDownloaded: {
                toggleKeepDownloaded(recording)
            },
            isSelectionMode: isSelectingRecordings,
            isSelected: selectedRecordingIds.contains(recording.id),
            onToggleSelection: {
                toggleRecordingSelection(recording.id)
            },
            allowsInlineExpansion: !usesSplitPlayback,
            isSplitFocused: usesSplitPlayback && expandedRecordingId == recording.id
        )
        
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
                    
                    if FileManager.default.fileExists(atPath: recording.fileURL.path) {
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
                    
                    if FileManager.default.fileExists(atPath: recording.fileURL.path) {
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
            splitLiveRecordingCard
        } else if let recording = focusedRecording {
            RecordingSplitDetailView(
                recording: recording,
                isPlaying: player.isPlaying && player.currentRecording?.id == recording.id,
                currentTime: player.currentRecording?.id == recording.id ? player.currentTime : nil,
                duration: recording.duration,
                playbackRate: player.playbackRate,
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

    var splitLiveRecordingCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(recorder.isRecording ? 1 : 0.45)
                    .symbolEffect(.pulse, options: .repeating, isActive: recorder.isRecording)

                Text(formatTime(recorder.recordingTime))
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            GeometryReader { geometry in
                let barPitch: CGFloat = 5.5
                let maxBars = max(80, Int(geometry.size.width / barPitch))
                LiveWaveformView(
                    audioLevels: recorder.waveformLevels,
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


