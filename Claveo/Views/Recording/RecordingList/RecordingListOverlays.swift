//
//  RecordingListView+Overlays.swift
//  Claveo
//
//  Floating controls and empty states split from the main layout.
//

import SwiftUI

extension RecordingListView {
    var recordingButtonOverlay: some View {
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
    
    var recordingIndicatorView: some View {
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
    
    var recordingControlsView: some View {
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
    
    var emptyStateView: some View {
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
    
    var emptyStateTitle: String {
        let hasActiveFilters = !searchText.isEmpty || selectedTag != nil || selectedPiece != nil
        return hasActiveFilters ? "No Results" : "No Recordings"
    }
    
    var emptyStateMessage: String {
        let hasActiveFilters = !searchText.isEmpty || selectedTag != nil || selectedPiece != nil
        if hasActiveFilters {
            return "Try adjusting your search or filters"
        }
        return "Tap the record button to create your first recording"
    }
}


