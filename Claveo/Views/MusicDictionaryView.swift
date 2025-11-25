//
//  MusicDictionaryView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct MusicDictionaryView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var dictionaryService = MusicDictionaryService.shared
    @AppStorage("showAdvancedDictionaryItems") private var showAdvancedDictionaryItems: Bool = true
    @State private var searchText = ""
    @State private var selectedTab: DictionaryTab = .dictionary
    
    enum DictionaryTab: String, CaseIterable, Hashable {
        case dictionary = "Dictionary"
        case symbols = "Symbols"
    }
    
    var filteredTerms: [MusicTerm] {
        dictionaryService.searchAllTerms(query: searchText)
    }
    
    var filteredSymbols: [MusicSymbol] {
        dictionaryService.searchSymbols(query: searchText)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Tab selector
                Picker("Dictionary Type", selection: $selectedTab) {
                    ForEach(DictionaryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Content
                if dictionaryService.isLoading {
                    Spacer()
                    ProgressView("Loading dictionary...")
                    Spacer()
                } else if let error = dictionaryService.errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Error Loading Dictionary")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            dictionaryService.loadDictionary()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else {
                    if selectedTab == .dictionary {
                        TermsListView(terms: filteredTerms, searchText: searchText)
                    } else {
                        SymbolsListView(symbols: filteredSymbols, searchText: searchText)
                    }
                }
            }
            .navigationTitle("Music Dictionary")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search...", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct TermsListView: View {
    let terms: [MusicTerm]
    let searchText: String
    
    var groupedTerms: [String: [MusicTerm]] {
        Dictionary(grouping: terms) { $0.category }
    }
    
    var sortedCategories: [String] {
        // Prioritize common categories first
        let priorityCategories = [
            "Theory", "Tempo", "Dynamics", "Articulation", 
            "Notation", "Form", "General"
        ]
        
        let categories = groupedTerms.keys.sorted()
        let prioritized = categories.filter { priorityCategories.contains($0) }
        let others = categories.filter { !priorityCategories.contains($0) }
        
        return prioritized + others.sorted()
    }
    
    var body: some View {
        if terms.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text(searchText.isEmpty ? "No terms available" : "No results found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                if !searchText.isEmpty {
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if searchText.isEmpty {
                    // Grouped by category when not searching
                    ForEach(sortedCategories, id: \.self) { category in
                        Section(category) {
                            ForEach(groupedTerms[category] ?? []) { term in
                                TermRowView(term: term)
                            }
                        }
                    }
                } else {
                    // Flat list when searching
                    ForEach(terms) { term in
                        TermRowView(term: term)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

struct TermRowView: View {
    let term: MusicTerm
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(term.term)
                    .font(.headline)
                Spacer()
                Text(term.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.themeFill)
                    .cornerRadius(8)
            }
            
            Text(term.definition)
                .font(.body)
                .foregroundColor(.primary)
            
            if let example = term.example, !example.isEmpty {
                Text("\"\(example)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
}

struct SymbolsListView: View {
    let symbols: [MusicSymbol]
    let searchText: String
    
    var groupedSymbols: [String: [MusicSymbol]] {
        Dictionary(grouping: symbols) { $0.category }
    }
    
    var sortedCategories: [String] {
        groupedSymbols.keys.sorted()
    }
    
    var body: some View {
        if symbols.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text(searchText.isEmpty ? "No symbols available" : "No results found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                if !searchText.isEmpty {
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if searchText.isEmpty {
                    // Grouped by category when not searching
                    ForEach(sortedCategories, id: \.self) { category in
                        Section(category) {
                            ForEach(groupedSymbols[category] ?? []) { symbol in
                                SymbolRowView(symbol: symbol)
                            }
                        }
                    }
                } else {
                    // Flat list when searching
                    ForEach(symbols) { symbol in
                        SymbolRowView(symbol: symbol)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

struct SymbolRowView: View {
    let symbol: MusicSymbol
    
    // Custom font for musical symbols - Bravura ONLY (SMuFL reference font)
    private var musicFont: Font {
        return FontHelper.shared.bravuraSwiftUIFont(size: 32)
    }
    
    // Get the display symbol - ALWAYS use SMuFL codes (NO Unicode)
    // Symbols are already stored with SMuFL characters in the JSON
    private var displaySymbol: String {
        // Symbols are already stored as SMuFL characters (Private Use Area U+E000-U+F8FF)
        // Just use the stored symbol directly - it's already a SMuFL character
        if !symbol.symbol.isEmpty {
            return symbol.symbol
        }
        
        // If symbol is empty, try to generate from SMuFL code
        let smuflCode = symbol.smuflCode ?? symbol.unicode
        if smuflCode.hasPrefix("U+E") || smuflCode.hasPrefix("U+F") {
            if let char = SMuFLMapper.shared.character(from: smuflCode) {
                return String(char)
            }
        }
        
        // No valid SMuFL code - return placeholder
        return "?"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Symbol display - ensure Bravura font is used
            Text(displaySymbol)
                .font(musicFont)
                .fontDesign(.none) // Prevent system font fallback
                .frame(width: 50, height: 50)
                .background(Color.themeTertiaryBackground)
                .cornerRadius(8)
            
            // Symbol info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(symbol.name)
                        .font(.headline)
                    Spacer()
                    Text(symbol.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.themeFill)
                        .cornerRadius(8)
                }
                
                Text(symbol.description)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text("SMuFL: \(symbol.smuflCode ?? symbol.unicode)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MusicDictionaryView()
}

