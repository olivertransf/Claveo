//
//  MetronomeView+MainContent.swift
//  Claveo
//
//  Main metronome UI extracted from MetronomeView.
//

import SwiftUI

extension MetronomeView {
    var mainContentView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 12) {
                Text("\(metronome.tempo)")
                    .font(.system(size: isIPad ? 144 : 96, weight: .ultraLight, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                
                Text("BPM")
                    .font(isIPad ? .title : .title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, isIPad ? 60 : 40)
            
            Spacer()
            
            Button(action: {
                if metronome.isPlaying {
                    metronome.stop()
                } else {
                    metronome.start()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(metronome.isPlaying ? Color.red : themeManager.accentColor)
                        .frame(width: isIPad ? 140 : 100, height: isIPad ? 140 : 100)
                        .shadow(color: (metronome.isPlaying ? Color.red : themeManager.accentColor).opacity(0.3), radius: isIPad ? 30 : 20, x: 0, y: isIPad ? 15 : 10)
                    
                    Image(systemName: metronome.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: isIPad ? 56 : 40, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .accessibilityLabel(metronome.isPlaying ? "Stop Metronome" : "Start Metronome")
            
            Spacer()
            
            VStack(spacing: isIPad ? 24 : 16) {
                HStack(alignment: .center, spacing: isIPad ? 12 : 10) {
                    Button(action: {
                        metronome.tempo = max(20, metronome.tempo - 1)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(isIPad ? .title : .title2)
                            .foregroundColor(themeManager.accentColor)
                    }
                    .frame(width: isIPad ? 40 : 32, height: isIPad ? 40 : 32)
                    .offset(y: -13)
                    
                    VStack(spacing: isIPad ? 8 : 4) {
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
                        metronome.tempo = min(300, metronome.tempo + 1)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(isIPad ? .title : .title2)
                            .foregroundColor(themeManager.accentColor)
                    }
                    .frame(width: isIPad ? 40 : 32, height: isIPad ? 40 : 32)
                    .offset(y: -13)
                }
                .padding(.horizontal, isIPad ? 20 : 16)
                
                if !isIPad {
                    HStack(spacing: 20) {
                        Button(action: tapTempo) {
                            VStack(spacing: 4) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.title3)
                                Text("Tap")
                                    .font(.caption2)
                            }
                            .foregroundColor(themeManager.accentColor)
                            .frame(maxWidth: .infinity)
                        }
                        
                        Menu {
                            ForEach(TimeSignature.allCases, id: \.self) { signature in
                                Button(action: {
                                    metronome.setTimeSignature(signature)
                                }) {
                                    HStack {
                                        Text(signature.rawValue)
                                        if metronome.timeSignature == signature {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundColor(themeManager.accentColor)
                                        }
                                    }
                                }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(metronome.timeSignature.rawValue)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Text("Time")
                                    .font(.caption2)
                            }
                            .foregroundColor(themeManager.accentColor)
                            .frame(maxWidth: .infinity)
                        }
                        
                        Button(action: {
                            withAnimation {
                                showingBeatPattern.toggle()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: showingBeatPattern ? "circle.grid.3x3.fill" : "circle.grid.3x3")
                                    .font(.title3)
                                Text("Beats")
                                    .font(.caption2)
                            }
                            .foregroundColor(showingBeatPattern ? themeManager.accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                if !favoriteTempos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(favoriteTempos, id: \.self) { tempo in
                                Button(action: {
                                    metronome.tempo = tempo
                                }) {
                                    Text("\(tempo)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(metronome.tempo == tempo ? .white : .primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(metronome.tempo == tempo ? themeManager.accentColor : Color(.systemGray5))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .frame(height: 32)
                }
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("Metronome")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        let defaultTempo = settingsManager.settings.defaultMetronomeTempo
                        if defaultTempo >= 20 && defaultTempo <= 300 {
                            metronome.tempo = defaultTempo
                        }
                    }) {
                        Label("Reset to Default", systemImage: "arrow.counterclockwise")
                    }
                    
                    Divider()
                    
                    Button(action: {
                        if favoriteTempos.contains(metronome.tempo) {
                            removeFavoriteTempo(metronome.tempo)
                        } else {
                            addFavoriteTempo(metronome.tempo)
                        }
                    }) {
                        Label(
                            favoriteTempos.contains(metronome.tempo) ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: favoriteTempos.contains(metronome.tempo) ? "star.fill" : "star"
                        )
                    }
                    
                    if !favoriteTempos.isEmpty {
                        Button(action: {
                            showingTemposManagement = true
                        }) {
                            Label("Manage Tempos", systemImage: "list.bullet")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(themeManager.accentColor)
                }
            }
        }
        .overlay(alignment: .center) {
            if showingBeatPattern && !isIPad {
                VStack(spacing: 16) {
                    Text("Beat Pattern")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 10) {
                        ForEach(0..<((metronome.beatPattern.count + 5) / 6), id: \.self) { rowIndex in
                            HStack(spacing: 10) {
                                ForEach(0..<min(6, metronome.beatPattern.count - rowIndex * 6), id: \.self) { colIndex in
                                    let index = rowIndex * 6 + colIndex
                                    Circle()
                                        .fill(
                                            index == metronome.currentBeat && metronome.isPlaying ?
                                            Color.red :
                                            (metronome.beatPattern[index] ? themeManager.accentColor : Color(.systemGray5))
                                        )
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text("\(index + 1)")
                                                .font(.caption2)
                                                .foregroundColor(
                                                    index == metronome.currentBeat && metronome.isPlaying ?
                                                    .white :
                                                    (metronome.beatPattern[index] ? .white : .secondary)
                                                )
                                        )
                                        .onTapGesture {
                                            toggleBeat(index)
                                        }
                                        .animation(.easeInOut(duration: 0.1), value: metronome.currentBeat)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))
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
            if !metronome.isPlaying {
                let defaultTempo = settingsManager.settings.defaultMetronomeTempo
                if defaultTempo >= 20 && defaultTempo <= 300 {
                    metronome.tempo = defaultTempo
                }
            }
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
        .onChange(of: settingsManager.settings.metronomeSound) { _, _ in
            syncSettingsFromManager()
        }
        .onChange(of: settingsManager.settings.metronomeHapticEnabled) { _, _ in
            syncSettingsFromManager()
        }
    }
}


