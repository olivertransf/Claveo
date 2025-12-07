//
//  RecordingListView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

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
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isRecordingButtonVisible: Bool = true
    
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
    
    @State private var isSearchPresented = false
    
    var body: some View {
        NavigationStack {
            mainContentView
                .background(Color.themeGroupedBackground)
                .navigationBarTitleDisplayMode(.inline)
                .if(isSearchPresented) { view in
                    view.searchable(
                        text: $searchText,
                        isPresented: $isSearchPresented,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search recordings..."
                    )
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        // Search button toggles the native search bar
                        if !isSearchPresented {
                            Button {
                                withAnimation {
                                    isSearchPresented = true
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(themeManager.accentColor)
                            }
                            
                            filterButton
                        }
                    }
                }
                .sheet(item: $selectedRecording) { recording in
                    detailSheet(for: recording)
                }
                .sheet(isPresented: $showingFilterSheet) {
                    filterSheet
                }
                .alert("Delete Recording", isPresented: $showingDeleteAlert) {
                    deleteAlertButtons
                } message: {
                    Text("Are you sure you want to delete this recording?")
                }
                .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
                    permissionAlertButtons
                } message: {
                    permissionAlertMessage
                }
                .onChange(of: recorder.permissionError) { _, newValue in
                    showingPermissionAlert = newValue != nil
                }
                .onChange(of: recorder.newlyCreatedRecordingId) { _, newId in
                    handleNewRecording(newId)
                }
        }
    }
    
    private var mainContentView: some View {
        ZStack {
            // Show either empty state or recordings list
            if shouldShowEmptyState {
                emptyStateView
            } else {
                recordingsList
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            
            // Recording button - Spacer pushes it to bottom
            if isRecordingButtonVisible {
                recordingButtonOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    private var shouldShowEmptyState: Bool {
        // Show empty state only if:
        // 1. Not currently recording AND
        // 2. Either no recordings exist at all, OR we have active filters/search with no results
        guard !recorder.isRecording else { return false }
        
        let hasRecordings = !recorder.recordings.isEmpty
        
        // If no recordings exist at all, show empty state
        if !hasRecordings {
            return true
        }
        
        // Only show empty state if we have active filters/search AND no results
        // This prevents flickering when typing fast
        let hasActiveFilters = !searchText.isEmpty || selectedTag != nil || selectedPiece != nil
        if hasActiveFilters && sortedRecordings.isEmpty {
            return true
        }
        
        return false
    }
    
    private var filterButton: some View {
        Button(action: {
            showingFilterSheet = true
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: selectedTag != nil || selectedPiece != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(themeManager.accentColor)
                
                if selectedTag != nil || selectedPiece != nil {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
    
    private var recordingsList: some View {
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
            
            // Only update if there's significant movement
            guard abs(scrollDelta) > 5 else { return }
            
            // Hide button when scrolling down (negative delta), show when scrolling up (positive delta)
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
            Color.clear.frame(height: 140) // Space for recording button - increased for better scrolling
        }
        .contentMargins(.bottom, 20, for: .scrollContent)
    }
    
    private func recordingRow(for recording: Recording) -> some View {
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
    
    private var recordingButtonOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                if recorder.isRecording {
                    recordingIndicatorView
                }
                
                recordingControlsView
            }
            .padding(.bottom, 15)
        }
    }
    
    private func detailSheet(for recording: Recording) -> some View {
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
    
    private var filterSheet: some View {
        RecordingFilterSheet(
            selectedTag: $selectedTag,
            selectedPiece: $selectedPiece,
            availablePieces: loadAvailablePieces()
        )
    }
    
    @ViewBuilder
    private var deleteAlertButtons: some View {
        Button("Cancel", role: .cancel) { }
        Button("Delete", role: .destructive) {
            if let recording = recordingToDelete {
                recorder.deleteRecording(recording)
            }
        }
    }
    
    @ViewBuilder
    private var permissionAlertButtons: some View {
        Button("Settings") {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }
        Button("Cancel", role: .cancel) {
            recorder.permissionError = nil
        }
    }
    
    private var permissionAlertMessage: Text {
        if let error = recorder.permissionError {
            return Text(error)
        } else {
            return Text("Microphone access is required to record audio.")
        }
    }
    
    private func handleNewRecording(_ newId: UUID?) {
        guard let newId = newId,
              let recording = recorder.recordings.first(where: { $0.id == newId }) else {
            return
        }
        selectedRecording = recording
        recorder.newlyCreatedRecordingId = nil
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
            
            Text(emptyStateTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateTitle: String {
        let hasActiveFilters = !searchText.isEmpty || selectedTag != nil || selectedPiece != nil
        return hasActiveFilters ? "No Results" : "No Recordings"
    }
    
    private var emptyStateMessage: String {
        let hasActiveFilters = !searchText.isEmpty || selectedTag != nil || selectedPiece != nil
        if hasActiveFilters {
            return "Try adjusting your search or filters"
        }
        return "Tap the record button to create your first recording"
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
                        Circle()
                            .fill(Color.red)
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
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
                    Circle()
                        .fill(Color.red)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
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
    @Environment(\.colorScheme) var colorScheme
    
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
            
            // Playback controls (shown when expanded)
            if isExpanded {
                VStack(spacing: 16) {
                    // Progress Bar
                    GeometryReader { geometry in
                        let availableWidth = geometry.size.width
                        ZStack(alignment: .leading) {
                            // Background
                            Capsule()
                                .fill(Color(.systemGray4))
                                .frame(height: 3)
                            
                            // Progress
                            Capsule()
                                .fill(themeManager.accentColor)
                                .frame(width: availableWidth * CGFloat((currentTime ?? 0) / max(duration, 1)), height: 3)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let percentage = min(max(0, value.location.x / availableWidth), 1)
                                    let newTime = TimeInterval(percentage) * duration
                                    onSeek(newTime)
                                }
                        )
                    }
                    .frame(height: 3)
                    
                    // Time (right under progress bar)
                    HStack {
                        Text(formatTime(currentTime ?? 0))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(isPlaying ? "-\(formatTime(max(0, duration - (currentTime ?? 0))))" : formatTime(duration))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    // Controls
                    HStack {
                        // Edit button
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit Recording")
                        
                        Spacer()
                        
                        // Skip Backward
                        Button(action: onSkipBackward) {
                            Image(systemName: "gobackward.15")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Skip Backward 15 Seconds")
                        
                        Spacer()
                            .frame(width: 50)
                        
                        // Play/Pause
                        Button(action: onPlayPause) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPlaying ? "Pause" : "Play")
                        
                        Spacer()
                            .frame(width: 50)
                        
                        // Skip Forward
                        Button(action: onSkipForward) {
                            Image(systemName: "goforward.15")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Skip Forward 15 Seconds")
                        
                        Spacer()
                        
                        // Delete button
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete Recording")
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
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
    PreviewRecordingListView(isRecording: true, recordingTime: 45.3)
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


// PreferenceKey for tracking scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
