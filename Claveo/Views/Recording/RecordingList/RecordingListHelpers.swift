//
//  RecordingListView+Helpers.swift
//  Claveo
//
//  Logic helpers split from RecordingListView.
//

import SwiftUI

extension RecordingListView {
    func handleNewRecording(_ newId: UUID?) {
        guard let newId = newId,
              let recording = recorder.recordings.first(where: { $0.id == newId }) else {
            return
        }
        selectedRecording = recording
        recorder.newlyCreatedRecordingId = nil
    }
    
    func loadAvailablePieces() -> [Piece] {
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("pieces.json")
        
        do {
            let data = try iCloudManager.shared.readFile(from: fileURL)
            if let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
                UserDefaults.standard.set(data, forKey: "pieces_cache")
                return decoded.sorted { $0.name < $1.name }
            }
        } catch {
            // fall through to other strategies
        }
        
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
            UserDefaults.standard.set(data, forKey: "pieces_cache")
            return decoded.sorted { $0.name < $1.name }
        }
        
        if let cachedData = UserDefaults.standard.data(forKey: "pieces_cache"),
           let decoded = try? JSONDecoder().decode([Piece].self, from: cachedData) {
            return decoded.sorted { $0.name < $1.name }
        }
        
        return []
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


