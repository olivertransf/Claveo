//
//  ContentView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var toneGenerator = ToneGeneratorEngine()
    @State private var selectedTabIndex = 0

    var showTabBarText: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        return settingsManager.settings.showTabBarText
    }

    var body: some View {
        TabView(selection: $selectedTabIndex) {
            RecordingListView()
                .tabItem {
                    if showTabBarText {
                        Label("Recordings", systemImage: "waveform")
                    } else {
                        Image(systemName: "waveform")
                    }
                }
                .tag(0)

            MetronomeView()
                .environmentObject(toneGenerator)
                .tabItem {
                    if showTabBarText {
                        Label("Metronome", systemImage: "metronome")
                    } else {
                        Image(systemName: "metronome")
                    }
                }
                .tag(1)

            TunerView()
                .tabItem {
                    if showTabBarText {
                        Label("Tuner", systemImage: "tuningfork")
                    } else {
                        Image(systemName: "tuningfork")
                    }
                }
                .tag(2)

            PracticeView()
                .tabItem {
                    if showTabBarText {
                        Label("Practice", systemImage: "calendar.badge.clock")
                    } else {
                        Image(systemName: "calendar.badge.clock")
                    }
                }
                .tag(3)

            MusicDictionaryView()
                .tabItem {
                    if showTabBarText {
                        Label("Dictionary", systemImage: "book")
                    } else {
                        Image(systemName: "book")
                    }
                }
                .tag(4)

            SettingsView()
                .tabItem {
                    if showTabBarText {
                        Label("Settings", systemImage: "gear")
                    } else {
                        Image(systemName: "gear")
                    }
                }
                .tag(5)
        }
        .tint(themeManager.accentColor)
        .onChange(of: selectedTabIndex) { _, newIndex in
            if newIndex != 1, settingsManager.settings.stopToneWhenLeavingMetronomeTab {
                toneGenerator.stop()
            }
            NotificationCenter.default.post(
                name: .claveoSelectedTabChanged,
                object: nil,
                userInfo: ["index": newIndex]
            )
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
}
