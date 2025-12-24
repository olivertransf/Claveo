//
//  SMuFLMapper.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

/// Converts SMuFL Private Use Area codes (U+E000-U+F8FF) to characters for Bravura font
/// Based on SMuFL specification: https://www.smufl.org/
/// We use ONLY SMuFL codes - no Unicode Musical Symbols conversion
class SMuFLMapper {
    static let shared = SMuFLMapper()
    
    private init() {}
    
    /// Convert SMuFL code string (e.g., "U+E050") to a Character
    func character(from smuflCode: String) -> Character? {
        let hexString = smuflCode.replacingOccurrences(of: "U+", with: "")
        guard let codePoint = UInt32(hexString, radix: 16),
              let scalar = UnicodeScalar(codePoint) else {
            return nil
        }
        return Character(scalar)
    }
    
    /// Get display symbol for a MusicSymbol - uses SMuFL code directly
    func displaySymbol(for symbol: MusicSymbol) -> String {
        // Use SMuFL code if available (stored in smuflCode or unicode field)
        let smuflCode = symbol.smuflCode ?? symbol.unicode
        if smuflCode.hasPrefix("U+E") || smuflCode.hasPrefix("U+F") {
            // This is a SMuFL code (Private Use Area)
            if let char = character(from: smuflCode) {
                return String(char)
            }
        }
        
        // Fallback to stored symbol character
        return symbol.symbol
    }
}

