//
//  ChordScaleReferenceView.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct ChordScaleReferenceView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedRoot = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    rootPicker
                    scaleSection(title: "\(rootName) Major Scale",
                                 notes: scaleNotes(intervals: Self.majorIntervals),
                                 degrees: Self.scaleDegreeNumerals)
                    scaleSection(title: "\(rootName) Natural Minor Scale",
                                 notes: scaleNotes(intervals: Self.minorIntervals),
                                 degrees: Self.scaleDegreeNumerals)
                    chordSection(title: "\(rootName) Major — Diatonic Chords",
                                 root: selectedRoot,
                                 intervals: Self.majorIntervals,
                                 qualities: Self.majorDiatonic)
                    chordSection(title: "\(rootName) Minor — Diatonic Chords",
                                 root: selectedRoot,
                                 intervals: Self.minorIntervals,
                                 qualities: Self.minorDiatonic)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Chord & Scale Reference")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Root picker

    private var rootPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<12, id: \.self) { root in
                    let isSelected = selectedRoot == root
                    Button { selectedRoot = root } label: {
                        Text(Self.sharpNames[root])
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: 48, minHeight: 44)
                            .padding(.horizontal, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? themeManager.accentColor : Color(.tertiarySystemFill))
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Scale section

    private func scaleSection(title: String, notes: [Int], degrees: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(notes.enumerated()), id: \.offset) { i, pitch in
                        VStack(spacing: 5) {
                            Text(noteName(pitch))
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(i == 0
                                              ? themeManager.accentColor
                                              : Color(.secondarySystemFill))
                                )
                                .foregroundStyle(i == 0 ? .white : .primary)

                            Text(degrees[i])
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Chord section

    private func chordSection(
        title: String,
        root: Int,
        intervals: [Int],
        qualities: [ChordQuality]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 20)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(0..<7, id: \.self) { i in
                    chordCard(
                        degreeIndex: i,
                        scaleRoot: root,
                        scaleIntervals: intervals,
                        quality: qualities[i]
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chordCard(
        degreeIndex: Int,
        scaleRoot: Int,
        scaleIntervals: [Int],
        quality: ChordQuality
    ) -> some View {
        let degreeRoot = (scaleRoot + scaleIntervals[degreeIndex]) % 12
        let triad = quality.triad(from: degreeRoot)
        let numeral = quality.numeral(for: degreeIndex, isMajorContext: scaleIntervals == Self.majorIntervals)

        return VStack(alignment: .leading, spacing: 6) {
            Text(numeral)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(noteName(degreeRoot) + quality.suffix)
                .font(.title3.weight(.bold))

            HStack(spacing: 4) {
                ForEach(triad, id: \.self) { pitch in
                    Text(noteName(pitch))
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                        )
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Helpers

    private var rootName: String { Self.sharpNames[selectedRoot] }

    private func scaleNotes(intervals: [Int]) -> [Int] {
        intervals.map { (selectedRoot + $0) % 12 }
    }

    /// Returns the context-aware note name (sharps vs. flats based on root).
    private func noteName(_ pitch: Int) -> String {
        Self.flatRoots.contains(selectedRoot) ? Self.flatNames[pitch] : Self.sharpNames[pitch]
    }

    // MARK: - Static data

    static let sharpNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
    static let flatNames  = ["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"]
    /// Roots that conventionally use flat notation.
    static let flatRoots: Set<Int> = [5, 10, 3, 8, 1, 6] // F Bb Eb Ab Db Gb

    static let majorIntervals = [0, 2, 4, 5, 7, 9, 11]
    static let minorIntervals = [0, 2, 3, 5, 7, 8, 10]

    static let scaleDegreeNumerals = ["1", "2", "3", "4", "5", "6", "7"]

    fileprivate static let majorDiatonic: [ChordQuality] = [
        .major, .minor, .minor, .major, .major, .minor, .diminished
    ]
    fileprivate static let minorDiatonic: [ChordQuality] = [
        .minor, .diminished, .major, .minor, .minor, .major, .major
    ]
}

// MARK: - Chord quality

fileprivate enum ChordQuality: Equatable {
    case major, minor, diminished

    var suffix: String {
        switch self {
        case .major:      return ""
        case .minor:      return "m"
        case .diminished: return "°"
        }
    }

    /// Root position triad (root, third, fifth).
    func triad(from root: Int) -> [Int] {
        switch self {
        case .major:      return [root, (root + 4) % 12, (root + 7) % 12]
        case .minor:      return [root, (root + 3) % 12, (root + 7) % 12]
        case .diminished: return [root, (root + 3) % 12, (root + 6) % 12]
        }
    }

    /// Roman numeral label for the given scale degree.
    func numeral(for degree: Int, isMajorContext: Bool) -> String {
        let majorNumerals    = ["I", "ii", "iii", "IV",  "V",  "vi",  "vii°"]
        let minorNumerals    = ["i", "ii°", "III", "iv", "v",  "VI",  "VII"]
        return isMajorContext ? majorNumerals[degree] : minorNumerals[degree]
    }
}

#Preview {
    ChordScaleReferenceView()
        .environmentObject(ThemeManager.shared)
}
