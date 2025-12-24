//
//  PreviewRecordingListView.swift
//  Claveo
//
//  Helper view for RecordingListView previews.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct PreviewRecordingListView: View {
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var player = AudioPlayer()
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDeleteAlert = false
    @State private var recordingToDelete: Recording?
    @State private var showingPermissionAlert = false
    @State private var selectedRecording: Recording?
    @State private var expandedRecordingId: UUID?
    
    let previewRecordings: [Recording]?
    let previewIsRecording: Bool?
    let previewRecordingTime: TimeInterval?
    
    init(recordings: [Recording]? = nil, isRecording: Bool? = nil, recordingTime: TimeInterval? = nil) {
        previewRecordings = recordings
        previewIsRecording = isRecording
        previewRecordingTime = recordingTime
    }
    
    var sortedRecordings: [Recording] {
        (previewRecordings ?? recorder.recordings).sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if sortedRecordings.isEmpty && !(previewIsRecording ?? recorder.isRecording) {
                    ContentUnavailableView {
                        Label("No Recordings", systemImage: "waveform")
                    } description: {
                        Text("Tap the record button to create your first recording")
                    }
                } else {
                    List {
                        ForEach(sortedRecordings) { recording in
                            RecordingRowView(
                                recording: recording,
                                isExpanded: Binding(
                                    get: { expandedRecordingId == recording.id },
                                    set: { newValue in
                                        expandedRecordingId = newValue ? recording.id : nil
                                    }
                                ),
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
                    }
                    .listStyle(.automatic)
                }
            }
            .onAppear {
                if let recordings = previewRecordings {
                    recorder.recordings = recordings
                }
                if let isRecording = previewIsRecording {
                    recorder.isRecording = isRecording
                }
                if let recordingTime = previewRecordingTime {
                    recorder.recordingTime = recordingTime
                }
            }
        }
    }
    
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


