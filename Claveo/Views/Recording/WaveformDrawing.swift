//
//  WaveformDrawing.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

enum WaveformDrawing {
    static func drawBars(
        in context: GraphicsContext,
        size: CGSize,
        samples: [Float],
        barWidth: CGFloat = 2,
        spacing: CGFloat = 2,
        cornerRadius: CGFloat = 1.5,
        colorForIndex: (Int, CGFloat) -> Color
    ) {
        guard !samples.isEmpty, size.width > 0, size.height > 0 else { return }

        let maxAmp = max(samples.map { abs($0) }.max() ?? 0, 0.0001)
        let count = samples.count
        let step = barWidth + spacing
        let naturalWidth = CGFloat(count) * step - spacing
        let scale = naturalWidth > size.width ? size.width / naturalWidth : 1
        let drawStep = step * scale
        let drawBarWidth = max(1, barWidth * scale)
        let midY = size.height / 2

        for (index, sample) in samples.enumerated() {
            let normalized = CGFloat(abs(sample) / maxAmp)
            let height = max(2, normalized * (size.height - 4))
            let x = CGFloat(index) * drawStep
            let rect = CGRect(
                x: x,
                y: midY - height / 2,
                width: drawBarWidth,
                height: height
            )
            let progress = CGFloat(index) / CGFloat(max(count - 1, 1))
            context.fill(
                Path(roundedRect: rect, cornerRadius: cornerRadius),
                with: .color(colorForIndex(index, progress))
            )
        }
    }

    static func drawTimedBars(
        in context: GraphicsContext,
        size: CGSize,
        bars: [Float],
        duration: TimeInterval,
        selectionStart: TimeInterval,
        selectionEnd: TimeInterval,
        accentColor: Color,
        barWidth: CGFloat = 2
    ) {
        guard duration > 0, !bars.isEmpty, size.width > 0, size.height > 0 else { return }

        let maxAmp = max(bars.map { abs($0) }.max() ?? 0, 0.0001)
        let count = bars.count
        let midY = size.height / 2

        for (index, sample) in bars.enumerated() {
            let time = (Double(index) / Double(max(count - 1, 1))) * duration
            let x = CGFloat(time / duration) * size.width
            let inSelection = time >= selectionStart && time <= selectionEnd
            let normalized = CGFloat(abs(sample) / maxAmp)
            let height = max(2, normalized * (size.height - 4))
            let rect = CGRect(x: x - barWidth / 2, y: midY - height / 2, width: barWidth, height: height)
            context.fill(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(inSelection ? accentColor : accentColor.opacity(0.22))
            )
        }
    }
}
