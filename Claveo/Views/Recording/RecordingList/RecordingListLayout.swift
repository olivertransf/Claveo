//
//  RecordingListView+Layout.swift
//  Claveo
//
//  Layout and subviews extracted to keep RecordingListView small.
//

import SwiftUI

extension RecordingListView {
    @ViewBuilder
    var mainContentView: some View {
        if shouldShowEmptyState {
            emptyStateView
        } else {
            recordingsList
        }
    }
    
    var shouldShowEmptyState: Bool {
        guard !recorder.isRecording else { return false }
        
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
    
    func recordingRow(for recording: Recording) -> some View {
        let isExpandedBinding = Binding<Bool>(
            get: { expandedRecordingId == recording.id },
            set: { newValue in
                expandedRecordingId = newValue ? recording.id : nil
            }
        )
        
        return RecordingRowView(
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
            }
        )
        .contextMenu {
            Button {
                selectedRecording = recording
            } label: {
                Label("Edit", systemImage: "pencil")
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
            
            Button {
                selectedRecording = recording
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
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


