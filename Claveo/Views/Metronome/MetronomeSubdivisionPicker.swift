//
//  MetronomeSubdivisionPicker.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct MetronomeSubdivisionPicker: View {
    @EnvironmentObject var themeManager: ThemeManager

    let selection: MetronomeSubdivision
    let onSelect: (MetronomeSubdivision) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Subdivisions", systemImage: "music.note.list")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(MetronomeSubdivision.allCases) { subdivision in
                    let isSelected = subdivision == selection
                    Button {
                        HapticFeedback.lightImpact()
                        onSelect(subdivision)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isSelected ? themeManager.accentColor : Color.clear)
                                .frame(width: 48, height: 48)

                            MetronomeSubdivisionGlyph(subdivision: subdivision)
                                .foregroundStyle(glyphColor(selected: isSelected))
                                .frame(width: 40, height: 36)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(subdivision.localizedName)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func glyphColor(selected: Bool) -> Color {
        guard selected else { return .primary }
        return themeManager.accentColorOption == .yellow ? .black : .white
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
        switch subdivision {
        case .quarter:
            noteCount = 1
        case .eighths, .dottedEighthSixteenth, .sixteenthDottedEighth:
            noteCount = 2
        case .triplet:
            noteCount = 3
        case .sixteenths:
            noteCount = 4
        }

        let inset = size.width * (noteCount == 1 ? 0.34 : 0.16)
        let xs: [CGFloat]
        if noteCount == 1 {
            xs = [size.width / 2]
        } else {
            xs = (0..<noteCount).map { index in
                inset + CGFloat(index) / CGFloat(noteCount - 1) * (size.width - inset * 2)
            }
        }

        let headWidth = min(size.width * 0.22, 9)
        let headHeight = headWidth * 0.72
        let headY = size.height * 0.66
        let stemTop = size.height * 0.18
        let stemXOffset = headWidth * 0.42

        for x in xs {
            drawNotehead(in: context, center: CGPoint(x: x, y: headY), width: headWidth, height: headHeight)
            var stem = Path()
            stem.move(to: CGPoint(x: x + stemXOffset, y: headY - headHeight * 0.15))
            stem.addLine(to: CGPoint(x: x + stemXOffset, y: stemTop))
            context.stroke(stem, with: .foreground, lineWidth: 1.4)
        }

        switch subdivision {
        case .quarter:
            break
        case .eighths, .triplet:
            drawBeam(in: context, xs: xs, stemXOffset: stemXOffset, y: stemTop + 1.2, width: 2.4)
        case .sixteenths:
            drawBeam(in: context, xs: xs, stemXOffset: stemXOffset, y: stemTop + 1.2, width: 2.2)
            drawBeam(in: context, xs: xs, stemXOffset: stemXOffset, y: stemTop + 5.2, width: 2.2)
        case .dottedEighthSixteenth:
            drawDot(in: context, noteX: xs[0], headY: headY, headWidth: headWidth)
            drawBeam(in: context, xs: xs, stemXOffset: stemXOffset, y: stemTop + 1.2, width: 2.2)
            drawPartialBeam(
                in: context,
                fromX: xs[1] + stemXOffset,
                towardX: xs[0] + stemXOffset,
                y: stemTop + 5.2,
                width: 2.2
            )
        case .sixteenthDottedEighth:
            drawDot(in: context, noteX: xs[1], headY: headY, headWidth: headWidth)
            drawBeam(in: context, xs: xs, stemXOffset: stemXOffset, y: stemTop + 1.2, width: 2.2)
            drawPartialBeam(
                in: context,
                fromX: xs[0] + stemXOffset,
                towardX: xs[1] + stemXOffset,
                y: stemTop + 5.2,
                width: 2.2
            )
        }

        if subdivision == .triplet {
            let label = Text("3").font(.system(size: 9, weight: .bold, design: .rounded))
            context.draw(
                context.resolve(label),
                at: CGPoint(x: size.width / 2, y: max(6, stemTop - 7)),
                anchor: .center
            )
        }
    }

    private func drawNotehead(in context: GraphicsContext, center: CGPoint, width: CGFloat, height: CGFloat) {
        var context = context
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: .degrees(-22))
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        context.fill(Path(ellipseIn: rect), with: .foreground)
    }

    private func drawBeam(in context: GraphicsContext, xs: [CGFloat], stemXOffset: CGFloat, y: CGFloat, width: CGFloat) {
        guard let first = xs.first, let last = xs.last, first != last else { return }
        var path = Path()
        path.move(to: CGPoint(x: first + stemXOffset, y: y))
        path.addLine(to: CGPoint(x: last + stemXOffset, y: y))
        context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func drawPartialBeam(
        in context: GraphicsContext,
        fromX: CGFloat,
        towardX: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) {
        let endX = fromX + (towardX - fromX) * 0.42
        var path = Path()
        path.move(to: CGPoint(x: fromX, y: y))
        path.addLine(to: CGPoint(x: endX, y: y))
        context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func drawDot(in context: GraphicsContext, noteX: CGFloat, headY: CGFloat, headWidth: CGFloat) {
        let radius = max(1.4, headWidth * 0.16)
        let rect = CGRect(
            x: noteX + headWidth * 0.62,
            y: headY - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .foreground)
    }
}
