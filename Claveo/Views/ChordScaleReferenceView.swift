//
//  ChordScaleReferenceView.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct ChordScaleReferenceView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedRoot = 0
    @State private var useFlats = false

    // MARK: - Derived

    /// Root of the relative minor key (major 6th = +9 semitones).
    private var relativeMinorRoot: Int { (selectedRoot + 9) % 12 }

    private var rootName: String { noteNameFor(selectedRoot) }
    private var relativeMinorName: String { noteNameFor(relativeMinorRoot) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    accidentalPicker
                    rootPicker
                    scaleSection(
                        title: "\(rootName) Major Scale",
                        notes: scaleNotes(from: selectedRoot, intervals: Self.majorIntervals),
                        degrees: Self.scaleDegreeNumerals
                    )
                    scaleSection(
                        title: "\(relativeMinorName) Natural Minor Scale  ·  relative minor of \(rootName)",
                        notes: scaleNotes(from: relativeMinorRoot, intervals: Self.minorIntervals),
                        degrees: Self.scaleDegreeNumerals
                    )
                    chordSection(
                        title: "\(rootName) Major — Diatonic Chords",
                        root: selectedRoot,
                        intervals: Self.majorIntervals,
                        qualities: Self.majorDiatonic
                    )
                    chordSection(
                        title: "\(relativeMinorName) Minor — Diatonic Chords  ·  relative minor",
                        root: relativeMinorRoot,
                        intervals: Self.minorIntervals,
                        qualities: Self.minorDiatonic
                    )
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Chord & Scale Reference")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Accidental toggle

    private var accidentalPicker: some View {
        HStack(spacing: 0) {
            ForEach(["Sharps  ♯", "Flats  ♭"].indices, id: \.self) { i in
                let isSelected = useFlats == (i == 1)
                Button { useFlats = (i == 1) } label: {
                    Text(["Sharps  ♯", "Flats  ♭"][i])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? themeManager.accentColor : Color.clear)
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Root picker

    private var rootPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<12, id: \.self) { root in
                    let isSelected = selectedRoot == root
                    let relMinor = (root + 9) % 12
                    Button {
                        selectedRoot = root
                    } label: {
                        VStack(spacing: 2) {
                            Text(noteNameFor(root))
                                .font(.subheadline.weight(.semibold))
                            Text("\(noteNameFor(relMinor))m")
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                        .frame(minWidth: 52, minHeight: 52)
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
                            Text(noteNameFor(pitch))
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

            Text(noteNameFor(degreeRoot) + quality.suffix)
                .font(.title3.weight(.bold))

            HStack(spacing: 4) {
                ForEach(triad, id: \.self) { pitch in
                    Text(noteNameFor(pitch))
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

    /// Returns the display name for a pitch respecting the current sharps/flats setting.
    private func noteNameFor(_ pitch: Int) -> String {
        useFlats ? Self.flatNames[pitch] : Self.sharpNames[pitch]
    }

    private func scaleNotes(from root: Int, intervals: [Int]) -> [Int] {
        intervals.map { (root + $0) % 12 }
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
        let majorNumerals = ["I", "ii", "iii", "IV",  "V",  "vi",  "vii°"]
        let minorNumerals = ["i", "ii°", "III", "iv", "v",  "VI",  "VII"]
        return isMajorContext ? majorNumerals[degree] : minorNumerals[degree]
    }
}

#Preview {
    ChordScaleReferenceView()
        .environmentObject(ThemeManager.shared)
}
