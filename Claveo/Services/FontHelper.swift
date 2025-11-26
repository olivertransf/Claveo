//
//  FontHelper.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import UIKit
import SwiftUI
import CoreText
import CoreGraphics

/// Helper to load and verify Bravura font for SMuFL symbols
class FontHelper {
    static let shared = FontHelper()
    
    private var bravuraFont: UIFont?
    
    private init() {
        loadBravuraFont()
    }
    
    private func loadBravuraFont() {
        // Try to load Bravura font
        if let font = UIFont(name: "Bravura", size: 16) {
            bravuraFont = font
            #if DEBUG
            print("✅ Bravura font loaded successfully")
            #endif
        } else {
            #if DEBUG
            print("❌ Bravura font NOT found")
            #endif
            
            // Check if font file exists in bundle
            if let fontURL = Bundle.main.url(forResource: "Bravura", withExtension: "otf") {
                #if DEBUG
                print("✅ Bravura.otf found in bundle at: \(fontURL.path)")
                #endif
                
                // Try to register font manually using modern API
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                    #if DEBUG
                    print("✅ Bravura font registered manually")
                    #endif
                    if let font = UIFont(name: "Bravura", size: 16) {
                        bravuraFont = font
                    }
                } else {
                    #if DEBUG
                    if let errorRef = error?.takeUnretainedValue() {
                        let errorDescription = CFErrorCopyDescription(errorRef) as String? ?? "unknown error"
                        print("❌ Failed to register font: \(errorDescription)")
                    } else {
                        print("❌ Failed to register font: unknown error")
                    }
                    #endif
                }
            } else {
                #if DEBUG
                print("❌ Bravura.otf NOT found in bundle")
                #endif
            }
            
            #if DEBUG
            // List all available fonts for debugging
            print("Available fonts containing 'brav':")
            for family in UIFont.familyNames.sorted() {
                if family.lowercased().contains("brav") {
                    print("  Family: \(family)")
                    for name in UIFont.fontNames(forFamilyName: family) {
                        print("    - \(name)")
                    }
                }
            }
            #endif
        }
    }
    
    /// Get Bravura font if available
    func bravuraFont(size: CGFloat) -> UIFont? {
        return UIFont(name: "Bravura", size: size)
    }
    
    /// Check if Bravura font is available
    var isBravuraAvailable: Bool {
        return bravuraFont != nil
    }
    
    /// Get SwiftUI Font for Bravura
    func bravuraSwiftUIFont(size: CGFloat) -> Font {
        if bravuraFont(size: size) != nil {
            // Use custom font with explicit name to ensure it's used
            return Font.custom("Bravura", size: size)
        }
        // Fallback - but this shouldn't happen if font is loaded
        return .system(size: size)
    }
}

