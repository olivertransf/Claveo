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
    @StateObject var recorder = AudioRecorder()
    @StateObject var player = AudioPlayer()
    @State var showingDeleteAlert = false
    @State var recordingToDelete: Recording?
    @State var showingPermissionAlert = false
    @State var selectedRecording: Recording?
    @State var expandedRecordingId: UUID?
    @State var searchText: String = ""
    @State var selectedTag: String? = nil
    @State var selectedPiece: String? = nil
    @State var showingFilterSheet = false
    @State var showingPiecesManagement = false
    @State var availablePieces: [Piece] = []
    @State var lastScrollOffset: CGFloat = 0
    @State var isRecordingButtonVisible: Bool = true
    
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
    
    @State var isSearchPresented = false
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        Group {
            if isIPad {
                iPadView
            } else {
                iPhoneView
            }
        }
        .sheet(isPresented: $showingPiecesManagement) {
            PieceManagementView(pieces: $availablePieces)
                .environmentObject(themeManager)
        }
        .onChange(of: showingPiecesManagement) { _, isPresented in
            if !isPresented {
                availablePieces = loadAvailablePieces()
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
        .onAppear {
            availablePieces = loadAvailablePieces()
        }
    }
}
