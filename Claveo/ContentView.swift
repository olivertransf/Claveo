//
//  ContentView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    
    var showTabBarText: Bool {
        // Always show text on iPad, use setting on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        return settingsManager.settings.showTabBarText
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

            PracticeView()
                .tabItem {
                    if showTabBarText {
                        Label("Practice", systemImage: "calendar.badge.clock")
                    } else {
                        Image(systemName: "calendar.badge.clock")
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
        }
        .tint(themeManager.accentColor)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
}
