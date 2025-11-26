//
//  RecordingListView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct RecordingListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var player = AudioPlayer()
    @State private var showingDeleteAlert = false
    @State private var recordingToDelete: Recording?
    @State private var showingPermissionAlert = false
    @State private var selectedRecording: Recording?
    @State private var expandedRecordingId: UUID?
    @State private var searchText: String = ""
    @State private var selectedTag: String? = nil
    @State private var selectedPiece: String? = nil
    @State private var showingFilterSheet = false
    
    var filteredRecordings: [Recording] {
        var filtered = recorder.recordings
        
        // Search filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { recording in
                recording.name.lowercased().contains(searchLower) ||
                recording.piece?.lowercased().contains(searchLower) ?? false ||
                recording.notes.lowercased().contains(searchLower)
            }
        }
        
        // Tag filter
        if let selectedTag = selectedTag {
            filtered = filtered.filter { $0.tags.contains(selectedTag) }
        }
        
        // Piece filter
        if let selectedPiece = selectedPiece {
            filtered = filtered.filter { $0.piece == selectedPiece }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    var sortedRecordings: [Recording] {
        filteredRecordings
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Recordings list
                if sortedRecordings.isEmpty && !recorder.isRecording {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        // Search and filter bar
                        HStack(spacing: 12) {
                            // Search field
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                                
                                TextField("Search", text: $searchText)
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.themeFill)
                            .cornerRadius(10)
                            
                            // Filter button
                            Button(action: {
                                showingFilterSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: selectedTag != nil || selectedPiece != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 16))
                                    
                                    if selectedTag != nil || selectedPiece != nil {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .foregroundColor(selectedTag != nil || selectedPiece != nil ? .themeAccent : .secondary)
                                .frame(width: 44, height: 44)
                                .background(Color.themeFill)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.themeGroupedBackground)
                        
                        List {
                            // Recordings
                            ForEach(sortedRecordings) { recording in
                                RecordingRowView(
                                recording: recording,
                                isExpanded: expandedRecordingId == recording.id,
                                isPlaying: player.isPlaying && player.currentRecording?.id == recording.id,
                                currentTime: player.currentRecording?.id == recording.id ? player.currentTime : nil,
                                duration: recording.duration,
                                playbackRate: player.playbackRate,
                                onExpand: {
                                    // Expand/collapse on tap
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
                
                // Recording button - Spacer pushes it to bottom
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        if recorder.isRecording {
                            recordingIndicatorView
                        }
                        
                        recordingControlsView
                    }
                    .padding(.bottom, 8)
                }
            }
            .background(Color.themeGroupedBackground)
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedRecording) { recording in
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
            .sheet(isPresented: $showingFilterSheet) {
                RecordingFilterSheet(
                    selectedTag: $selectedTag,
                    selectedPiece: $selectedPiece,
                    availablePieces: loadAvailablePieces()
                )
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
                    recorder.newlyCreatedRecordingId = nil
                }
            }
        }
    }
    
    private func loadAvailablePieces() -> [Piece] {
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("pieces.json")
        
        // Try to load from iCloud first
        do {
            let data = try iCloudManager.shared.readFile(from: fileURL)
            if let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
                // Update local cache
                UserDefaults.standard.set(data, forKey: "pieces_cache")
                return decoded.sorted { $0.name < $1.name }
            }
        } catch {
            // iCloud file doesn't exist or can't be read - try fallback
        }
        
        // Fallback to direct read from iCloud directory
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
            // Update local cache
            UserDefaults.standard.set(data, forKey: "pieces_cache")
            return decoded.sorted { $0.name < $1.name }
        }
        
        // Last resort: load from local cache (for offline access)
        if let cachedData = UserDefaults.standard.data(forKey: "pieces_cache"),
           let decoded = try? JSONDecoder().decode([Piece].self, from: cachedData) {
            return decoded.sorted { $0.name < $1.name }
        }
        
        return []
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
    
    private var recordingIndicatorView: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(recorder.isRecording ? 1 : 0.5)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: recorder.isRecording)
            
            Text(formatTime(recorder.recordingTime))
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
    
    private var recordingControlsView: some View {
        HStack {
            Spacer()
            
            if recorder.isRecording {
                Button(action: {
                    recorder.stopRecording()
                }) {
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 60, height: 60)
                            .blur(radius: 4)
                        
                        // Background circle
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        // Stroke
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 60, height: 60)
                        
                        // Stop icon
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.red)
                            .frame(width: 22, height: 22)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop Recording")
                } else {
                Button(action: {
                    Task {
                        await recorder.startRecording()
                    }
                }) {
                    ZStack {
                        // Outer glow for dark mode
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 64, height: 64)
                            .blur(radius: 6)
                        
                        // Main button
                        Circle()
                            .fill(Color.red)
                            .frame(width: 60, height: 60)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start Recording")
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

struct RecordingRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let recording: Recording
    let isExpanded: Bool
    let isPlaying: Bool
    let currentTime: TimeInterval?
    let duration: TimeInterval
    let playbackRate: Float
    let onExpand: () -> Void
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSpeedChange: (Float) -> Void
    let onSkipBackward: () -> Void
    let onSkipForward: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onExpand) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recording.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(recording.relativeDateString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let piece = recording.piece {
                                Text("•")
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text(piece)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text(recording.formattedDuration)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(recording.displayName), \(recording.formattedDuration)")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
            
            // Waveform and playback controls (shown when expanded)
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    // Progress bar with time
                    VStack(spacing: 10) {
                        HStack {
                            Text(formatTime(currentTime ?? 0))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("-\(formatTime(duration - (currentTime ?? 0)))")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.themeFill)
                                    .frame(height: 3)
                                
                                // Progress track
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.themeAccent)
                                    .frame(width: geometry.size.width * CGFloat((currentTime ?? 0) / duration), height: 3)
                            }
                        }
                        .frame(height: 3)
                        .padding(.horizontal, 20)
                    }
                    
                    // Playback controls
                    HStack(spacing: 0) {
                        // Edit button
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.title3)
                                .foregroundColor(.themeAccent)
                                .frame(width: 50, height: 50)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit Recording")
                        
                        Spacer()
                        
                        // Skip backward button
                        Button(action: onSkipBackward) {
                            VStack(spacing: 4) {
                                Image(systemName: "gobackward.15")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                                Text("15")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 50, height: 50)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Skip Backward 15 Seconds")
                        
                        Spacer()
                        
                        // Play/Pause button
                        Button(action: onPlayPause) {
                            ZStack {
                                Circle()
                                    .fill(Color.themeAccent)
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .offset(x: isPlaying ? 0 : 2) // Slight offset for play icon
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPlaying ? "Pause" : "Play")
                        
                        Spacer()
                        
                        // Skip forward button
                        Button(action: onSkipForward) {
                            VStack(spacing: 4) {
                                Image(systemName: "goforward.15")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                                Text("15")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 50, height: 50)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // Delete button
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundColor(.red)
                                .frame(width: 50, height: 50)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color.themeBackground)
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview("Empty State") {
    RecordingListView()
        .environmentObject(ThemeManager.shared)
}

#Preview("With Recordings") {
    let view = RecordingListView()
    let recorder = AudioRecorder()
    
    // Add sample recordings
    let sampleRecordings = [
        Recording(
            fileName: "recording1.m4a",
            createdAt: Date(),
            duration: 125.5,
            name: "Run through",
            tags: ["Practice"]
        ),
        Recording(
            fileName: "recording2.m4a",
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            duration: 3.2,
            name: "New Recording 72",
            tags: []
        ),
        Recording(
            fileName: "recording3.m4a",
            createdAt: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            duration: 45.8,
            name: "891 26th Ave 11",
            tags: ["Lesson"],
            piece: "Grieg Concerto",
        ),
        Recording(
            fileName: "recording4.m4a",
            createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            duration: 90.0,
            name: "Grieg whole section",
            tags: ["Practice"]
        )
    ]
    
    // Use reflection or create a preview-specific version
    // For now, we'll use a workaround with a preview wrapper
    PreviewRecordingListView(recordings: sampleRecordings)
        .environmentObject(ThemeManager.shared)
}

#Preview("Active Recording") {
    let view = RecordingListView()
    let recorder = AudioRecorder()
    recorder.isRecording = true
    recorder.recordingTime = 45.3
    
    return PreviewRecordingListView(isRecording: true, recordingTime: 45.3)
        .environmentObject(ThemeManager.shared)
}

// Preview helper view that allows injecting state
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
        self.previewRecordings = recordings
        self.previewIsRecording = isRecording
        self.previewRecordingTime = recordingTime
    }
    
    var sortedRecordings: [Recording] {
        (previewRecordings ?? recorder.recordings).sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Recordings list
                if sortedRecordings.isEmpty && !(previewIsRecording ?? recorder.isRecording) {
                    emptyStateView
                } else {
                    List {
                        // Recordings
                        ForEach(sortedRecordings) { recording in
                            RecordingRowView(
                                recording: recording,
                                isExpanded: expandedRecordingId == recording.id,
                                isPlaying: player.isPlaying && player.currentRecording?.id == recording.id,
                                currentTime: player.currentRecording?.id == recording.id ? player.currentTime : nil,
                                duration: recording.duration,
                                playbackRate: player.playbackRate,
                                onExpand: {
                                    // Expand/collapse on tap
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
                
                // Floating recording button - fixed above tab bar
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        if previewIsRecording ?? recorder.isRecording {
                            VStack(spacing: 12) {
                                // Waveform preview
                                LiveWaveformView(audioLevels: recorder.waveformLevels)
                                    .padding(.horizontal, 20)
                                
                                previewRecordingIndicatorView
                            }
                        }
                        
                        previewRecordingControlsView
                    }
                    .padding(.bottom, 83) // Tab bar height + padding
                }
                .allowsHitTesting(true)
            }
            .background(Color.themeGroupedBackground)
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 150) // Space for button + tab bar
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
                        // Outer glow
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 60, height: 60)
                            .blur(radius: 4)
                        
                        // Background circle
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        // Stroke
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 60, height: 60)
                        
                        // Stop icon
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.red)
                            .frame(width: 22, height: 22)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {}) {
                    ZStack {
                        // Outer glow for dark mode
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 64, height: 64)
                            .blur(radius: 6)
                        
                        // Main button
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

