//
//  RecordingListView+Overlays.swift
//  Claveo
//
//  Floating controls and empty states split from the main layout.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

extension RecordingListView {
    var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Recordings", systemImage: "waveform")
        } description: {
            Text(emptyStateMessage)
        }
    }
    
    var emptyStateMessage: String {
        let hasActiveFilters = !searchText.isEmpty || selectedTag != nil || selectedPiece != nil
        return hasActiveFilters
            ? String(localized: "Try adjusting your search or filters")
            : String(localized: "Tap the record button to create your first recording")
    }
}


