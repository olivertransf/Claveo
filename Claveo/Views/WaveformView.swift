//
//  WaveformView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI
import AVFoundation

struct WaveformView: View {
    let recording: Recording
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
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
                ZStack(alignment: .leading) {
                    // Waveform
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let samples = waveformData.count
                        let sampleWidth = width / CGFloat(samples)
                        
                        path.move(to: CGPoint(x: 0, y: height / 2))
                        
                        for (index, amplitude) in waveformData.enumerated() {
                            let x = CGFloat(index) * sampleWidth
                            let normalizedAmplitude = CGFloat(abs(amplitude))
                            let barHeight = normalizedAmplitude * height * 0.8
                            let y = (height - barHeight) / 2
                            
                            path.addLine(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x, y: y + barHeight))
                            path.addLine(to: CGPoint(x: x + sampleWidth, y: y + barHeight))
                            path.addLine(to: CGPoint(x: x + sampleWidth, y: y))
                        }
                        
                        path.addLine(to: CGPoint(x: width, y: height / 2))
                    }
                    .fill(Color.themeAccent.opacity(0.6))
                    
                    // Playback position indicator
                    if duration > 0 {
                        Rectangle()
                            .fill(Color.themeAccent.opacity(0.5))
                            .frame(width: 2)
                            .offset(x: CGFloat(currentTime / duration) * geometry.size.width - 1)
                    }
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
        .frame(height: 60)
        .onAppear {
            loadWaveform()
        }
    }
    
    private func loadWaveform() {
        Task {
            do {
                let file = try AVAudioFile(forReading: recording.fileURL)
                let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false)!
                
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
                let downsampleFactor = max(1, frameCount / 200) // Show ~200 bars
                var samples: [Float] = []
                
                for i in stride(from: 0, to: frameCount, by: downsampleFactor) {
                    samples.append(channelData[0][i])
                }
                
                await MainActor.run {
                    waveformData = samples
                    isLoading = false
                }
            } catch {
                print("Failed to load waveform: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

