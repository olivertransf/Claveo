//
//  LiveWaveformView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct LiveWaveformView: View {
    let audioLevels: [Float]
    let maxBars: Int

    init(audioLevels: [Float], maxBars: Int = 50) {
        self.maxBars = maxBars
        if audioLevels.count > maxBars {
            self.audioLevels = Array(audioLevels.suffix(maxBars))
        } else {
            self.audioLevels = audioLevels
        }
    }

    var body: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 3
            let spacing: CGFloat = 2.5
            let step = barWidth + spacing
            let maxFit = max(1, Int((size.width - spacing) / step))
            let barsToShow = min(maxBars, maxFit)

            if audioLevels.isEmpty {
                for index in 0..<barsToShow {
                    let x = CGFloat(index) * step
                    let rect = CGRect(x: x, y: size.height / 2 - 1.5, width: barWidth, height: 3)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(.white.opacity(0.2))
                    )
                }
                return
            }

            let levels = Array(audioLevels.suffix(barsToShow))
            let maxAmp = max(levels.max() ?? 0.001, 0.001)
            let midY = size.height / 2

            for (index, level) in levels.enumerated() {
                let amplified = pow(CGFloat(level / maxAmp), 0.4) * 2.5
                let height = min(size.height, max(3, amplified * size.height))
                let x = CGFloat(index) * step
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(.white))
            }

            if levels.count < barsToShow {
                for index in levels.count..<barsToShow {
                    let x = CGFloat(index) * step
                    let rect = CGRect(x: x, y: midY - 1.5, width: barWidth, height: 3)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(.white.opacity(0.2))
                    )
                }
            }
        }
    }
}
