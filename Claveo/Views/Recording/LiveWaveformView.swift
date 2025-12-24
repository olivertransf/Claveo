//
//  LiveWaveformView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct LiveWaveformView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let audioLevels: [Float]
    let maxBars: Int
    
    init(audioLevels: [Float], maxBars: Int = 50) {
        self.maxBars = maxBars
        // Take the most recent levels if we have more than maxBars
        if audioLevels.count > maxBars {
            self.audioLevels = Array(audioLevels.suffix(maxBars))
        } else {
            self.audioLevels = audioLevels
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            if audioLevels.isEmpty {
                // Show empty waveform with minimal bars
                HStack(spacing: 2) {
                    ForEach(0..<maxBars, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(themeManager.accentColor.opacity(0.2))
                            .frame(width: 2, height: 2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                HStack(spacing: 2) {
                    ForEach(Array(audioLevels.enumerated()), id: \.offset) { index, level in
                        let normalizedLevel = CGFloat(level)
                        let minBarHeight: CGFloat = 2
                        let maxBarHeight = geometry.size.height - 4
                        let barHeight = max(minBarHeight, normalizedLevel * maxBarHeight)
                        
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(themeManager.accentColor)
                            .frame(width: 2, height: barHeight)
                    }
                    
                    // Fill remaining space with empty bars if needed
                    if audioLevels.count < maxBars {
                        ForEach(audioLevels.count..<maxBars, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(themeManager.accentColor.opacity(0.2))
                                .frame(width: 2, height: 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: 40)
    }
}

