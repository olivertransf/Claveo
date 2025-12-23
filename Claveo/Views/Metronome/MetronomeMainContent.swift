//
//  MetronomeView+MainContent.swift
//  Claveo
//
//  Main metronome UI extracted from MetronomeView.
//

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
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingVolumeSheet = true
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
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
                // Don't override tempo on appear - it's already loaded from lastMetronomeTempo in init
            }
            .onDisappear {
                if autoStopOnTabSwitch && metronome.isPlaying {
                    metronome.stop()
                }
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
