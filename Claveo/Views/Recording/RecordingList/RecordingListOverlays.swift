//
//  RecordingListView+Overlays.swift
//  Claveo
//
//  Floating controls and empty states split from the main layout.
//

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
        return hasActiveFilters ? "Try adjusting your search or filters" : "Tap the record button to create your first recording"
    }
}


