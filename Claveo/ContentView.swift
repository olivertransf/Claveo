//
//  ContentView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        TabView {
            RecordingListView()
                .tabItem {
                    if settingsManager.settings.showTabBarText {
                        Label("Recordings", systemImage: "waveform")
                    } else {
                        Image(systemName: "waveform")
                    }
                }
            
            MetronomeView()
                .tabItem {
                    if settingsManager.settings.showTabBarText {
                        Label("Metronome", systemImage: "metronome")
                    } else {
                        Image(systemName: "metronome")
                    }
                }
            
            TunerView()
                .tabItem {
                    if settingsManager.settings.showTabBarText {
                        Label("Tuner", systemImage: "tuningfork")
                    } else {
                        Image(systemName: "tuningfork")
                    }
                }
            
            MusicDictionaryView()
                .tabItem {
                    if settingsManager.settings.showTabBarText {
                        Label("Dictionary", systemImage: "book")
                    } else {
                        Image(systemName: "book")
                    }
                }
            
            SettingsView()
                .tabItem {
                    if settingsManager.settings.showTabBarText {
                        Label("Settings", systemImage: "gearshape")
                    } else {
                        Image(systemName: "gearshape")
                    }
                }
        }
        .tint(themeManager.accentColor)
        .id(settingsManager.settings.showTabBarText)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
}
