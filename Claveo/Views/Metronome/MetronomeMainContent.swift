//
//  MetronomeView+MainContent.swift
//  Claveo
//
//  Main metronome UI extracted from MetronomeView.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

extension MetronomeView {
    var mainContentView: some View {
        ScrollView {
            Group {
                if isIPad {
                    iPadMetronomeLayout
                } else {
                    phoneMetronomeLayout
                }
            }
            .padding(.bottom, isIPad ? 40 : 24)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Metronome")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingVolumeSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Metronome Settings")
            }
        }
        .sheet(isPresented: $showingTemposManagement) {
            TemposManagementView(
                tempos: Binding(
                    get: { settingsManager.settings.favoriteTempos },
                    set: { settingsManager.update(\.favoriteTempos, value: $0) }
                )
            )
            .environmentObject(themeManager)
        }
        .onAppear {
            syncSettingsFromManager()
            syncNoteSelection()
        }
        .onChange(of: metronome.soundType) { _, _ in
            settingsManager.setMetronomeSound(metronome.soundType)
        }
        .onChange(of: metronome.hapticEnabled) { _, _ in
            settingsManager.update(\.metronomeHapticEnabled, value: metronome.hapticEnabled)
        }
        .onChange(of: metronome.tempo) { _, newValue in
            let tempoToSave = newValue
            Task { @MainActor [weak metronome] in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let metronome = metronome, metronome.tempo == tempoToSave else { return }
                settingsManager.update(\.lastMetronomeTempo, value: tempoToSave)
            }
        }
        .onChange(of: settingsManager.settings.metronomeSound) { _, _ in
            syncSettingsFromManager()
        }
        .onChange(of: settingsManager.settings.metronomeHapticEnabled) { _, _ in
            syncSettingsFromManager()
        }
    }

    // MARK: - iPhone

    private var phoneMetronomeLayout: some View {
        VStack(spacing: 16) {
            metronomeHeroCard
            metronomeDetailsCard
            toneGeneratorSection(compact: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - iPad

    private var iPadMetronomeLayout: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                metronomeHeroCard
                    .frame(maxWidth: .infinity)

                metronomeDetailsCard
                    .frame(maxWidth: .infinity)
            }

            toneGeneratorPanel {
                HStack(alignment: .top, spacing: 28) {
                    toneGeneratorControlsColumn
                        .frame(maxWidth: .infinity)

                    toneGeneratorKeyboardColumn
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
    }

    private func toneGeneratorPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Tone Generator", systemImage: "waveform.path")
            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Metronome cards

    private var metronomeHeroCard: some View {
        VStack(spacing: 18) {
            HStack {
                Label("Tempo", systemImage: "metronome")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: toggleFavoriteTempo) {
                    Image(systemName: favoriteTempos.contains(metronome.tempo) ? "star.fill" : "star")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(favoriteTempos.contains(metronome.tempo) ? .yellow : .secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    favoriteTempos.contains(metronome.tempo) ? "Remove from Favorites" : "Add to Favorites"
                )
            }

            HStack(alignment: .center, spacing: 16) {
                tempoStepButton(delta: -1)
                tempoDisplay
                tempoStepButton(delta: 1)
            }

            Button(action: toggleMetronomePlayback) {
                Label(
                    metronome.isPlaying ? "Stop" : "Start",
                    systemImage: metronome.isPlaying ? "stop.fill" : "play.fill"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    metronome.isPlaying ? Color.red : themeManager.accentColor,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(metronome.isPlaying ? "Stop Metronome" : "Start Metronome")

            tempoSliderControl
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private var metronomeDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                compactMetronomeButton(title: "Tap Tempo", systemImage: "hand.tap", action: tapTempo)
                timeSignatureMenu
            }

            beatPatternSection

            if !favoriteTempos.isEmpty {
                favoriteTemposSection
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private func compactMetronomeButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tempoStepButton(delta: Int) -> some View {
        Button {
            HapticFeedback.lightImpact()
            metronome.tempo = max(20, min(300, metronome.tempo + delta))
        } label: {
            Image(systemName: delta < 0 ? "minus" : "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(themeManager.accentColor)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta < 0 ? "Decrease tempo" : "Increase tempo")
    }

    // MARK: - Shared metronome blocks

    private var tempoDisplay: some View {
        VStack(spacing: 2) {
            Text("\(metronome.tempo)")
                .font(.system(size: isIPad ? 88 : 64, weight: .light, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("BPM")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var tempoSliderControl: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { Double(metronome.tempo) },
                    set: { metronome.tempo = Int($0) }
                ),
                in: 20...300,
                step: 1
            )
            .tint(themeManager.accentColor)

            HStack {
                Text("20")
                Spacer()
                Text("300")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var timeSignatureMenu: some View {
        Menu {
            ForEach(TimeSignature.allCases, id: \.self) { signature in
                Button {
                    metronome.setTimeSignature(signature)
                } label: {
                    HStack {
                        Text(signature.rawValue)
                        if metronome.customTimeSignature == nil, metronome.timeSignature == signature {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(themeManager.accentColor)
                        }
                    }
                }
            }

            Divider()

            Button {
                prepareCustomTimeSignature()
            } label: {
                HStack {
                    Text("Custom…")
                    Spacer()
                    if metronome.customTimeSignature != nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(themeManager.accentColor)
                    }
                }
            }

            if metronome.customTimeSignature != nil {
                Button("Clear Custom", role: .destructive) {
                    metronome.setTimeSignature(.fourFour)
                }
            }
        } label: {
            Label(metronome.displayTimeSignature, systemImage: "music.note")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var beatPatternSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Beat Pattern", systemImage: "circle.grid.3x3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            let columns = Array(
                repeating: GridItem(.flexible(), spacing: 10),
                count: max(metronome.beatPattern.count, 1)
            )
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(metronome.beatPattern.enumerated()), id: \.offset) { index, isAccented in
                    Button {
                        toggleBeat(index)
                    } label: {
                        beatPatternCell(index: index, isAccented: isAccented)
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Beat \(index + 1)")
                    .accessibilityValue(beatAccessibilityValue(index: index, isAccented: isAccented))
                    .accessibilityAddTraits(isAccented ? .isSelected : [])
                }
            }
        }
    }

    private func beatPatternCell(index: Int, isAccented: Bool) -> some View {
        let isActive = metronome.isPlaying && index == metronome.currentBeat
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        return ZStack {
            shape
                .fill(beatCellFill(isAccented: isAccented, isActive: isActive))

            if !isActive {
                shape
                    .strokeBorder(
                        isAccented ? themeManager.accentColor : Color(.systemGray4),
                        lineWidth: isAccented ? 2.5 : 2
                    )
            }

            Text("\(index + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(beatCellNumberColor(isAccented: isAccented, isActive: isActive))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .scaleEffect(isActive ? 1.03 : 1.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.62), value: isActive)
        .animation(.spring(response: 0.16, dampingFraction: 0.62), value: metronome.currentBeat)
    }

    private func beatCellFill(isAccented: Bool, isActive: Bool) -> Color {
        if isActive {
            return themeManager.accentColor
        }
        if isAccented {
            return themeManager.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.14)
        }
        return Color(.tertiarySystemFill)
    }

    private func beatCellNumberColor(isAccented: Bool, isActive: Bool) -> Color {
        if isActive {
            return .white
        }
        return isAccented ? themeManager.accentColor : .secondary
    }

    private func beatAccessibilityValue(index: Int, isAccented: Bool) -> String {
        if metronome.isPlaying && index == metronome.currentBeat {
            return isAccented ? "Accented, playing" : "Playing"
        }
        return isAccented ? "Accented" : "Normal"
    }

    private var favoriteTemposSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Favorite Tempos", systemImage: "star.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(favoriteTempos, id: \.self) { tempo in
                        Button {
                            HapticFeedback.lightImpact()
                            metronome.tempo = tempo
                        } label: {
                            Text("\(tempo)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(metronome.tempo == tempo ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(
                                            metronome.tempo == tempo
                                                ? themeManager.accentColor
                                                : Color(.tertiarySystemFill)
                                        )
                                }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                removeFavoriteTempo(tempo)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tone generator

    private func toneGeneratorSection(compact: Bool) -> some View {
        Group {
            if compact {
                toneGeneratorPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        toneGeneratorControlsColumn
                        toneGeneratorKeyboardColumn
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    private var toneGeneratorControlsColumn: some View {
        VStack(spacing: 20) {
            Text(String(format: "%.1f Hz", toneGenerator.frequency))
                .font(.system(size: isIPad ? 36 : 28, weight: .medium, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: isIPad ? .leading : .center)

            HStack(spacing: 8) {
                TextField("Manual Hz", text: $manualToneFrequencyText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.claveoInset)
                    .font(.body.monospacedDigit())
                    .focused($isToneFrequencyFocused)
                    .onSubmit { commitManualToneFrequency() }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                commitManualToneFrequency()
                                isToneFrequencyFocused = false
                            }
                        }
                    }

                Button("Apply") {
                    HapticFeedback.lightImpact()
                    commitManualToneFrequency()
                }
                .buttonStyle(.bordered)
                .tint(themeManager.accentColor)
            }

            Button {
                HapticFeedback.lightImpact()
                if toneGenerator.isPlaying {
                    toneGenerator.stop()
                } else {
                    toneGenerator.start()
                }
            } label: {
                Label(
                    toneGenerator.isPlaying ? "Stop Tone" : "Play Tone",
                    systemImage: toneGenerator.isPlaying ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.accentColor)
        }
    }

    private var toneGeneratorKeyboardColumn: some View {
        let a4 = settingsManager.settings.a4ReferenceFrequency

        return VStack(alignment: .leading, spacing: 16) {
            toneNoteKeyboard(a4: a4)
            toneOctavePicker(a4: a4)
        }
    }

    private func toneNoteKeyboard(a4: Double) -> some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: toneGridSixColumns, spacing: 10) {
                ForEach(0..<6, id: \.self) { noteIdx in
                    tonePitchButton(noteIndex: noteIdx, a4: a4)
                }
            }
            LazyVGrid(columns: toneGridSixColumns, spacing: 10) {
                ForEach(6..<12, id: \.self) { noteIdx in
                    tonePitchButton(noteIndex: noteIdx, a4: a4)
                }
            }
        }
    }

    private func toneOctavePicker(a4: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Octave")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(1...6, id: \.self) { octave in
                        let selected = selectedToneOctave == octave
                        Button {
                            selectedToneOctave = octave
                            let noteIndex = selectedNoteIndex ?? 0
                            let midi = 24 + (octave - 1) * 12 + noteIndex
                            let hz = ToneGeneratorEngine.midiNoteToHz(midi: midi, a4: a4)
                            toneGenerator.applyFrequency(hz)
                        } label: {
                            Text("\(octave)")
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .frame(minWidth: isIPad ? 52 : 56, minHeight: 48)
                                .padding(.horizontal, 10)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(selected ? themeManager.accentColor : Color(.tertiarySystemFill))
                                }
                                .foregroundStyle(selected ? .white : .primary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func toggleFavoriteTempo() {
        if favoriteTempos.contains(metronome.tempo) {
            removeFavoriteTempo(metronome.tempo)
        } else {
            addFavoriteTempo(metronome.tempo)
        }
    }

    private func toggleMetronomePlayback() {
        if metronome.isPlaying {
            metronome.stop()
        } else {
            metronome.start()
        }
    }

    private static let toneChromaticShortNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    private var toneGridSixColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    }

    private func tonePitchButton(noteIndex: Int, a4: Double) -> some View {
        let name = Self.toneChromaticShortNames[noteIndex]
        let isSelected = selectedNoteIndex == noteIndex
        return Button {
            let midi = 24 + (selectedToneOctave - 1) * 12 + noteIndex
            let hz = ToneGeneratorEngine.midiNoteToHz(midi: midi, a4: a4)
            toneGenerator.applyFrequency(hz)
            selectedNoteIndex = noteIndex
        } label: {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isIPad ? 16 : 14)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? themeManager.accentColor : Color(.tertiarySystemFill))
                }
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }

    func commitManualToneFrequency() {
        let trimmed = manualToneFrequencyText.replacingOccurrences(of: ",", with: ".")
        if let v = Double(trimmed) {
            toneGenerator.applyFrequency(v)
        }
        manualToneFrequencyText = String(format: "%.1f", toneGenerator.frequency)
        syncNoteSelection()
    }
}

// System Volume Slider using MPVolumeView
import MediaPlayer

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsVolumeSlider = true
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
