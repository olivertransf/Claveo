//
//  RecordingListView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct RecordingListView: View {
    struct BulkShareSession: Identifiable {
        let id = UUID()
        let urls: [URL]
    }
    
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ObservedObject var recorder = AudioRecorder.shared
    @StateObject var player = AudioPlayer()
    @StateObject var settingsManager = SettingsManager.shared
    @State var showingDeleteAlert = false
    @State var showingRecordingErrorAlert = false
    @State var showingPlaybackErrorAlert = false
    @State var recordingToDelete: Recording?
    @State var showingPermissionAlert = false
    @State var selectedRecording: Recording?
    @State var recordingToTrim: Recording?
    @State var expandedRecordingId: UUID?
    @State var searchText: String = ""
    @State var isSearchFocused: Bool = false
    @State var selectedTag: String? = nil
    @State var selectedPiece: String? = nil
    @State var showingFilterSheet = false
    @State var showingPiecesManagement = false
    @State var availablePieces: [Piece] = []
    @State var pieceSearchText: String = ""
    @State var newPieceName: String = ""
    @State var newPieceComposer: String = ""
    @State var editingPiece: Piece?
    @State var showingStorageInfo = false
    @State var recordingToShare: Recording?
    @State var isSelectingRecordings = false
    @State var selectedRecordingIds = Set<UUID>()
    @State var bulkShareSession: BulkShareSession?
    
    @State var filteredRecordings: [Recording] = []

    var usesSplitPlayback: Bool {
        horizontalSizeClass == .regular
    }

    func refreshFilteredRecordings() {
        var filtered = recorder.recordings

        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { recording in
                recording.name.lowercased().contains(searchLower) ||
                recording.piece?.lowercased().contains(searchLower) ?? false ||
                recording.notes.lowercased().contains(searchLower)
            }
        }

        if let selectedTag {
            filtered = filtered.filter { $0.tags.contains(selectedTag) }
        }

        if let selectedPiece {
            filtered = filtered.filter { $0.piece == selectedPiece }
        }

        filteredRecordings = filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        unifiedView
            .sheet(isPresented: $showingPiecesManagement) {
            PieceManagementView(pieces: $availablePieces)
                .environmentObject(themeManager)
        }
        .sheet(item: $editingPiece) { pieceToEdit in
            PieceEditSheet(
                piece: pieceToEdit,
                onSave: { updatedPiece in
                    do {
                        availablePieces = try PieceService.upsert(updatedPiece)
                    } catch {
                        if let index = availablePieces.firstIndex(where: { $0.id == updatedPiece.id }) {
                            availablePieces[index] = updatedPiece
                            availablePieces.sort { $0.name < $1.name }
                        }
                    }
                    editingPiece = nil
                },
                onDelete: {
                    do {
                        availablePieces = try PieceService.delete(id: pieceToEdit.id)
                    } catch {
                        availablePieces.removeAll { $0.id == pieceToEdit.id }
                        availablePieces.sort { $0.name < $1.name }
                    }
                    editingPiece = nil
                },
                onCancel: {
                    editingPiece = nil
                }
            )
            .environmentObject(themeManager)
        }
        .sheet(item: $selectedRecording) { recording in
            detailSheet(for: recording)
        }
        .sheet(item: $recordingToTrim) { recording in
            RecordingTrimView(recording: recording) { updatedRecording in
                recorder.updateRecording(updatedRecording)
            }
            .environmentObject(themeManager)
        }
        .modifier(RecordingListAlertsModifier(
            showingDeleteAlert: $showingDeleteAlert,
            showingPermissionAlert: $showingPermissionAlert,
            showingRecordingErrorAlert: $showingRecordingErrorAlert,
            showingPlaybackErrorAlert: $showingPlaybackErrorAlert,
            recordingToDelete: $recordingToDelete,
            recorder: recorder,
            player: player
        ))
        .onChange(of: recorder.newlyCreatedRecordingId) { _, newId in
            handleNewRecording(newId)
        }
        .onAppear {
            availablePieces = loadAvailablePieces()
            refreshFilteredRecordings()
        }
        .onReceive(recorder.$recordings) { _ in refreshFilteredRecordings() }
        .onChange(of: recorder.isLoadingRecordings) { _, _ in refreshFilteredRecordings() }
        .onChange(of: searchText) { _, _ in refreshFilteredRecordings() }
        .onChange(of: selectedTag) { _, _ in refreshFilteredRecordings() }
        .onChange(of: selectedPiece) { _, _ in refreshFilteredRecordings() }
        .sheet(item: $recordingToShare) { recording in
            if FileManager.default.fileExists(atPath: recording.fileURL.path) {
                if let shareableURL = try? recording.shareableFileURL() {
                    ShareSheet(activityItems: [shareableURL])
                        .onDisappear {
                            try? FileManager.default.removeItem(at: shareableURL)
                        }
                }
            }
        }
        .sheet(item: $bulkShareSession) { session in
            ShareSheet(activityItems: session.urls)
                .onDisappear {
                    for url in session.urls {
                        try? FileManager.default.removeItem(at: url)
                    }
                }
        }
    }
}

private struct RecordingListAlertsModifier: ViewModifier {
    @Binding var showingDeleteAlert: Bool
    @Binding var showingPermissionAlert: Bool
    @Binding var showingRecordingErrorAlert: Bool
    @Binding var showingPlaybackErrorAlert: Bool
    @Binding var recordingToDelete: Recording?
    @ObservedObject var recorder: AudioRecorder
    @ObservedObject var player: AudioPlayer

    func body(content: Content) -> some View {
        content
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
            .alert("Recording Error", isPresented: $showingRecordingErrorAlert) {
                Button("OK") {
                    recorder.recordingError = nil
                }
            } message: {
                Text(recorder.recordingError ?? String(localized: "The recording could not be saved."))
            }
            .alert("Playback Error", isPresented: $showingPlaybackErrorAlert) {
                Button("OK") {
                    player.playbackError = nil
                }
            } message: {
                Text(player.playbackError ?? String(localized: "Playback failed."))
            }
            .onChange(of: recorder.permissionError) { _, newValue in
                showingPermissionAlert = newValue != nil
            }
            .onChange(of: recorder.recordingError) { _, newValue in
                showingRecordingErrorAlert = newValue != nil
            }
            .onChange(of: player.playbackError) { _, newValue in
                showingPlaybackErrorAlert = newValue != nil
            }
    }
}
