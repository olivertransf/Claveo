//
//  ClaveoApp.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

@main
struct ClaveoApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    init() {
        // Verify Bravura font is available (FontHelper will handle the actual loading)
        _ = FontHelper.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
        }
    }
}
