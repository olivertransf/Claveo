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
    
    var showTabBarText: Bool {
        settingsManager.settings.showTabBarText
    }
    
    var body: some View {
        TabView {
            RecordingListView()
                .tabItem {
                    if showTabBarText {
                        Label("Recordings", systemImage: "waveform")
                    } else {
                        Image(systemName: "waveform")
                    }
                }
            
            MetronomeView()
                .tabItem {
                    if showTabBarText {
                        Label("Metronome", systemImage: "metronome")
                    } else {
                        Image(systemName: "metronome")
                    }
                }
            
            TunerView()
                .tabItem {
                    if showTabBarText {
                        Label("Tuner", systemImage: "tuningfork")
                    } else {
                        Image(systemName: "tuningfork")
                    }
                }
            
            MusicDictionaryView()
                .tabItem {
                    if showTabBarText {
                        Label("Dictionary", systemImage: "book")
                    } else {
                        Image(systemName: "book")
                    }
                }
            
            SettingsView()
                .tabItem {
                    if showTabBarText {
                        Label("Settings", systemImage: "gearshape")
                    } else {
                        Image(systemName: "gearshape")
                    }
                }
        }
        .tint(themeManager.accentColor)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
}
