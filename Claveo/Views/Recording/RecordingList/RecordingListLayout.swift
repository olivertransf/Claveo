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
        expandedRecordingId = nil
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
            ForEach(filteredRecordings) { recording in
                recordingRow(for: recording)
            }
        }
        .listStyle(.automatic)
    }
    
    @ViewBuilder
    func recordingRow(for recording: Recording) -> some View {
        let isExpandedBinding = Binding<Bool>(
            get: { expandedRecordingId == recording.id },
            set: { newValue in
                expandedRecordingId = newValue ? recording.id : nil
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
                if player.currentRecording?.id == recording.id {
                    if player.isPlaying {
                        player.pause()
                    } else {
                        player.play(recording)
                    }
                } else {
                    player.play(recording)
                }
            },
            onSeek: { time in
                player.seek(to: time)
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
            isSelectionMode: isSelectingRecordings,
            isSelected: selectedRecordingIds.contains(recording.id),
            onToggleSelection: {
                toggleRecordingSelection(recording.id)
            }
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


