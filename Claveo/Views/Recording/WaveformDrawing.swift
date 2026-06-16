//
//  WaveformDrawing.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

enum WaveformDrawing {
    static let defaultBarWidth: CGFloat = 2
    static let defaultSpacing: CGFloat = 2

    /// Bar count that keeps roughly fixed visual pitch for a given width.
    static func barCount(
        for width: CGFloat,
        barWidth: CGFloat = defaultBarWidth,
        spacing: CGFloat = defaultSpacing,
        minimum: Int = 48,
        maximum: Int = 360
    ) -> Int {
        guard width > 0 else { return minimum }
        let pitch = barWidth + spacing
        return min(maximum, max(minimum, Int((width + spacing) / pitch)))
    }

    static func resample(_ samples: [Float], to count: Int) -> [Float] {
        guard count > 0 else { return [] }
        guard !samples.isEmpty else { return Array(repeating: 0, count: count) }
        if samples.count == count { return samples }

        if samples.count > count {
            return resamplePeaks(samples, to: count)
        }

        var result = [Float]()
        result.reserveCapacity(count)
        let lastIndex = samples.count - 1

        for index in 0..<count {
            let position = CGFloat(index) / CGFloat(max(count - 1, 1)) * CGFloat(lastIndex)
            let lower = Int(position)
            let upper = min(lower + 1, lastIndex)
            let fraction = Float(position - CGFloat(lower))
            let value = samples[lower] * (1 - fraction) + samples[upper] * fraction
            result.append(value)
        }

        return result
    }

    /// Downsamples by taking the peak in each bucket so transients stay visible.
    static func resamplePeaks(_ samples: [Float], to count: Int) -> [Float] {
        guard count > 0, !samples.isEmpty else { return [] }
        if samples.count == count { return samples }

        var result = [Float]()
        result.reserveCapacity(count)

        for index in 0..<count {
            let start = index * samples.count / count
            let end = max(start + 1, (index + 1) * samples.count / count)
            let bucket = samples[start..<end]
            result.append(bucket.max() ?? 0)
        }

        return result
    }

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
        let gap = spacing
        let drawBarWidth = max(1, (size.width - gap * CGFloat(count - 1)) / CGFloat(count))
        let drawStep = drawBarWidth + gap
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
