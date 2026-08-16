//
//  MusicDictionaryService.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation
import Combine

class MusicDictionaryService: ObservableObject {
    static let shared = MusicDictionaryService()
    
    @Published var dictionary: MusicDictionary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}

    /// Load JSON on first use from `MusicDictionaryView` so opening other overflow tabs (e.g. Practice) does not parse the dictionary.
    func loadDictionaryIfNeeded() {
        guard dictionary == nil, !isLoading else { return }
        loadDictionary()
    }

    /// Prefers `musicDictionary.<lang>.json` for the app's preferred localizations, then the base English file.
    private static func musicDictionaryURL() -> URL? {
        let codes = Bundle.main.preferredLocalizations.compactMap { localization -> String? in
            Locale(identifier: localization).language.languageCode?.identifier
        }
        var seen = Set<String>()
        for code in codes where seen.insert(code).inserted && code != "en" {
            if let url = Bundle.main.url(forResource: "musicDictionary.\(code)", withExtension: "json") {
                return url
            }
        }
        return Bundle.main.url(forResource: "musicDictionary", withExtension: "json")
    }

    func loadDictionary() {
        isLoading = true
        errorMessage = nil

        guard let url = Self.musicDictionaryURL() else {
            errorMessage = String(localized: "Dictionary file not found in bundle")
            isLoading = false
            return
        }

        Task {
            do {
                let data = try await Task.detached(priority: .utility) {
                    try Data(contentsOf: url)
                }.value
                dictionary = try JSONDecoder().decode(MusicDictionary.self, from: data)
                isLoading = false
            } catch {
                errorMessage = String(localized: "Failed to load dictionary: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }

    /// Search terms matching the query. Returns nothing when the query is empty.
    func searchAllTerms(query: String) -> [MusicTerm] {
        guard let dictionary = dictionary, !query.isEmpty else { return [] }

        let lowercasedQuery = query.lowercased()
        let filtered = dictionary.terms.filter { term in
            term.term.lowercased().contains(lowercasedQuery) ||
            term.definition.lowercased().contains(lowercasedQuery) ||
            term.category.lowercased().contains(lowercasedQuery) ||
            (term.example?.lowercased().contains(lowercasedQuery) ?? false)
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

    static let allCategoryToken = "__all__"

    /// Browse topics use categories assigned in musicDictionary.json.
    static var browseCategories: [(title: String, icon: String, category: String)] {
        [
            (String(localized: "All"), "books.vertical", allCategoryToken),
            (String(localized: "Tempo"), "metronome", "Tempo"),
            (String(localized: "Dynamics"), "speaker.wave.2.fill", "Dynamics"),
            (String(localized: "Articulation"), "waveform.path", "Articulation"),
            (String(localized: "Ornamentation"), "sparkles", "Ornamentation"),
            (String(localized: "Expression"), "face.smiling", "Expression"),
            (String(localized: "Rhythm"), "figure.wave", "Rhythm"),
            (String(localized: "Theory"), "music.note", "Theory"),
            (String(localized: "Notation"), "music.note.list", "Notation"),
            (String(localized: "Form"), "square.grid.2x2", "Form"),
            (String(localized: "Performance"), "person.3", "Performance"),
            (String(localized: "General"), "text.book.closed", "General")
        ]
    }

    func allTerms() -> [MusicTerm] {
        guard let dictionary = dictionary else { return [] }
        return dictionary.terms.sorted {
            $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending
        }
    }

    func terms(inCategory category: String) -> [MusicTerm] {
        guard let dictionary = dictionary else { return [] }
        return dictionary.terms
            .filter { $0.category == category }
            .sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
    }
    
    func getTermsByCategory(_ category: String) -> [MusicTerm] {
        guard let dictionary = dictionary else { return [] }
        return dictionary.terms.filter { $0.category == category }
    }
    
    var allCategories: [String] {
        guard let dictionary = dictionary else { return [] }
        let termCategories = Set(dictionary.terms.map { $0.category })
        return Array(termCategories).sorted()
    }
}

