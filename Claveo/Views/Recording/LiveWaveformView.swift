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
    var barColor: Color = .white

    init(audioLevels: [Float], maxBars: Int = 50, barColor: Color = .white) {
        self.maxBars = maxBars
        self.barColor = barColor
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
            let maxFit = max(1, Int((size.width + spacing) / step))
            let barsToShow = min(maxBars, maxFit)
            let contentWidth = CGFloat(barsToShow) * step - spacing
            let startX = max(0, (size.width - contentWidth) / 2)
            let midY = size.height / 2

            if audioLevels.isEmpty {
                for index in 0..<barsToShow {
                    let x = startX + CGFloat(index) * step
                    let rect = CGRect(x: x, y: midY - 1.5, width: barWidth, height: 3)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(barColor.opacity(0.2))
                    )
                }
                return
            }

            let levels = Array(audioLevels.suffix(barsToShow))

            for (index, level) in levels.enumerated() {
                let height = barHeight(for: level, in: size.height)
                let x = startX + CGFloat(index) * step
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(barColor))
            }

            if levels.count < barsToShow {
                for index in levels.count..<barsToShow {
                    let x = startX + CGFloat(index) * step
                    let rect = CGRect(x: x, y: midY - 1.5, width: barWidth, height: 3)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(barColor.opacity(0.2))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func barHeight(for level: Float, in totalHeight: CGFloat) -> CGFloat {
        let clamped = CGFloat(max(0, min(1, level)))
        guard clamped > 0.06 else { return 3 }
        let curved = pow(clamped, 0.8)
        return max(3, curved * totalHeight)
    }
}
