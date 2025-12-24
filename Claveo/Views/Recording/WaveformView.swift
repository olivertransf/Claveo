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
    
    var body: some View {
        GeometryReader { geometry in
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if waveformData.isEmpty {
                Text("No waveform data")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let maxAmplitude = waveformData.map { abs($0) }.max() ?? 1.0
                let playProgress = duration > 0 ? currentTime / duration : 0
                
                ZStack(alignment: .leading) {
                    // Waveform - Voice Memos style bars
                    HStack(spacing: 2) {
                        ForEach(Array(waveformData.enumerated()), id: \.offset) { index, amplitude in
                            let normalizedAmplitude = CGFloat(abs(amplitude) / maxAmplitude)
                            let minBarHeight: CGFloat = 2
                            let maxBarHeight = geometry.size.height - 4
                            let barHeight = max(minBarHeight, normalizedAmplitude * maxBarHeight)
                            let isPlayed = CGFloat(index) / CGFloat(waveformData.count) < CGFloat(playProgress)
                            
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(isPlayed ? themeManager.accentColor : themeManager.accentColor.opacity(0.3))
                                .frame(width: 2, height: barHeight)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            let seekTime = progress * duration
                            onSeek(seekTime)
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
                let file = try AVAudioFile(forReading: recording.fileURL)
                guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false) else {
                    await MainActor.run {
                        isLoading = false
                    }
                    return
                }
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
                    await MainActor.run {
                        isLoading = false
                    }
                    return
                }
                
                try file.read(into: buffer)
                
                guard let channelData = buffer.floatChannelData else {
                    await MainActor.run {
                        isLoading = false
                    }
                    return
                }
                
                // Downsample for visualization (take every Nth sample)
                let frameCount = Int(buffer.frameLength)
                guard frameCount > 0 else {
                    await MainActor.run {
                        isLoading = false
                    }
                    return
                }
                
                let downsampleFactor = max(1, frameCount / 200) // Show ~200 bars
                var samples: [Float] = []
                
                for i in stride(from: 0, to: frameCount, by: downsampleFactor) {
                    guard i < frameCount else { break }
                    samples.append(channelData[0][i])
                }
                
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

