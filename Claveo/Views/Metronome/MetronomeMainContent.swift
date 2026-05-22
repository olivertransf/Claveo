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
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Metronome")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingVolumeSheet = true
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
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
        VStack(spacing: 24) {
            tempoDisplay
            playAndFavoriteControls
            VStack(spacing: 20) {
                tempoSliderControl
                metronomeControlsBlock
                toneGeneratorSection(compact: true)
            }
        }
    }

    // MARK: - iPad

    private var iPadMetronomeLayout: some View {
        VStack(spacing: 28) {
            metronomePanel {
                HStack(alignment: .top, spacing: 28) {
                    VStack(spacing: 28) {
                        tempoDisplay
                        playAndFavoriteControls
                        tempoSliderControl
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 24) {
                        metronomeControlsBlock
                    }
                    .frame(maxWidth: .infinity)
                }
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

    private func metronomePanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Metronome", systemImage: "metronome")
            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
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

    // MARK: - Shared metronome blocks

    private var tempoDisplay: some View {
        VStack(spacing: 12) {
            Text("\(metronome.tempo)")
                .font(.system(size: isIPad ? 120 : 96, weight: .light, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()

            Text("BPM")
                .font(isIPad ? .title2 : .title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, isIPad ? 8 : 20)
    }

    private var playAndFavoriteControls: some View {
        HStack(spacing: 24) {
            Button(action: toggleFavoriteTempo) {
                Image(systemName: favoriteTempos.contains(metronome.tempo) ? "star.fill" : "star")
                    .font(.system(size: isIPad ? 36 : 32, weight: .medium))
                    .foregroundStyle(favoriteTempos.contains(metronome.tempo) ? .yellow : themeManager.accentColor)
            }
            .accessibilityLabel(
                favoriteTempos.contains(metronome.tempo) ? "Remove from Favorites" : "Add to Favorites"
            )

            Button(action: toggleMetronomePlayback) {
                Image(systemName: metronome.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: isIPad ? 72 : 72, weight: .light))
                    .foregroundStyle(metronome.isPlaying ? .red : themeManager.accentColor)
            }
            .accessibilityLabel(metronome.isPlaying ? "Stop Metronome" : "Start Metronome")
        }
        .frame(maxWidth: .infinity)
    }

    private var tempoSliderControl: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            HStack(alignment: .center, spacing: isIPad ? 12 : 10) {
                Button {
                    metronome.tempo = max(20, metronome.tempo - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(isIPad ? .title : .title2)
                        .foregroundStyle(themeManager.accentColor)
                }
                .frame(width: isIPad ? 40 : 36, height: isIPad ? 40 : 36)
                .offset(y: -13)

                VStack(spacing: isIPad ? 8 : 6) {
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
                    .font(isIPad ? .caption : .caption2)
                    .foregroundStyle(.secondary)
                }

                Button {
                    metronome.tempo = min(300, metronome.tempo + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(isIPad ? .title : .title2)
                        .foregroundStyle(themeManager.accentColor)
                }
                .frame(width: isIPad ? 40 : 36, height: isIPad ? 40 : 36)
                .offset(y: -13)
            }
        }
        .padding(.horizontal, isIPad ? 0 : 20)
    }

    private var metronomeControlsBlock: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Button(action: tapTempo) {
                    Label("Tap Tempo", systemImage: "hand.tap")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.accentColor)

                timeSignatureMenu
            }

            beatPatternSection

            if !favoriteTempos.isEmpty {
                favoriteTemposSection
            }
        }
        .padding(.horizontal, isIPad ? 0 : 20)
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
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private var beatPatternSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Beat Pattern", systemImage: "circle.grid.3x3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            let columns = [GridItem(.adaptive(minimum: isIPad ? 56 : 52), spacing: 12)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(0..<metronome.beatPattern.count, id: \.self) { index in
                    Button {
                        toggleBeat(index)
                    } label: {
                        Circle()
                            .fill(beatFillColor(for: index))
                            .frame(width: isIPad ? 56 : 52, height: isIPad ? 56 : 52)
                            .overlay {
                                Text("\(index + 1)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(beatLabelColor(for: index))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var favoriteTemposSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Favorite Tempos", systemImage: "star.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favoriteTempos, id: \.self) { tempo in
                        Button {
                            metronome.tempo = tempo
                        } label: {
                            HStack(spacing: 6) {
                                Text("\(tempo)")
                                    .font(.body.weight(.semibold).monospacedDigit())
                                Text("BPM")
                                    .font(.caption2.weight(.medium))
                                    .opacity(0.8)
                            }
                            .foregroundStyle(metronome.tempo == tempo ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        metronome.tempo == tempo
                                            ? themeManager.accentColor
                                            : Color(.systemGray6)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
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
        .padding(.vertical, isIPad ? 0 : 8)
    }

    // MARK: - Tone generator

    private func toneGeneratorSection(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.top, 20)
                        .padding(.bottom, 4)

                    toneSectionHeader

                    toneGeneratorControlsColumn
                    toneGeneratorKeyboardColumn
                }
            } else {
                EmptyView()
            }
        }
    }

    private var toneSectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Tone Generator")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var toneGeneratorControlsColumn: some View {
        let a4 = settingsManager.settings.a4ReferenceFrequency

        return VStack(spacing: 20) {
            Text(String(format: "%.1f Hz", toneGenerator.frequency))
                .font(.system(size: isIPad ? 36 : 28, weight: .medium, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: isIPad ? .leading : .center)

            HStack(spacing: 8) {
                TextField("Manual Hz", text: $manualToneFrequencyText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
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
                    commitManualToneFrequency()
                }
                .buttonStyle(.bordered)
                .tint(themeManager.accentColor)
            }

            Button {
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

            if !isIPad {
                toneNoteKeyboard(a4: a4)
                toneOctavePicker(a4: a4)
            }
        }
        .padding(.horizontal, isIPad ? 0 : 20)
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
                        .buttonStyle(.plain)
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

    private func beatFillColor(for index: Int) -> Color {
        if index == metronome.currentBeat, metronome.isPlaying {
            return .red
        }
        return metronome.beatPattern[index] ? themeManager.accentColor : Color(.systemGray5)
    }

    private func beatLabelColor(for index: Int) -> Color {
        if index == metronome.currentBeat, metronome.isPlaying {
            return .white
        }
        return metronome.beatPattern[index] ? .white : .secondary
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
        .buttonStyle(.plain)
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
