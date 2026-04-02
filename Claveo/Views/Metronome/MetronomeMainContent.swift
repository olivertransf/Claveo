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
            VStack(spacing: isIPad ? 32 : 24) {
                // Tempo display
                VStack(spacing: 12) {
                    Text("\(metronome.tempo)")
                        .font(
                            .system(
                                size: isIPad ? 144 : 96,
                                weight: .light,
                                design: .rounded
                            )
                        )
                        .foregroundColor(.primary)
                        .monospacedDigit()
                    
                    Text("BPM")
                        .font(isIPad ? .title : .title3)
                        .foregroundColor(.secondary)
                }
                .padding(.top, isIPad ? 40 : 20)
                
                // Favorite and Play buttons
                HStack(spacing: 24) {
                    // Favorite button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            if favoriteTempos.contains(metronome.tempo) {
                                removeFavoriteTempo(metronome.tempo)
                            } else {
                                addFavoriteTempo(metronome.tempo)
                            }
                        }
                    }) {
                        Image(systemName: favoriteTempos.contains(metronome.tempo) ? "star.fill" : "star")
                            .font(.system(size: isIPad ? 40 : 32, weight: .medium))
                            .foregroundColor(favoriteTempos.contains(metronome.tempo) ? .yellow : themeManager.accentColor)
                            .shadow(color: (favoriteTempos.contains(metronome.tempo) ? Color.yellow : themeManager.accentColor).opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .accessibilityLabel(favoriteTempos.contains(metronome.tempo) ? "Remove from Favorites" : "Add to Favorites")
                    
                    // Play/Stop button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            if metronome.isPlaying {
                                metronome.stop()
                            } else {
                                metronome.start()
                            }
                        }
                    }) {
                        Image(systemName: metronome.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: isIPad ? 80 : 72, weight: .light))
                            .foregroundColor(metronome.isPlaying ? .red : themeManager.accentColor)
                            .shadow(color: (metronome.isPlaying ? Color.red : themeManager.accentColor).opacity(0.2), radius: 12, x: 0, y: 6)
                            .scaleEffect(metronome.isPlaying ? 1.0 : 1.0)
                    }
                    .accessibilityLabel(metronome.isPlaying ? "Stop Metronome" : "Start Metronome")
                }
                
                VStack(spacing: isIPad ? 24 : 20) {
                    // Tempo slider section
                    VStack(spacing: isIPad ? 8 : 6) {
                        HStack(alignment: .center, spacing: isIPad ? 12 : 10) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    metronome.tempo = max(20, metronome.tempo - 1)
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(isIPad ? .title : .title2)
                                    .foregroundColor(themeManager.accentColor)
                            }
                            .frame(width: isIPad ? 40 : 36, height: isIPad ? 40 : 36)
                            .offset(y: -13)
                            
                            VStack(spacing: isIPad ? 8 : 6) {
                                Slider(value: Binding(
                                    get: { Double(metronome.tempo) },
                                    set: { metronome.tempo = Int($0) }
                                ), in: 20...300, step: 1)
                                .tint(themeManager.accentColor)
                                
                                HStack {
                                    Text("20")
                                        .font(isIPad ? .caption : .caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("300")
                                        .font(isIPad ? .caption : .caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    metronome.tempo = min(300, metronome.tempo + 1)
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(isIPad ? .title : .title2)
                                    .foregroundColor(themeManager.accentColor)
                            }
                            .frame(width: isIPad ? 40 : 36, height: isIPad ? 40 : 36)
                            .offset(y: -13)
                        }
                        .padding(.horizontal, isIPad ? 20 : 20)
                    }
                    
                    // Control buttons section (shown on all devices)
                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            Button(action: tapTempo) {
                                Label("Tap Tempo", systemImage: "hand.tap")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(themeManager.accentColor)
                            
                            Menu {
                                ForEach(TimeSignature.allCases, id: \.self) { signature in
                                    Button(action: {
                                        metronome.setTimeSignature(signature)
                                    }) {
                                        HStack {
                                            Text(signature.rawValue)
                                            if metronome.customTimeSignature == nil && metronome.timeSignature == signature {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(themeManager.accentColor)
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
                                                .foregroundColor(themeManager.accentColor)
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
                        .padding(.horizontal, 20)
                        
                        // Beat pattern section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "circle.grid.3x3")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Beat Pattern")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            // Grid layout that wraps to multiple rows
                            let columns = [GridItem(.adaptive(minimum: 52), spacing: 12)]
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                                ForEach(0..<metronome.beatPattern.count, id: \.self) { index in
                                    Button {
                                        toggleBeat(index)
                                    } label: {
                                        Circle()
                                            .fill(
                                                index == metronome.currentBeat && metronome.isPlaying ?
                                                Color.red :
                                                    (metronome.beatPattern[index] ? themeManager.accentColor : Color(.systemGray5))
                                            )
                                            .frame(width: 52, height: 52)
                                            .overlay(
                                                Text("\(index + 1)")
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(
                                                        index == metronome.currentBeat && metronome.isPlaying ?
                                                            .white :
                                                            (metronome.beatPattern[index] ? .white : .secondary)
                                                    )
                                            )
                                            .shadow(color: (index == metronome.currentBeat && metronome.isPlaying ? Color.red : (metronome.beatPattern[index] ? themeManager.accentColor : Color.clear)).opacity(0.3), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .id("\(index)-\(metronome.beatPattern.count)")
                                    .animation(.easeInOut(duration: 0.1), value: metronome.currentBeat)
                                }
                            }
                            .padding(.horizontal, 20)
                            .animation(.easeInOut(duration: 0.2), value: metronome.beatPattern.count)
                        }
                    }

                    toneGeneratorSection

                    if !favoriteTempos.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Favorite Tempos")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(favoriteTempos, id: \.self) { tempo in
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                metronome.tempo = tempo
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Text("\(tempo)")
                                                    .font(.system(.body, design: .rounded))
                                                    .fontWeight(.semibold)
                                                    .monospacedDigit()
                                                Text("BPM")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .opacity(0.8)
                                            }
                                            .foregroundColor(metronome.tempo == tempo ? .white : .primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                Group {
                                                    if metronome.tempo == tempo {
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .fill(themeManager.accentColor)
                                                            .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .fill(Color(.systemGray6))
                                                    }
                                                }
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(metronome.tempo == tempo ? themeManager.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                                            )
                                            .scaleEffect(metronome.tempo == tempo ? 1.05 : 1.0)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive, action: {
                                                withAnimation {
                                                    removeFavoriteTempo(tempo)
                                                }
                                            }) {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
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
                // Save last tempo with a small delay to avoid too many saves while dragging slider
                let tempoToSave = newValue
                Task { @MainActor [weak metronome] in
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    // Check if metronome still exists and tempo hasn't changed
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
        .scrollDismissesKeyboard(.interactively)
    }

    private static let toneChromaticShortNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    private var toneGridSixColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    }

    var toneGeneratorSection: some View {
        let a4 = settingsManager.settings.a4ReferenceFrequency

        return VStack(alignment: .leading, spacing: 16) {
            Divider()
                .padding(.top, 20)
                .padding(.bottom, 4)

            HStack(spacing: 8) {
                Image(systemName: "waveform.path")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tone Generator")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)

            Text(String(format: "%.1f Hz", toneGenerator.frequency))
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                TextField("Manual", text: $manualToneFrequencyText)
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
            .padding(.horizontal, 20)

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
            .padding(.horizontal, 20)

            LazyVGrid(columns: toneGridSixColumns, spacing: 10) {
                ForEach(0..<6, id: \.self) { noteIdx in
                    tonePitchButton(noteIndex: noteIdx, a4: a4)
                }
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: toneGridSixColumns, spacing: 10) {
                ForEach(6..<12, id: \.self) { noteIdx in
                    tonePitchButton(noteIndex: noteIdx, a4: a4)
                }
            }
            .padding(.horizontal, 20)

            Text("Octave")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 8)

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
                                .frame(minWidth: 56, minHeight: 52)
                                .padding(.horizontal, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(selected ? themeManager.accentColor : Color(.tertiarySystemFill))
                                )
                                .foregroundStyle(selected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
        .padding(.bottom, 24)
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
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? themeManager.accentColor : Color(.tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
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
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        // No updates needed
    }
}
