//
//  MetronomeSubdivision.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

enum MetronomeSubdivision: String, CaseIterable, Identifiable, Sendable {
    case quarter
    case eighths
    case triplet
    case sixteenths
    case dottedEighthSixteenth
    case sixteenthDottedEighth

    var id: String { rawValue }

    /// Offsets from the start of a beat, in beat units (0...1).
    var beatOffsets: [Double] {
        switch self {
        case .quarter:
            return [0]
        case .eighths:
            return [0, 0.5]
        case .triplet:
            return [0, 1.0 / 3.0, 2.0 / 3.0]
        case .sixteenths:
            return [0, 0.25, 0.5, 0.75]
        case .dottedEighthSixteenth:
            return [0, 0.75]
        case .sixteenthDottedEighth:
            return [0, 0.25]
        }
    }

    var localizedName: String {
        switch self {
        case .quarter:
            return String(localized: "Quarter")
        case .eighths:
            return String(localized: "Eighths")
        case .triplet:
            return String(localized: "Triplet")
        case .sixteenths:
            return String(localized: "Sixteenths")
        case .dottedEighthSixteenth:
            return String(localized: "Dotted eighth and sixteenth")
        case .sixteenthDottedEighth:
            return String(localized: "Sixteenth and dotted eighth")
        }
    }

    func scheduledClicks(
        beatNumber: Int,
        startTime: TimeInterval,
        interval: TimeInterval,
        beatsPerMeasure: Int,
        beatPattern: [Bool],
        now: TimeInterval,
        minimumLead: TimeInterval
    ) -> [MetronomeScheduledClick] {
        let measure = max(1, beatsPerMeasure)
        let beatTime = startTime + Double(beatNumber) * interval
        let beatInMeasure = ((beatNumber % measure) + measure) % measure
        let beatIsAccent = beatInMeasure < beatPattern.count && beatPattern[beatInMeasure]

        return beatOffsets.compactMap { offset in
            let time = beatTime + offset * interval
            guard time >= now + minimumLead else { return nil }
            return MetronomeScheduledClick(
                hostTimeSeconds: time,
                isAccent: offset == 0 && beatIsAccent
            )
        }
    }
}

struct MetronomeScheduledClick: Equatable, Sendable {
    let hostTimeSeconds: TimeInterval
    let isAccent: Bool
}
