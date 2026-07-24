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
    @State private var keyMode: KeyReferenceMode = .major

    private enum KeyReferenceMode: String, CaseIterable, Identifiable {
        case major = "Major"
        case relativeMinor = "Minor"

        var id: String { rawValue }
    }

    // MARK: - Derived

    private var relativeMinorRoot: Int { (selectedRoot + 9) % 12 }

    private var rootName: String { noteNameFor(selectedRoot) }
    private var relativeMinorName: String { noteNameFor(relativeMinorRoot) }

    private var activeScaleRoot: Int {
        keyMode == .major ? selectedRoot : relativeMinorRoot
    }

    private var activeIntervals: [Int] {
        keyMode == .major ? Self.majorIntervals : Self.minorIntervals
    }

    private var activeDiatonicQualities: [ChordQuality] {
        keyMode == .major ? Self.majorDiatonic : Self.minorDiatonic
    }

    private var activeKeyTitle: String {
        keyMode == .major
            ? String(localized: "\(rootName) Major")
            : String(localized: "\(relativeMinorName) Natural Minor")
    }

    private var activeKeySubtitle: String {
        if keyMode == .major {
            return String(localized: "Relative minor: \(relativeMinorName) minor — same notes, different tonic.")
        }
        return String(localized: "Relative major: \(rootName) major — same notes, different tonic.")
    }

    private var scaleSectionTitle: String {
        String(localized: "Scale notes")
    }

    private var scaleSectionFooter: String {
        if keyMode == .major {
            return String(localized: "1 is the tonic (home note). 5 is the dominant — it often leads back to 1. 7 is the leading tone, a half step below the tonic.")
        }
        return String(localized: "Natural minor lowers the 3rd, 6th, and 7th compared to major. Same letter names as \(rootName) major, different tonic.")
    }

    private var chordSectionTitle: String {
        String(localized: "Chords in this key")
    }

    private var chordSectionFooter: String {
        String(localized: "Each chord is built by stacking thirds on a scale degree. Roman numerals show its role in the key.")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    accidentalPicker
                    rootPicker
                    keySummaryCard
                    modePicker

                    referenceCard(title: scaleSectionTitle, footer: scaleSectionFooter) {
                        scaleRow(
                            notes: scaleNotes(from: activeScaleRoot, intervals: activeIntervals)
                        )
                    }

                    referenceCard(title: chordSectionTitle, footer: chordSectionFooter) {
                        chordGrid(
                            root: activeScaleRoot,
                            intervals: activeIntervals,
                            qualities: activeDiatonicQualities
                        )
                    }
                }
                .padding(.vertical, 16)
                .animation(.easeInOut(duration: 0.2), value: selectedRoot)
                .animation(.easeInOut(duration: 0.2), value: keyMode)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Chords & Scales")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Pickers

    private var accidentalPicker: some View {
        let titles = [String(localized: "Sharps  ♯"), String(localized: "Flats  ♭")]
        return HStack(spacing: 0) {
            ForEach(titles.indices, id: \.self) { i in
                let isSelected = useFlats == (i == 1)
                Button { useFlats = (i == 1) } label: {
                    Text(titles[i])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? themeManager.accentColor : Color.clear)
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
        .padding(.horizontal, 16)
    }

    private var rootPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose a key")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<12, id: \.self) { root in
                        let isSelected = selectedRoot == root
                        Button {
                            selectedRoot = root
                            if Self.flatRoots.contains(root) {
                                useFlats = true
                            }
                        } label: {
                            Text(noteNameFor(root))
                                .font(.subheadline.weight(.semibold))
                                .frame(minWidth: 44, minHeight: 44)
                                .padding(.horizontal, 6)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(isSelected ? themeManager.accentColor : Color(.tertiarySystemFill))
                                )
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .accessibilityLabel(String(localized: "\(noteNameFor(root)) major"))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var keySummaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(activeKeyTitle)
                .font(.title2.weight(.bold))
                .contentTransition(.numericText())

            Text(activeKeySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    private var modePicker: some View {
        Picker("Key type", selection: $keyMode) {
            Text(String(localized: "\(rootName) Major")).tag(KeyReferenceMode.major)
            Text(String(localized: "\(relativeMinorName) Minor")).tag(KeyReferenceMode.relativeMinor)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }

    // MARK: - Cards

    private func referenceCard<Content: View>(
        title: String,
        footer: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()

            Text(footer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .padding(.horizontal, 16)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }

    // MARK: - Scale

    private func scaleRow(notes: [Int]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(notes.enumerated()), id: \.offset) { index, pitch in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(index == 0
                                  ? themeManager.accentColor
                                  : Color(.tertiarySystemFill))
                        Circle()
                            .strokeBorder(
                                index == 0
                                    ? Color.clear
                                    : Color.primary.opacity(0.12),
                                lineWidth: 1
                            )
                        Text(noteNameFor(pitch))
                            .font(.body.weight(.semibold))
                            .minimumScaleFactor(0.65)
                            .lineLimit(1)
                            .foregroundStyle(index == 0 ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(minHeight: 60)

                    Text("\(index + 1)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(index == 0 ? themeManager.accentColor : .secondary)
                        .frame(height: 14)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    String(localized: "Scale degree \(index + 1), \(noteNameFor(pitch))")
                )
            }
        }
    }

    // MARK: - Chords

    private func chordGrid(
        root: Int,
        intervals: [Int],
        qualities: [ChordQuality]
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(0..<7, id: \.self) { degreeIndex in
                chordCard(
                    degreeIndex: degreeIndex,
                    scaleRoot: root,
                    scaleIntervals: intervals,
                    quality: qualities[degreeIndex]
                )
            }
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
        let chordName = noteNameFor(degreeRoot) + quality.suffix

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(chordName)
                    .font(.title3.weight(.bold))
                Spacer(minLength: 4)
                Text(numeral)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(themeManager.accentColor)
            }

            Text(String(localized: "Scale degree \(degreeIndex + 1)"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("Notes")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                ForEach(triad, id: \.self) { pitch in
                    Text(noteNameFor(pitch))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                localized: "\(chordName), scale degree \(degreeIndex + 1), \(triad.map(noteNameFor).joined(separator: ", "))"
            )
        )
    }

    // MARK: - Helpers

    private func noteNameFor(_ pitch: Int) -> String {
        useFlats ? Self.flatNames[pitch] : Self.sharpNames[pitch]
    }

    private func scaleNotes(from root: Int, intervals: [Int]) -> [Int] {
        intervals.map { (root + $0) % 12 }
    }

    // MARK: - Static data

    static let sharpNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    static let flatNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    static let flatRoots: Set<Int> = [5, 10, 3, 8, 1, 6]

    static let majorIntervals = [0, 2, 4, 5, 7, 9, 11]
    static let minorIntervals = [0, 2, 3, 5, 7, 8, 10]

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
        case .major: return ""
        case .minor: return "m"
        case .diminished: return "°"
        }
    }

    func triad(from root: Int) -> [Int] {
        switch self {
        case .major: return [root, (root + 4) % 12, (root + 7) % 12]
        case .minor: return [root, (root + 3) % 12, (root + 7) % 12]
        case .diminished: return [root, (root + 3) % 12, (root + 6) % 12]
        }
    }

    func numeral(for degree: Int, isMajorContext: Bool) -> String {
        let majorNumerals = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
        let minorNumerals = ["i", "ii°", "III", "iv", "v", "VI", "VII"]
        return isMajorContext ? majorNumerals[degree] : minorNumerals[degree]
    }
}

#Preview {
    ChordScaleReferenceView()
        .environmentObject(ThemeManager.shared)
}
