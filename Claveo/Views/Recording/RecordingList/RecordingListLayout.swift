//
//  RecordingListView+Layout.swift
//  Claveo
//
//  Layout and subviews extracted to keep RecordingListView small.
//

import SwiftUI

extension RecordingListView {
    var mainContentView: some View {
        ZStack {
            if shouldShowEmptyState {
                emptyStateView
            } else {
                recordingsList
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            
            if isRecordingButtonVisible {
                recordingButtonOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    var shouldShowEmptyState: Bool {
        guard !recorder.isRecording else { return false }
        
        let hasRecordings = !recorder.recordings.isEmpty
        if !hasRecordings {
            return true
        }
        
        let hasActiveFilters = !searchText.isEmpty || selectedTag != nil || selectedPiece != nil
        if hasActiveFilters && sortedRecordings.isEmpty {
            return true
        }
        
        return false
    }

    var recordingsList: some View {
        List {
            ForEach(sortedRecordings) { recording in
                recordingRow(for: recording)
                    .background(
                        GeometryReader { geometry in
                            let frame = geometry.frame(in: .named("scroll"))
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: frame.minY
                            )
                        }
                    )
            }
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            let currentOffset = value
            let scrollDelta = currentOffset - lastScrollOffset
            guard abs(scrollDelta) > 5 else { return }
            
            withAnimation(.easeInOut(duration: 0.2)) {
                if scrollDelta < 0 {
                    isRecordingButtonVisible = false
                } else {
                    isRecordingButtonVisible = true
                }
            }
            
            lastScrollOffset = currentOffset
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 140)
        }
        .contentMargins(.bottom, 20, for: .scrollContent)
    }
    
    func recordingRow(for recording: Recording) -> some View {
        RecordingRowView(
            recording: recording,
            isExpanded: expandedRecordingId == recording.id,
            isPlaying: player.isPlaying && player.currentRecording?.id == recording.id,
            currentTime: player.currentRecording?.id == recording.id ? player.currentTime : nil,
            duration: recording.duration,
            playbackRate: player.playbackRate,
            onExpand: {
                if expandedRecordingId == recording.id {
                    expandedRecordingId = nil
                } else {
                    expandedRecordingId = recording.id
                }
            },
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
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.visible)
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
    
    @ViewBuilder
    var deleteAlertButtons: some View {
        Button("Cancel", role: .cancel) { }
        Button("Delete", role: .destructive) {
            if let recording = recordingToDelete {
                recorder.deleteRecording(recording)
            }
        }
    }
    
    @ViewBuilder
    var permissionAlertButtons: some View {
        Button("Settings") {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }
        Button("Cancel", role: .cancel) {
            recorder.permissionError = nil
        }
    }
    
    var permissionAlertMessage: Text {
        if let error = recorder.permissionError {
            return Text(error)
        } else {
            return Text("Microphone access is required to record audio.")
        }
    }
    
}


