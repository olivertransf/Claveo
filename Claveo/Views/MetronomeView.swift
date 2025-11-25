//
//  MetronomeView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct MetronomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var metronome = Metronome()
    @State private var tapTimes: [Date] = []
    @State private var showingTimeSignaturePicker = false
    @State private var showingSettings = false
    @AppStorage("favoriteTempos") private var favoriteTemposData: Data = Data()
    @State private var favoriteTempos: [Int] = []
    
    private func loadFavoriteTempos() {
        if let decoded = try? JSONDecoder().decode([Int].self, from: favoriteTemposData) {
            favoriteTempos = decoded
        }
    }
    
    private func saveFavoriteTempos() {
        if let encoded = try? JSONEncoder().encode(favoriteTempos) {
            favoriteTemposData = encoded
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Tempo display and controls
                VStack(spacing: 16) {
                    Text("\(metronome.tempo)")
                        .font(.system(size: 72, weight: .light, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("BPM")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    // Tempo slider
                    HStack(spacing: 16) {
                        Text("40")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                        
                        Slider(value: Binding(
                            get: { Double(metronome.tempo) },
                            set: { metronome.tempo = Int($0) }
                        ), in: 40...200, step: 1)
                        
                        Text("200")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                    }
                    .padding(.horizontal, 32)
                    
                    // Tempo adjustment buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            metronome.tempo = max(40, metronome.tempo - 1)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            metronome.tempo = min(200, metronome.tempo + 1)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Favorite tempos quick access
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
                                            .foregroundColor(metronome.tempo == tempo ? .white : .themeLabel)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(metronome.tempo == tempo ? Color.themeAccent : Color.themeFill)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                        }
                    }
                    
                    // Add to favorites button
                    Button(action: {
                        if !favoriteTempos.contains(metronome.tempo) {
                            favoriteTempos.append(metronome.tempo)
                            favoriteTempos.sort()
                            saveFavoriteTempos()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: favoriteTempos.contains(metronome.tempo) ? "star.fill" : "star")
                                .font(.caption)
                            Text("Favorite")
                                .font(.caption)
                        }
                        .foregroundColor(favoriteTempos.contains(metronome.tempo) ? .yellow : .secondary)
                    }
                }
                
                // Time signature
                Button(action: {
                    showingTimeSignaturePicker = true
                }) {
                    HStack {
                        Text(metronome.timeSignature.rawValue)
                            .font(.title2)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.themeTertiaryBackground)
                    .cornerRadius(8)
                }
                
                // Beat pattern grid
                VStack(spacing: 12) {
                    Text("Beat Pattern")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(0..<metronome.beatPattern.count, id: \.self) { index in
                            Circle()
                                .fill(
                                    index == metronome.currentBeat && metronome.isPlaying ?
                                    Color.red :
                                    (metronome.beatPattern[index] ? Color.primary : Color(.systemGray5))
                                )
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(
                                            index == metronome.currentBeat && metronome.isPlaying ?
                                            .white :
                                            (metronome.beatPattern[index] ? .primary : .secondary)
                                        )
                                )
                                .onTapGesture {
                                    toggleBeat(index)
                                }
                                .animation(.easeInOut(duration: 0.1), value: metronome.currentBeat)
                        }
                    }
                }
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 40) {
                    // Tap tempo button
                    Button(action: tapTempo) {
                        VStack(spacing: 4) {
                            Image(systemName: "hand.tap.fill")
                                .font(.title2)
                            Text("Tap")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                        .frame(width: 60, height: 60)
                    }
                    
                    // Play/Stop button
                    Button(action: {
                        if metronome.isPlaying {
                            metronome.stop()
                        } else {
                            metronome.start()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(metronome.isPlaying ? Color.red : Color.primary)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: metronome.isPlaying ? "stop.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
            .navigationTitle("Metronome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingTimeSignaturePicker) {
                TimeSignaturePickerView(selectedSignature: Binding(
                    get: { metronome.timeSignature },
                    set: { metronome.setTimeSignature($0) }
                ))
            }
            .sheet(isPresented: $showingSettings) {
                MetronomeSettingsView(
                    soundType: $metronome.soundType,
                    hapticEnabled: $metronome.hapticEnabled,
                    favoriteTempos: Binding(
                        get: { favoriteTempos },
                        set: { newValue in
                            favoriteTempos = newValue
                            saveFavoriteTempos()
                        }
                    ),
                    onDismiss: {
                        metronome.savePreferences()
                    }
                )
            }
            .onAppear {
                loadFavoriteTempos()
            }
        }
    }
    
    private func toggleBeat(_ index: Int) {
        metronome.beatPattern[index].toggle()
    }
    
    private func tapTempo() {
        let now = Date()
        tapTimes.append(now)
        
        // Keep only last 4 taps
        if tapTimes.count > 4 {
            tapTimes.removeFirst()
        }
        
        // Calculate tempo from tap intervals
        if tapTimes.count >= 2 {
            let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0.timeIntervalSince($1) }
            let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
            let calculatedTempo = Int(60.0 / averageInterval)
            
            // Clamp to valid range
            metronome.tempo = max(40, min(200, calculatedTempo))
        }
        
        // Clear taps after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if tapTimes.count > 0 {
                tapTimes.removeAll()
            }
        }
    }
}

struct MetronomeSettingsView: View {
    @Binding var soundType: MetronomeSound
    @Binding var hapticEnabled: Bool
    @Binding var favoriteTempos: [Int]
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sound") {
                    Picker("Sound Type", selection: $soundType) {
                        ForEach(MetronomeSound.allCases, id: \.self) { sound in
                            Text(sound.rawValue).tag(sound)
                        }
                    }
                }
                
                Section("Haptic Feedback") {
                    Toggle("Enable Haptic Feedback", isOn: $hapticEnabled)
                }
                
                Section("Favorite Tempos") {
                    if favoriteTempos.isEmpty {
                        Text("No favorite tempos yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(favoriteTempos, id: \.self) { tempo in
                            HStack {
                                Text("\(tempo) BPM")
                                Spacer()
                                Button(action: {
                                    favoriteTempos.removeAll { $0 == tempo }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Metronome Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TimeSignaturePickerView: View {
    @Binding var selectedSignature: TimeSignature
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(TimeSignature.allCases, id: \.self) { signature in
                    Button(action: {
                        selectedSignature = signature
                        dismiss()
                    }) {
                        HStack {
                            Text(signature.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedSignature == signature {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Time Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MetronomeView()
}

