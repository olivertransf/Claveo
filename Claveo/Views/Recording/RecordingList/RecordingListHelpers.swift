//
//  RecordingListView+Helpers.swift
//  Claveo
//
//  Logic helpers split from RecordingListView.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

extension RecordingListView {
    func handleNewRecording(_ newId: UUID?) {
        guard let newId = newId,
              let recording = recorder.recordings.first(where: { $0.id == newId }) else {
            return
        }
        searchText = ""
        selectedTag = nil
        selectedPiece = nil
        refreshFilteredRecordings()
        selectedRecording = recording
        recorder.newlyCreatedRecordingId = nil
    }
    
    func loadAvailablePieces() -> [Piece] {
        PieceService.load()
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var filteredSidebarPieces: [Piece] {
        if pieceSearchText.isEmpty {
            return availablePieces.sorted { $0.name < $1.name }
        }
        return availablePieces.filter { piece in
            piece.name.localizedCaseInsensitiveContains(pieceSearchText) ||
            (piece.composer?.localizedCaseInsensitiveContains(pieceSearchText) ?? false)
        }.sorted { $0.name < $1.name }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


