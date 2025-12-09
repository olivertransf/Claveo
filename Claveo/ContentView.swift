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
    
    private var shouldShowTabBarText: Bool {
        // Always show text on iPad, respect setting on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        return settingsManager.settings.showTabBarText
    }
    
    var body: some View {
        TabView {
            RecordingListView()
                .tabItem {
                    if shouldShowTabBarText {
                        Label("Recordings", systemImage: "waveform")
                    } else {
                        Image(systemName: "waveform")
                    }
                }
            
            MetronomeView()
                .tabItem {
                    if shouldShowTabBarText {
                        Label("Metronome", systemImage: "metronome")
                    } else {
                        Image(systemName: "metronome")
                    }
                }
            
            TunerView()
                .tabItem {
                    if shouldShowTabBarText {
                        Label("Tuner", systemImage: "tuningfork")
                    } else {
                        Image(systemName: "tuningfork")
                    }
                }
            
            MusicDictionaryView()
                .tabItem {
                    if shouldShowTabBarText {
                        Label("Dictionary", systemImage: "book")
                    } else {
                        Image(systemName: "book")
                    }
                }
            
            SettingsView()
                .tabItem {
                    if shouldShowTabBarText {
                        Label("Settings", systemImage: "gearshape")
                    } else {
                        Image(systemName: "gearshape")
                    }
                }
        }
        .tint(themeManager.accentColor)
        .id(shouldShowTabBarText)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
}
