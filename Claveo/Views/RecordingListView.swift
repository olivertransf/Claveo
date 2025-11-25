//
//  RecordingListView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct RecordingListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var player = AudioPlayer()
    @State private var filter = RecordingFilter()
    @State private var showingDeleteAlert = false
    @State private var recordingToDelete: Recording?
    @State private var showingPermissionAlert = false
    @State private var selectedRecording: Recording?
    @State private var showingDetailView = false
    
    var filteredRecordings: [Recording] {
        recorder.recordings.filter { filter.matches($0) }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                RecordingFilterView(filter: $filter)
                
                // Recordings list
                if filteredRecordings.isEmpty && !recorder.isRecording {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredRecordings) { recording in
                                RecordingRowView(
                                    recording: recording,
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
                                    onEdit: {
                                        selectedRecording = recording
                                        showingDetailView = true
                                    },
                                    onDelete: {
                                        recordingToDelete = recording
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
                
                // Recording controls
                VStack(spacing: 0) {
                    Divider()
                    
                    if recorder.isRecording {
                        recordingIndicatorView
                    }
                    
                    recordingControlsView
                }
                .background(Color.themeBackground)
            }
            .background(Color.themeGroupedBackground)
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDetailView) {
                if let recording = selectedRecording {
                    NavigationStack {
                        RecordingDetailView(
                            recording: recording,
                            onSave: { updatedRecording in
                                recorder.updateRecording(updatedRecording)
                            }
                        )
                    }
                }
            }
            .alert("Delete Recording", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let recording = recordingToDelete {
                        recorder.deleteRecording(recording)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this recording?")
            }
            .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) {
                    recorder.permissionError = nil
                }
            } message: {
                if let error = recorder.permissionError {
                    Text(error)
                } else {
                    Text("Microphone access is required to record audio.")
                }
            }
            .onChange(of: recorder.permissionError) { _, newValue in
                showingPermissionAlert = newValue != nil
            }
            .onChange(of: recorder.newlyCreatedRecordingId) { _, newId in
                if let newId = newId,
                   let recording = recorder.recordings.first(where: { $0.id == newId }) {
                    // Show detail view after recording stops
                    selectedRecording = recording
                    showingDetailView = true
                    recorder.newlyCreatedRecordingId = nil
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Recordings")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var recordingIndicatorView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.themeAccent)
                .frame(width: 8, height: 8)
            
            Text(formatTime(recorder.recordingTime))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.themeLabel)
        }
        .padding(.vertical, 12)
    }
    
    private var recordingControlsView: some View {
        HStack {
            Spacer()
            
            if recorder.isRecording {
                Button(action: {
                    recorder.stopRecording()
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.themeAccent, lineWidth: 2)
                            .frame(width: 64, height: 64)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.themeAccent)
                            .frame(width: 24, height: 24)
                    }
                }
            } else {
                Button(action: {
                    Task {
                        await recorder.startRecording()
                    }
                }) {
                    Circle()
                        .fill(Color.themeAccent)
                        .frame(width: 64, height: 64)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 24)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct RecordingRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let recording: Recording
    let isPlaying: Bool
    let currentTime: TimeInterval?
    let duration: TimeInterval
    let playbackRate: Float
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSpeedChange: (Float) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(recording.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(recording.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let piece = recording.piece {
                        Text(piece)
                            .font(.caption)
                            .foregroundColor(.themeAccent)
                    }
                    
                    if let measureRange = recording.measureRange {
                        Text(measureRange)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if !recording.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(recording.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.themeFill)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.themeAccent)
                        .frame(width: 44, height: 44)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.themeBackground)
            
            // Waveform and playback controls (shown when playing)
            if isPlaying, let currentTime = currentTime {
                VStack(spacing: 8) {
                    // Waveform
                    WaveformView(
                        recording: recording,
                        currentTime: currentTime,
                        duration: duration,
                        onSeek: onSeek
                    )
                    .environmentObject(themeManager)
                    .padding(.horizontal, 16)
                    
                    // Playback speed control
                    HStack {
                        Text("Speed:")
                            .font(.caption2)
                            .foregroundColor(.themeSecondaryLabel)
                        
                        Spacer()
                        
                        PlaybackSpeedControl(onSpeedChange: onSpeedChange)
                            .environmentObject(themeManager)
                    }
                    .padding(.horizontal, 16)
                    
                    // Time display
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatTime(duration))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
                .background(Color.themeBackground)
            }
            
            Divider()
                .padding(.leading, 60)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    RecordingListView()
}

