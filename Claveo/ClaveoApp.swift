//
//  ClaveoApp.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

@main
struct ClaveoApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
                .tint(themeManager.accentColor)
                .preferredColorScheme(themeManager.colorScheme)
                .task {
                    await AppStartupCoordinator.run()
                }
        }
    }
}
