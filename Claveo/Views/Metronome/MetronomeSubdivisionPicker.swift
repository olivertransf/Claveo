//
//  MetronomeSubdivisionPicker.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct MetronomeSubdivisionPicker: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    let selection: MetronomeSubdivision
    let onSelect: (MetronomeSubdivision) -> Void

    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 108), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Subdivisions", systemImage: "music.note.list")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(MetronomeSubdivision.allCases) { subdivision in
                    let isSelected = subdivision == selection
                    Button {
                        HapticFeedback.lightImpact()
                        onSelect(subdivision)
                    } label: {
                        subdivisionCell(subdivision: subdivision, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel(subdivision.localizedName)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func subdivisionCell(subdivision: MetronomeSubdivision, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        return ZStack {
            shape
                .fill(cellFill(isSelected: isSelected))

            shape
                .strokeBorder(
                    isSelected ? themeManager.accentColor : Color(.systemGray4),
                    lineWidth: isSelected ? 2.5 : 2
                )

            MetronomeSubdivisionGlyph(subdivision: subdivision)
                .foregroundStyle(glyphColor(selected: isSelected))
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
    }

    private func cellFill(isSelected: Bool) -> Color {
        if isSelected {
            return themeManager.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.14)
        }
        return Color(.tertiarySystemFill)
    }

    private func glyphColor(selected: Bool) -> Color {
        if selected {
            return themeManager.accentColorOption == .yellow ? .primary : themeManager.accentColor
        }
        return .primary
    }
}

struct MetronomeSubdivisionGlyph: View {
    let subdivision: MetronomeSubdivision

    var body: some View {
        Canvas { context, size in
            draw(subdivision, in: context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func draw(_ subdivision: MetronomeSubdivision, in context: GraphicsContext, size: CGSize) {
        let noteCount: Int
        let dottedIndices: Set<Int>
        switch subdivision {
        case .quarter:
            noteCount = 1
            dottedIndices = []
        case .eighths:
            noteCount = 2
            dottedIndices = []
        case .triplet:
            noteCount = 3
            dottedIndices = []
        case .sixteenths, .eighthsThenSixteenths, .sixteenthsThenEighths:
            noteCount = 4
            dottedIndices = []
        case .dottedEighthSixteenth:
            noteCount = 2
            dottedIndices = [0]
        case .sixteenthDottedEighth:
            noteCount = 2
            dottedIndices = [1]
        }

        let hasTriplet = subdivision == .triplet

        let headWidth: CGFloat = 8
        let headHeight: CGFloat = 5.8
        let stemXOffset = headWidth * 0.36
        let stemLength: CGFloat = 16
        let headY = size.height * 0.68
        let beamY = headY - stemLength
        let xs = noteXs(
            count: noteCount,
            width: size.width,
            dottedIndices: dottedIndices
        )

        for (index, x) in xs.enumerated() {
            let isDownbeat = index == 0
            let noteWidth = isDownbeat ? headWidth * 1.12 : headWidth
            let noteHeight = isDownbeat ? headHeight * 1.12 : headHeight
            let stemWidth: CGFloat = isDownbeat ? 1.85 : 1.6
            drawNotehead(in: context, center: CGPoint(x: x, y: headY), width: noteWidth, height: noteHeight)
            var stem = Path()
            stem.move(to: CGPoint(x: x + stemXOffset, y: headY - 0.2))
            stem.addLine(to: CGPoint(x: x + stemXOffset, y: beamY))
            context.stroke(stem, with: .foreground, lineWidth: stemWidth)

            if dottedIndices.contains(index) {
                drawDot(in: context, noteX: x, headY: headY, headWidth: noteWidth)
            }
        }

        let stems = xs.map { $0 + stemXOffset }
        let beamHeight: CGFloat = 2.6
        let secondBeamY = beamY + beamHeight + 1.6

        switch subdivision {
        case .quarter:
            break
        case .eighths, .triplet:
            drawBeam(in: context, from: stems.first, to: stems.last, y: beamY, height: beamHeight)
        case .sixteenths:
            drawBeam(in: context, from: stems.first, to: stems.last, y: beamY, height: beamHeight)
            drawBeam(in: context, from: stems.first, to: stems.last, y: secondBeamY, height: beamHeight)
        case .eighthsThenSixteenths:
            drawBeam(in: context, from: stems.first, to: stems.last, y: beamY, height: beamHeight)
            if stems.count == 4 {
                drawBeam(in: context, from: stems[2], to: stems[3], y: secondBeamY, height: beamHeight)
            }
        case .sixteenthsThenEighths:
            drawBeam(in: context, from: stems.first, to: stems.last, y: beamY, height: beamHeight)
            if stems.count == 4 {
                drawBeam(in: context, from: stems[0], to: stems[1], y: secondBeamY, height: beamHeight)
            }
        case .dottedEighthSixteenth:
            drawBeam(in: context, from: stems.first, to: stems.last, y: beamY, height: beamHeight)
            if let right = stems.last, let left = stems.first {
                drawPartialBeam(in: context, fromX: right, towardX: left, y: secondBeamY, height: beamHeight)
            }
        case .sixteenthDottedEighth:
            drawBeam(in: context, from: stems.first, to: stems.last, y: beamY, height: beamHeight)
            if let left = stems.first, let right = stems.last {
                drawPartialBeam(in: context, fromX: left, towardX: right, y: secondBeamY, height: beamHeight)
            }
        }

        if hasTriplet, let first = stems.first, let last = stems.last {
            let label = Text("3").font(.system(size: 9, weight: .bold))
            context.draw(
                context.resolve(label),
                at: CGPoint(x: (first + last) / 2, y: beamY - 6.5),
                anchor: .center
            )
        }
    }

    private func noteXs(count: Int, width: CGFloat, dottedIndices: Set<Int>) -> [CGFloat] {
        if count == 1 {
            return [width / 2]
        }

        let spacing: CGFloat
        switch count {
        case 4:
            spacing = 10
        case 3:
            spacing = 11
        default:
            spacing = 13
        }

        var gaps = Array(repeating: spacing, count: count - 1)
        for index in dottedIndices where index < gaps.count {
            gaps[index] += 3.5
        }

        let groupWidth = gaps.reduce(0, +)
        var x = (width - groupWidth) / 2
        var xs: [CGFloat] = [x]
        for gap in gaps {
            x += gap
            xs.append(x)
        }
        return xs
    }

    private func drawNotehead(in context: GraphicsContext, center: CGPoint, width: CGFloat, height: CGFloat) {
        var context = context
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: .degrees(-18))
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        context.fill(Path(ellipseIn: rect), with: .foreground)
    }

    private func drawBeam(in context: GraphicsContext, from: CGFloat?, to: CGFloat?, y: CGFloat, height: CGFloat) {
        guard let from, let to, from != to else { return }
        let minX = min(from, to)
        let rect = CGRect(x: minX, y: y, width: abs(to - from), height: height)
        context.fill(Path(roundedRect: rect, cornerRadius: height / 2), with: .foreground)
    }

    private func drawPartialBeam(
        in context: GraphicsContext,
        fromX: CGFloat,
        towardX: CGFloat,
        y: CGFloat,
        height: CGFloat
    ) {
        let length = abs(towardX - fromX) * 0.46
        let endX = fromX + (towardX > fromX ? length : -length)
        drawBeam(in: context, from: fromX, to: endX, y: y, height: height)
    }

    private func drawDot(in context: GraphicsContext, noteX: CGFloat, headY: CGFloat, headWidth: CGFloat) {
        let radius = max(1.5, headWidth * 0.18)
        let rect = CGRect(
            x: noteX + headWidth * 0.58,
            y: headY - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .foreground)
    }
}
