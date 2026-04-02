//
//  KeySignatureIdentificationVexStaffView.swift
//  Claveo
//
//  Treble staff + key signature only (no notes), via VexFoundation.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import VexFoundation

/// Treble clef + key signature: **auto-width stave** (no long empty staff after the signature) and a **SwiftUI canvas
/// sized from the key** so the bitmap is only slightly wider than the engraving.
struct KeySignatureIdentificationVexStaffView: View {
    let vexKeySpec: String
    /// Count of sharps or flats in the signature (same for relative major/minor pairs).
    let accidentalCount: Int

    var body: some View {
        GeometryReader { geo in
            let maxW = Double(max(geo.size.width, 80))
            let s = NoteIdentificationStaffMetrics.engravingStaveSpace(innerWidth: maxW)
            let logicalH = NoteIdentificationStaffMetrics.canvasHeight(engravingStaveSpace: s)
            let drawY = NoteIdentificationStaffMetrics.verticalDrawOffset(canvasHeight: logicalH, engravingStaveSpace: s)
            let k = NoteIdentificationStaffMetrics.vexContentScale

            let n = max(0, min(7, accidentalCount))
            /// Generous room for clef + accidentals (engraving stays comfortable via normal clef padding below).
            let contentEstimate = 58 + s * 1.15 + Double(n) * s * 0.50 + 58
            let canvasClipPad: Double = 6
            let desiredLogicalW = max(112, contentEstimate + canvasClipPad)
            /// `VexCanvas` size is in **points**; Vex draws in logical space then `scale(k,k)`. Never let
            /// `logicalW * k` exceed the row (leading gutter + trailing breathing room) or the canvas spills off-screen.
            let leading = Double(Self.cardLeadingGutter)
            let maxPixelW = max(72, Double(geo.size.width) - leading - 12)
            let desiredPixelW = desiredLogicalW * k
            let pixelW = min(desiredPixelW, maxPixelW)
            let canvasLogicalW = pixelW / k
            let pixelH = logicalH * k

            HStack(spacing: 0) {
                Color.clear.frame(width: Self.cardLeadingGutter)
                VexCanvas(width: pixelW, height: pixelH) { ctx in
                    ctx.clear()
                    ctx.save()
                    _ = ctx.scale(k, k)
                    FontLoader.loadDefaultFonts()

                    let f = Factory(options: FactoryOptions(
                        staveSpace: s,
                        width: max(canvasLogicalW + 28, 140),
                        height: logicalH
                    ))
                    _ = f.setContext(ctx)

                    let ghostVoice = f.Voice()
                    _ = ghostVoice.addTickables([f.GhostNote(duration: .whole)])

                    let system = f.System(options: SystemOptions(
                        factory: f,
                        autoWidth: true,
                        x: 6,
                        y: drawY,
                        noJustification: true
                    ))

                    let stave = system.addStave(SystemStave(
                        voices: [ghostVoice]
                    ))
                    _ = stave.addClef(.treble).addKeySignature(vexKeySpec)
                    if let clefMod = stave.getModifiers(position: .begin, category: Clef.category).first as? Clef {
                        _ = clefMod.setPadding(10 + 12)
                    }

                    system.format()
                    try? f.draw()
                    _ = ctx.restore()
                }
                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private static let cardLeadingGutter: CGFloat = 52
}
