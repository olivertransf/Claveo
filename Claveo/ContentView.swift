//
//  ContentView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        TabView {
            RecordingListView()
                .tabItem {
                    Label("Recordings", systemImage: "waveform")
                }
            
            MetronomeView()
                .tabItem {
                    Label("Metronome", systemImage: "metronome")
                }
            
            TunerView()
                .tabItem {
                    Label("Tuner", systemImage: "tuningfork")
                }
            
            MusicDictionaryView()
                .tabItem {
                    Label("Dictionary", systemImage: "book")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
}
