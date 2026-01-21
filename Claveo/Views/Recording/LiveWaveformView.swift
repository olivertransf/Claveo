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
            let availableWidth = geometry.size.width
            let barWidth: CGFloat = 3
            let barSpacing: CGFloat = 2.5
            let totalBarWidth = barWidth + barSpacing
            let maxBarsThatFit = Int((availableWidth - barSpacing) / totalBarWidth)
            let barsToShow = min(maxBars, maxBarsThatFit)
            
            if audioLevels.isEmpty {
                HStack(spacing: barSpacing) {
                    ForEach(0..<barsToShow, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: barWidth, height: 3)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                let levelsToShow = Array(audioLevels.suffix(barsToShow))
                
                HStack(spacing: barSpacing) {
                    ForEach(Array(levelsToShow.enumerated()), id: \.offset) { index, level in
                        let normalizedLevel = CGFloat(level)
                        let minBarHeight: CGFloat = 3
                        let maxBarHeight = geometry.size.height
                        let amplifiedLevel = pow(normalizedLevel, 0.4)
                        let sensitivityBoost: CGFloat = 2.5
                        let barHeight = max(minBarHeight, amplifiedLevel * maxBarHeight * sensitivityBoost)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: barWidth, height: min(barHeight, maxBarHeight))
                    }
                    
                    if levelsToShow.count < barsToShow {
                        ForEach(levelsToShow.count..<barsToShow, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.2))
                                .frame(width: barWidth, height: 3)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

