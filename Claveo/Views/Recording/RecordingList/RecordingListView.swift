//
//  RecordingListView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct RecordingListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject var recorder = AudioRecorder()
    @StateObject var player = AudioPlayer()
    @StateObject var settingsManager = SettingsManager.shared
    @State var showingDeleteAlert = false
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
    @State var showingSettingsSheet = false
    @State var showingStorageInfo = false
    @State var recordingToShare: Recording?
    
    var filteredRecordings: [Recording] {
        var filtered = recorder.recordings
        
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { recording in
                recording.name.lowercased().contains(searchLower) ||
                recording.piece?.lowercased().contains(searchLower) ?? false ||
                recording.notes.lowercased().contains(searchLower)
            }
        }
        
        if let selectedTag = selectedTag {
            filtered = filtered.filter { $0.tags.contains(selectedTag) }
        }
        
        if let selectedPiece = selectedPiece {
            filtered = filtered.filter { $0.piece == selectedPiece }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
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
                    if let index = availablePieces.firstIndex(where: { $0.id == updatedPiece.id }) {
                        availablePieces[index] = updatedPiece
                        availablePieces.sort { $0.name < $1.name }
                        savePieces()
                    }
                    editingPiece = nil
                },
                onDelete: {
                    availablePieces.removeAll { $0.id == pieceToEdit.id }
                    availablePieces.sort { $0.name < $1.name }
                    savePieces()
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
            handleNewRecording(newId)
        }
        .onAppear {
            availablePieces = loadAvailablePieces()
        }
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
    }
}
