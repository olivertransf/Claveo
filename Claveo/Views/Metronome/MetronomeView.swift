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
    
    private var shouldUseSplitView: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }
    
    var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        Group {
            if shouldUseSplitView {
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
                // iPhone layout (or iPad in narrow window)
                NavigationStack {
                    mainContentView
                }
            }
        }
        .sheet(isPresented: $showingCustomTimeSignatureSheet) {
            customTimeSignatureSheet
        }
    }
}

#Preview {
    MetronomeView()
}
