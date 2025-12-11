//
//  MetronomeView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct MetronomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject var metronome = Metronome()
    @StateObject var settingsManager = SettingsManager.shared
    @State var tapTimes: [Date] = []
    @State var showingTemposManagement = false
    @State var showingBeatPattern = false
    @State var showingCustomTimeSignatureSheet = false
    @State var customTop: Int = 4
    @State var customBottom: Int = 4
    
    var favoriteTempos: [Int] {
        settingsManager.settings.favoriteTempos
    }
    
    var autoStopOnTabSwitch: Bool {
        settingsManager.settings.metronomeAutoStopOnTabSwitch
    }
    
    func addFavoriteTempo(_ tempo: Int) {
        var tempos = settingsManager.settings.favoriteTempos
        if !tempos.contains(tempo) {
            tempos.append(tempo)
            tempos.sort()
            settingsManager.update(\.favoriteTempos, value: tempos)
        }
    }
    
    func removeFavoriteTempo(_ tempo: Int) {
        var tempos = settingsManager.settings.favoriteTempos
        tempos.removeAll { $0 == tempo }
        settingsManager.update(\.favoriteTempos, value: tempos)
    }
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationStack {
            mainContentView
        }
        .sheet(isPresented: $showingCustomTimeSignatureSheet) {
            customTimeSignatureSheet
        }
    }
    
    var customTimeSignatureSheet: some View {
        NavigationStack {
            Form {
                Section("Top Number") {
                    Stepper(value: $customTop, in: 1...16) {
                        Text("\(customTop)")
                    }
                }
                
                Section("Bottom Number") {
                    Picker("Bottom", selection: $customBottom) {
                        ForEach([1, 2, 4, 8, 16], id: \.self) { value in
                            Text("\(value)")
                                .tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Button("Save Custom Time Signature") {
                        saveCustomTimeSignature()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.accentColor)
                }
            }
            .navigationTitle("Custom Time Signature")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCustomTimeSignatureSheet = false
                    }
                }
            }
        }
    }
}

#Preview {
    MetronomeView()
}
