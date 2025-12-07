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
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var tapTimes: [Date] = []
    @State private var showingTimeSignaturePicker = false
    @State private var showingTemposManagement = false
    
    private var favoriteTempos: [Int] {
        settingsManager.settings.favoriteTempos
    }
    
    private var autoStopOnTabSwitch: Bool {
        settingsManager.settings.metronomeAutoStopOnTabSwitch
    }
    
    private func addFavoriteTempo(_ tempo: Int) {
        var tempos = settingsManager.settings.favoriteTempos
        if !tempos.contains(tempo) {
            tempos.append(tempo)
            tempos.sort()
            settingsManager.update(\.favoriteTempos, value: tempos)
        }
    }
    
    private func removeFavoriteTempo(_ tempo: Int) {
        var tempos = settingsManager.settings.favoriteTempos
        tempos.removeAll { $0 == tempo }
        settingsManager.update(\.favoriteTempos, value: tempos)
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
                        Text("20")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                        
                        Slider(value: Binding(
                            get: { Double(metronome.tempo) },
                            set: { metronome.tempo = Int($0) }
                        ), in: 20...300, step: 1)
                        
                        Text("300")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                    }
                    .padding(.horizontal, 32)
                    
                    // Tempo adjustment buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            metronome.tempo = max(20, metronome.tempo - 1)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            metronome.tempo = min(300, metronome.tempo + 1)
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
                                            .background(metronome.tempo == tempo ? themeManager.accentColor : Color.themeFill)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                        }
                    }
                    
                    // Add to favorites button and manage tempos
                    HStack(spacing: 16) {
                        Button(action: {
                            addFavoriteTempo(metronome.tempo)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: favoriteTempos.contains(metronome.tempo) ? "star.fill" : "star")
                                    .font(.caption)
                                Text("Add")
                                    .font(.caption)
                            }
                            .foregroundColor(favoriteTempos.contains(metronome.tempo) ? .yellow : .secondary)
                        }
                        
                        if !favoriteTempos.isEmpty {
                            Button(action: {
                                showingTemposManagement = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "list.bullet")
                                        .font(.caption)
                                    Text("Manage")
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
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
                
                // Beat pattern grid - max 6 beats per row
                VStack(spacing: 12) {
                    Text("Beat Pattern")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        ForEach(0..<((metronome.beatPattern.count + 5) / 6), id: \.self) { rowIndex in
                            HStack(spacing: 12) {
                                Spacer()
                                
                                ForEach(0..<min(6, metronome.beatPattern.count - rowIndex * 6), id: \.self) { colIndex in
                                    let index = rowIndex * 6 + colIndex
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
                                
                                Spacer()
                            }
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
                    .accessibilityLabel("Tap Tempo")
                    .accessibilityHint("Tap to set the tempo")
                    
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
                                .fill(metronome.isPlaying ? Color.red : themeManager.accentColor)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: metronome.isPlaying ? "stop.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    .accessibilityLabel(metronome.isPlaying ? "Stop Metronome" : "Start Metronome")
                }
                .padding(.bottom, 40)
            }
            .padding()
            .navigationTitle("Metronome")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingTimeSignaturePicker) {
                TimeSignaturePickerView(selectedSignature: Binding(
                    get: { metronome.timeSignature },
                    set: { metronome.setTimeSignature($0) }
                ))
                .environmentObject(themeManager)
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
                // Sync settings from SettingsManager
                syncSettingsFromManager()
            }
            .onDisappear {
                // Auto-stop metronome when switching tabs if setting is enabled
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
    
    private func syncSettingsFromManager() {
        let sound = settingsManager.metronomeSoundEnum
        if metronome.soundType != sound {
            metronome.soundType = sound
        }
        let hapticEnabled = settingsManager.settings.metronomeHapticEnabled
        if metronome.hapticEnabled != hapticEnabled {
            metronome.hapticEnabled = hapticEnabled
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
            metronome.tempo = max(20, min(300, calculatedTempo))
        }
        
        // Clear taps after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if tapTimes.count > 0 {
                tapTimes.removeAll()
            }
        }
    }
}

struct TimeSignaturePickerView: View {
    @Binding var selectedSignature: TimeSignature
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
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
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Time Signature")
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
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

struct TemposManagementView: View {
    @Binding var tempos: [Int]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var newTempo = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Add Tempo") {
                    HStack {
                        TextField("BPM", text: $newTempo)
                            .keyboardType(.numberPad)
                        
                        Button("Add") {
                            if let tempo = Int(newTempo), tempo >= 20 && tempo <= 300 {
                                if !tempos.contains(tempo) {
                                    tempos.append(tempo)
                                    tempos.sort()
                                    newTempo = ""
                                }
                            }
                        }
                        .disabled(newTempo.isEmpty || Int(newTempo) == nil || Int(newTempo)! < 20 || Int(newTempo)! > 300)
                    }
                }
                
                Section {
                    if tempos.isEmpty {
                        Text("No tempos")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(tempos.sorted(), id: \.self) { tempo in
                            HStack {
                                Text("\(tempo) BPM")
                                    .font(.body)
                                Spacer()
                                Button(action: {
                                    tempos.removeAll { $0 == tempo }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let sorted = tempos.sorted()
                            for index in indexSet {
                                if index < sorted.count {
                                    tempos.removeAll { $0 == sorted[index] }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Tempos")
                        Spacer()
                        if !tempos.isEmpty {
                            Text("\(tempos.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Manage Tempos")
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
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

