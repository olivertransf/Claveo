//
//  NoteIdentificationVexStaffView.swift
//  Claveo
//
//  Renders one staff + whole note via VexFoundation (VexFlow-accurate engraving).
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import VexFoundation

/// Staff metrics shared with `NoteIdentificationExerciseView` so the card height matches Vex’s canvas.
///
/// **Important:** Vex scales clefs, noteheads, and accidentals from `FactoryOptions.staveSpace` — not from
/// the SwiftUI frame. We use a generous base spacing plus `engravingBoost` so glyphs are large.
enum NoteIdentificationStaffMetrics {
    /// Uniform zoom for the whole score (clef, notehead, staff, accidentals) via `RenderContext.scale`, like VexFlow `ctx.scale`.
    static let vexContentScale: Double = 1.22

    /// Raw spacing derived from layout width (before boost).
    private static func baseStaveSpace(innerWidth: Double) -> Double {
        min(68, max(40, innerWidth / 3.4))
    }

    /// Extra multiplier applied **only** to `FactoryOptions.staveSpace` so symbols grow without widening the card arbitrarily.
    private static let engravingBoost: Double = 1.28

    /// Value passed to `FactoryOptions(staveSpace:)` — this is what actually scales SMuFL glyphs.
    static func engravingStaveSpace(innerWidth: Double) -> Double {
        min(86, baseStaveSpace(innerWidth: innerWidth) * engravingBoost)
    }

    /// Logical height Vex uses for layout (pre-`vexContentScale`). Slightly taller than `/6`, still compact.
    static func canvasHeight(engravingStaveSpace s: Double) -> Double {
        (s * 5.2 + 22) / 4.28
    }

    /// Minimal top inset: treat the stave block as nearly full-height so less empty band above/below.
    static func verticalDrawOffset(canvasHeight h: Double, engravingStaveSpace s: Double) -> Double {
        let contentSpan = min(s * 3.72, h * 0.993)
        let centered = max(0, (h - contentSpan) / 2)
        // Nudge the system up so there’s extra empty band along the bottom inside the canvas.
        return max(0, centered - s * 0.13)
    }

    /// SwiftUI frame for the staff block (physical points = logical × `vexContentScale`).
    static func notationBlockHeight(innerContentWidth: CGFloat) -> CGFloat {
        let w = Double(max(innerContentWidth, 80))
        let s = engravingStaveSpace(innerWidth: w)
        let logicalH = canvasHeight(engravingStaveSpace: s)
        return CGFloat(logicalH * vexContentScale)
    }
}

/// Single-line EasyScore (e.g. `C#5/w`) with a chosen clef.
struct NoteIdentificationVexStaffView: View {
    let clef: ClefName
    let easyScoreLine: String

    var body: some View {
        GeometryReader { geo in
            let maxW = Double(max(geo.size.width, 80))
            let s = NoteIdentificationStaffMetrics.engravingStaveSpace(innerWidth: maxW)
            let logicalH = NoteIdentificationStaffMetrics.canvasHeight(engravingStaveSpace: s)
            /// Base content width; `staveTotalW` adds trailing space before the end barline.
            let contentMaxW = max(72, min(maxW * 0.31, 134))
            let gapBeforeEndBar: Double = 18 + s * 0.12
            let staveTotalW = contentMaxW + gapBeforeEndBar
            let drawY = NoteIdentificationStaffMetrics.verticalDrawOffset(canvasHeight: logicalH, engravingStaveSpace: s)
            let k = NoteIdentificationStaffMetrics.vexContentScale
            let pixelW = staveTotalW * k
            let pixelH = logicalH * k

            let noteOpts: [String: String] = ["clef": clef.rawValue]

            HStack {
                Spacer(minLength: 0)
                VexCanvas(width: pixelW, height: pixelH) { ctx in
                    ctx.clear()
                    ctx.save()
                    _ = ctx.scale(k, k)
                    FontLoader.loadDefaultFonts()

                    let f = Factory(options: FactoryOptions(staveSpace: s, width: staveTotalW, height: logicalH))
                    _ = f.setContext(ctx)
                    let score = f.EasyScore()

                    // Fixed width (not auto) so `justifyWidth` includes `gapBeforeEndBar` between the note and the end barline.
                    let system = f.System(options: SystemOptions(
                        factory: f,
                        autoWidth: false,
                        x: 6,
                        width: staveTotalW,
                        y: drawY
                    ))

                    let stave = system.addStave(SystemStave(
                        voices: [score.voice(score.notes(easyScoreLine, options: noteOpts))]
                    ))
                    _ = stave.addClef(clef)
                    if let clefMod = stave.getModifiers(position: .begin, category: Clef.category).first as? Clef {
                        _ = clefMod.setPadding(10 + 12)
                    }

                    system.format()
                    try? f.draw()
                    _ = ctx.restore()
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
