//
//  WaveformView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import AVFoundation

struct WaveformView: View {
    let recording: Recording
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var waveformData: [Float] = []
    @State private var isLoading = true

    private var playProgress: CGFloat {
        duration > 0 ? CGFloat(currentTime / duration) : 0
    }

    var body: some View {
        GeometryReader { geometry in
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if waveformData.isEmpty {
                Text("No waveform data")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Canvas { context, size in
                    WaveformDrawing.drawBars(
                        in: context,
                        size: size,
                        samples: waveformData,
                        colorForIndex: { _, progress in
                            progress <= playProgress
                                ? themeManager.accentColor
                                : themeManager.accentColor.opacity(0.3)
                        }
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            onSeek(progress * duration)
                        }
                )
            }
        }
        .frame(height: 50)
        .onAppear {
            loadWaveform()
        }
    }

    private func loadWaveform() {
        Task {
            do {
                let samples = try await WaveformExtractor.extractBars(from: recording.fileURL, bars: 100)
                await MainActor.run {
                    waveformData = samples
                    isLoading = false
                }
            } catch {
                #if DEBUG
                print("Failed to load waveform: \(error)")
                #endif
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}
