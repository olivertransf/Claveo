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
    @State private var contentId = UUID()
    
    init() {
        // Verify Bravura font is available (FontHelper will handle the actual loading)
        _ = FontHelper.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(contentId)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onChange(of: themeManager.accentColorOption.id) { _, _ in
                    // Reload content when accent color changes
                    // Use a delay to ensure views are ready and avoid crashes
                    Task { @MainActor in
                        // Wait for current render cycle to complete
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        contentId = UUID()
                    }
                }
        }
    }
}
