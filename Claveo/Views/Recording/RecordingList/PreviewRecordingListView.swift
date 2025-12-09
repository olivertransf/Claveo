//
//  PreviewRecordingListView.swift
//  Claveo
//
//  Helper view for RecordingListView previews.
//

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
            ZStack {
                if sortedRecordings.isEmpty && !(previewIsRecording ?? recorder.isRecording) {
                    emptyStateView
                } else {
                    List {
                        ForEach(sortedRecordings) { recording in
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
                            .listRowInsets(EdgeInsets())
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
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        if previewIsRecording ?? recorder.isRecording {
                            VStack(spacing: 12) {
                                LiveWaveformView(audioLevels: recorder.waveformLevels)
                                    .padding(.horizontal, 20)
                                
                                previewRecordingIndicatorView
                            }
                        }
                        
                        previewRecordingControlsView
                    }
                    .padding(.bottom, 83)
                }
                .allowsHitTesting(true)
            }
            .background(Color.themeGroupedBackground)
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 150)
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
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Recordings")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Tap the record button to create your first recording")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var previewRecordingIndicatorView: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(1)
            
            Text(formatTime(previewRecordingTime ?? recorder.recordingTime))
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.themeBackground.opacity(0.95))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var previewRecordingControlsView: some View {
        HStack {
            Spacer()
            
            if previewIsRecording ?? recorder.isRecording {
                Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 60, height: 60)
                            .blur(radius: 4)
                        
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 60, height: 60)
                        
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.red)
                            .frame(width: 22, height: 22)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 64, height: 64)
                            .blur(radius: 6)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 60, height: 60)
                    }
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


