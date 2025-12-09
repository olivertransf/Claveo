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
    
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        if isIPad {
            // iPad split view layout using native NavigationSplitView
            NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
                // Sidebar
                sidebarView
                    .navigationSplitViewColumnWidth(min: 300, ideal: 350)
            } detail: {
                // Main content
                mainContentView
            }
        } else {
            // iPhone layout
            NavigationStack {
                mainContentView
            }
        }
    }
}

#Preview {
    MetronomeView()
}
