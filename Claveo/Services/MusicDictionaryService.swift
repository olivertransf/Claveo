//
//  MusicDictionaryService.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import Foundation
import Combine

class MusicDictionaryService: ObservableObject {
    static let shared = MusicDictionaryService()
    
    @Published var dictionary: MusicDictionary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {
        loadDictionary()
    }
    
    func loadDictionary() {
        isLoading = true
        errorMessage = nil
        
        guard let url = Bundle.main.url(forResource: "musicDictionary", withExtension: "json") else {
            errorMessage = "Dictionary file not found in bundle"
            isLoading = false
            #if DEBUG
            print("❌ Dictionary file not found at: musicDictionary.json")
            #endif
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            #if DEBUG
            print("✅ Dictionary file loaded, size: \(data.count) bytes")
            #endif
            
            let decoder = JSONDecoder()
            dictionary = try decoder.decode(MusicDictionary.self, from: data)
            #if DEBUG
            print("✅ Dictionary decoded successfully")
            print("   - Terms: \(dictionary?.terms.count ?? 0)")
            print("   - Symbols: \(dictionary?.symbols.count ?? 0)")
            #endif
            isLoading = false
        } catch let decodingError as DecodingError {
            var errorDetails = "Failed to decode dictionary: "
            switch decodingError {
            case .dataCorrupted(let context):
                errorDetails += "Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                errorDetails += "Key '\(key.stringValue)' not found at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .typeMismatch(let type, let context):
                errorDetails += "Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                errorDetails += "Value not found for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            @unknown default:
                errorDetails += decodingError.localizedDescription
            }
            errorMessage = errorDetails
            isLoading = false
            #if DEBUG
            print("❌ Decoding error: \(errorDetails)")
            #endif
        } catch {
            errorMessage = "Failed to load dictionary: \(error.localizedDescription)"
            isLoading = false
            #if DEBUG
            print("❌ General error: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Search all terms (including theory concepts)
    func searchAllTerms(query: String) -> [MusicTerm] {
        let showAdvanced = SettingsManager.shared.settings.showAdvancedDictionaryItems
        
        guard let dictionary = dictionary, !query.isEmpty else {
            // When no query, return common terms first
            let terms = dictionary?.terms ?? []
            let filtered = showAdvanced ? terms : filterCommonTerms(terms)
            return filtered.sorted(by: { termPriority($0) > termPriority($1) })
        }
        
        let lowercasedQuery = query.lowercased()
        let filtered = dictionary.terms.filter { term in
            let matches = term.term.lowercased().contains(lowercasedQuery) ||
            term.definition.lowercased().contains(lowercasedQuery) ||
            term.category.lowercased().contains(lowercasedQuery) ||
            (term.example?.lowercased().contains(lowercasedQuery) ?? false)
            
            // Filter out advanced terms if setting is off
            if !showAdvanced && !isCommonTerm(term) {
                return false
            }
            
            return matches
        }
        
        // Sort by priority (common terms first), then by name
        return filtered.sorted { first, second in
            let firstPriority = termPriority(first, query: lowercasedQuery)
            let secondPriority = termPriority(second, query: lowercasedQuery)
            
            if firstPriority != secondPriority {
                return firstPriority > secondPriority
            }
            return first.term < second.term
        }
    }
    
    /// Filter to show only common terms
    private func filterCommonTerms(_ terms: [MusicTerm]) -> [MusicTerm] {
        return terms.filter { isCommonTerm($0) }
    }
    
    /// Check if a term is common (not advanced/specialized)
    private func isCommonTerm(_ term: MusicTerm) -> Bool {
        let category = term.category.lowercased()
        let termLower = term.term.lowercased()
        
        // Only show terms from these common categories
        let commonCategories = [
            "tempo", "dynamics", "articulation", "ornamentation", "style",
            "notation", "form", "general"
        ]
        
        // Check if category is in the common list
        let isCommonCategory = commonCategories.contains(where: { category.contains($0) })
        
        // For Theory category, only show basic/common theory terms
        if category == "theory" {
            // Common theory terms that should be shown
            let commonTheoryTerms = [
                "scale", "chord", "triad", "interval", "harmony", "melody",
                "rhythm", "beat", "tempo", "key", "mode", "major", "minor",
                "tonic", "dominant", "subdominant", "cadence", "progression",
                "arpeggio", "octave", "semitone", "whole tone", "accidental",
                "sharp", "flat", "natural", "transposition", "modulation",
                "consonance", "dissonance", "resolution", "phrase", "motive",
                "theme", "variation", "canon", "fugue", "sonata", "rondo",
                "symphony", "concerto", "overture", "prelude", "etude"
            ]
            
            // Only show if it's a common theory term
            return commonTheoryTerms.contains(where: { termLower.contains($0) })
        }
        
        // Hide advanced/specialized categories
        let advancedCategories = [
            "history", "instruments"
        ]
        
        if advancedCategories.contains(where: { category.contains($0) }) {
            return false
        }
        
        // Advanced theory concepts (very specialized) - filter these out even if in common category
        let advancedTerms = [
            "sagittal", "herculean", "olympian", "magrathean", "promethean",
            "athenian", "trojan", "spartan", "johnston", "helmholtz",
            "wyschnegradsky", "arel-ezgi", "turkish folk", "persian",
            "arabic", "stockhausen", "kahnotation", "daseian", "kievan",
            "renaissance lute", "german organ", "medieval and renaissance",
            "atonal", "bitonal", "polytonal", "serial", "twelve-tone",
            "microtonal", "quarter tone", "just intonation", "equal temperament",
            "pythagorean", "meantone", "well temperament", "schisma", "comma"
        ]
        
        if advancedTerms.contains(where: { termLower.contains($0) }) {
            return false
        }
        
        // Return true if it's a common category
        return isCommonCategory
    }
    
    /// Legacy function for backward compatibility
    func searchTerms(query: String) -> [MusicTerm] {
        return searchAllTerms(query: query)
    }
    
    /// Calculate priority score for a term (higher = more common/important)
    private func termPriority(_ term: MusicTerm, query: String = "") -> Int {
        let termLower = term.term.lowercased()
        let categoryLower = term.category.lowercased()
        var priority = 0
        
        // High priority categories (common musical terms and theory)
        let highPriorityCategories = [
            "theory", "tempo", "dynamics", "articulation", "ornaments", 
            "clefs", "notes", "rests", "accidentals", "time signatures",
            "form", "notation"
        ]
        
        if highPriorityCategories.contains(where: { categoryLower.contains($0) }) {
            priority += 100
        }
        
        // Extra boost for theory concepts (chords, scales, harmony)
        let theoryKeywords = ["scale", "chord", "triad", "interval", "harmony", 
                            "melody", "mode", "cadence", "progression", "key"]
        for keyword in theoryKeywords {
            if termLower.contains(keyword) {
                priority += 20
                break
            }
        }
        
        // Boost for exact matches
        if !query.isEmpty {
            if termLower == query {
                priority += 200 // Exact match
            } else if termLower.hasPrefix(query) {
                priority += 100 // Starts with query
            } else if termLower.contains(query) {
                priority += 50 // Contains query
            }
        }
        
        // Boost for common terms
        let commonTerms = [
            "allegro", "adagio", "andante", "moderato", "presto",
            "piano", "forte", "mezzo", "crescendo", "decrescendo",
            "staccato", "legato", "trill", "mordent", "turn",
            "clef", "note", "rest", "sharp", "flat", "natural",
            "major", "minor", "scale", "chord"
        ]
        
        for commonTerm in commonTerms {
            if termLower.contains(commonTerm) {
                priority += 30
                break
            }
        }
        
        return priority
    }
    
    func searchSymbols(query: String) -> [MusicSymbol] {
        let showAdvanced = SettingsManager.shared.settings.showAdvancedDictionaryItems
        
        guard let dictionary = dictionary, !query.isEmpty else {
            // When no query, return common symbols first
            let symbols = dictionary?.symbols ?? []
            let filtered = showAdvanced ? symbols : filterCommonSymbols(symbols)
            return filtered.sorted(by: { symbolPriority($0) > symbolPriority($1) })
        }
        
        let lowercasedQuery = query.lowercased()
        let filtered = dictionary.symbols.filter { symbol in
            let matches = symbol.name.lowercased().contains(lowercasedQuery) ||
            symbol.description.lowercased().contains(lowercasedQuery) ||
            symbol.category.lowercased().contains(lowercasedQuery) ||
            symbol.unicode.lowercased().contains(lowercasedQuery)
            
            // Filter out advanced symbols if setting is off
            if !showAdvanced && !isCommonSymbol(symbol) {
                return false
            }
            
            return matches
        }
        
        // Sort by priority (common symbols first), then by name
        return filtered.sorted { first, second in
            let firstPriority = symbolPriority(first, query: lowercasedQuery)
            let secondPriority = symbolPriority(second, query: lowercasedQuery)
            
            if firstPriority != secondPriority {
                return firstPriority > secondPriority
            }
            return first.name < second.name
        }
    }
    
    /// Filter to show only common symbols
    private func filterCommonSymbols(_ symbols: [MusicSymbol]) -> [MusicSymbol] {
        return symbols.filter { isCommonSymbol($0) }
    }
    
    /// Check if a symbol is common (not advanced/specialized)
    private func isCommonSymbol(_ symbol: MusicSymbol) -> Bool {
        let category = symbol.category.lowercased()
        let nameLower = symbol.name.lowercased()
        
        // Advanced/specialized categories to hide
        let advancedCategories = [
            "sagittal", "promethean", "herculean", "olympian", "magrathean",
            "athenian", "trojan", "spartan", "johnston", "helmholtz",
            "wyschnegradsky", "arel-ezgi", "turkish folk", "persian",
            "arabic", "stockhausen", "kahnotation", "daseian", "kievan",
            "renaissance lute", "german organ", "medieval and renaissance",
            "beaters pictograms", "electronic music pictograms",
            "german renaissance", "french and english renaissance",
            "italian and spanish renaissance", "simplified music notation",
            "kodály hand signs", "function theory", "analytics"
        ]
        
        if advancedCategories.contains(where: { category.contains($0) }) {
            return false
        }
        
        // Very specialized symbol names
        let advancedNames = [
            "sagittal", "kahnotation", "daseian", "kievan", "kodály",
            "renaissance", "medieval", "organ tablature", "lute tablature"
        ]
        
        if advancedNames.contains(where: { nameLower.contains($0) }) {
            return false
        }
        
        return true
    }
    
    /// Calculate priority score for a symbol (higher = more common/important)
    private func symbolPriority(_ symbol: MusicSymbol, query: String = "") -> Int {
        let nameLower = symbol.name.lowercased()
        let categoryLower = symbol.category.lowercased()
        var priority = 0
        
        // High priority categories (common musical symbols)
        let highPriorityCategories = [
            "clefs", "noteheads", "notes", "rests", "accidentals", 
            "dynamics", "barlines", "time signatures", "staff", 
            "stems", "flags", "articulation", "ornaments"
        ]
        
        if highPriorityCategories.contains(where: { categoryLower.contains($0) }) {
            priority += 100
        }
        
        // Boost for exact matches on common terms
        let commonTerms = [
            "g clef", "treble clef", "f clef", "bass clef", "c clef",
            "whole note", "half note", "quarter note", "eighth note", "sixteenth note",
            "whole rest", "half rest", "quarter rest", "eighth rest",
            "sharp", "flat", "natural", "double sharp", "double flat",
            "piano", "forte", "mezzo", "crescendo", "decrescendo",
            "barline", "staff", "stem", "flag", "dot"
        ]
        
        for term in commonTerms {
            if nameLower.contains(term) {
                priority += 50
                break
            }
        }
        
        // Boost for name matches (exact or starts with)
        if !query.isEmpty {
            if nameLower == query {
                priority += 200 // Exact match
            } else if nameLower.hasPrefix(query) {
                priority += 100 // Starts with query
            } else if nameLower.contains(query) {
                priority += 50 // Contains query
            }
        }
        
        // Boost for common patterns in name
        let commonPatterns = ["clef", "note", "rest", "sharp", "flat", "natural", 
                             "piano", "forte", "barline", "staff", "stem"]
        for pattern in commonPatterns {
            if nameLower.contains(pattern) {
                priority += 10
                break
            }
        }
        
        return priority
    }
    
    func getTermsByCategory(_ category: String) -> [MusicTerm] {
        guard let dictionary = dictionary else { return [] }
        return dictionary.terms.filter { $0.category == category }
    }
    
    func getSymbolsByCategory(_ category: String) -> [MusicSymbol] {
        guard let dictionary = dictionary else { return [] }
        return dictionary.symbols.filter { $0.category == category }
    }
    
    
    var allCategories: [String] {
        guard let dictionary = dictionary else { return [] }
        let termCategories = Set(dictionary.terms.map { $0.category })
        let symbolCategories = Set(dictionary.symbols.map { $0.category })
        return Array(termCategories.union(symbolCategories)).sorted()
    }
}

