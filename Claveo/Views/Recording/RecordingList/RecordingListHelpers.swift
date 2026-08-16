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
        expandedRecordingId = recording.id
        if !usesSplitPlayback {
            selectedRecording = recording
        }
        recorder.newlyCreatedRecordingId = nil
    }

    var focusedRecording: Recording? {
        guard let expandedRecordingId else { return nil }
        return filteredRecordings.first(where: { $0.id == expandedRecordingId })
            ?? recorder.recordings.first(where: { $0.id == expandedRecordingId })
    }

    func syncSplitSelection() {
        guard usesSplitPlayback else { return }
        if let expandedRecordingId,
           filteredRecordings.contains(where: { $0.id == expandedRecordingId }) {
            return
        }
        expandedRecordingId = filteredRecordings.first?.id
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


