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
    @State private var sourceWaveformData: [Float] = []
    @State private var viewWidth: CGFloat = 1

    private var playProgress: CGFloat {
        duration > 0 ? CGFloat(currentTime / duration) : 0
    }

    private var hasWaveform: Bool {
        !sourceWaveformData.isEmpty
    }

    var body: some View {
        ZStack {
            if !hasWaveform {
                timelineScrubber
                    .transition(.opacity)
            }

            if hasWaveform {
                waveformCanvas
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasWaveform)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { viewWidth = max(proxy.size.width, 1) }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        viewWidth = max(newWidth, 1)
                    }
            }
        }
        .contentShape(Rectangle())
        .gesture(seekGesture)
        .task(id: recording.id) {
            await loadWaveform()
        }
    }

    private var timelineScrubber: some View {
        Canvas { context, size in
            let trackHeight: CGFloat = 4
            let midY = size.height / 2
            let trackRect = CGRect(
                x: 0,
                y: midY - trackHeight / 2,
                width: size.width,
                height: trackHeight
            )

            context.fill(
                Path(roundedRect: trackRect, cornerRadius: 2),
                with: .color(Color.secondary.opacity(0.22))
            )

            let playedWidth = size.width * playProgress
            if playedWidth > 0 {
                let playedRect = CGRect(
                    x: 0,
                    y: midY - trackHeight / 2,
                    width: playedWidth,
                    height: trackHeight
                )
                context.fill(
                    Path(roundedRect: playedRect, cornerRadius: 2),
                    with: .color(themeManager.accentColor.opacity(0.85))
                )
            }

            let playheadX = size.width * playProgress
            let playheadRect = CGRect(x: playheadX - 1, y: 6, width: 2, height: size.height - 12)
            context.fill(
                Path(roundedRect: playheadRect, cornerRadius: 1),
                with: .color(themeManager.accentColor)
            )
        }
    }

    private var waveformCanvas: some View {
        Canvas { context, size in
            let barCount = WaveformDrawing.barCount(for: size.width)
            let samples = WaveformDrawing.resample(sourceWaveformData, to: barCount)
            WaveformDrawing.drawBars(
                in: context,
                size: size,
                samples: samples,
                colorForIndex: { _, progress in
                    progress <= playProgress
                        ? themeManager.accentColor
                        : themeManager.accentColor.opacity(0.3)
                }
            )
        }
    }

    private var seekGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let progress = max(0, min(1, value.location.x / viewWidth))
                onSeek(progress * duration)
            }
    }

    private func loadWaveform() async {
        sourceWaveformData = []

        do {
            let samples = try await WaveformExtractor.extractBars(from: recording.fileURL, bars: 512)
            guard !Task.isCancelled else { return }
            sourceWaveformData = samples
        } catch {
            #if DEBUG
            print("Failed to load waveform: \(error)")
            #endif
        }
    }
}
