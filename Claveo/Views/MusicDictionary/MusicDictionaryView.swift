//
//  MusicDictionaryView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct MusicDictionaryView: View {
    /// When false (e.g. another overflow tab is visible), skip loading JSON so Practice and other tabs do not pay dictionary parse cost.
    var isTabSelected: Bool = true

    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var dictionaryService = MusicDictionaryService.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var searchText = ""
    @State private var isSearchPresented = false
    
    var filteredTerms: [MusicTerm] {
        return dictionaryService.searchAllTerms(query: searchText)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if dictionaryService.isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading dictionary...")
                        Spacer()
                    }
                } else if let error = dictionaryService.errorMessage {
                    VStack {
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
                    }
                } else {
                    TermsListView(terms: filteredTerms, searchText: searchText)
                }
            }
            .navigationTitle("Dictionary")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search dictionary")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .task(id: isTabSelected) {
                guard isTabSelected else { return }
                dictionaryService.loadDictionaryIfNeeded()
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
                    .background(.ultraThinMaterial)
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
            .background(.ultraThinMaterial)
            .cornerRadius(10)
        }
    }
    
    struct TermsListView: View {
        let terms: [MusicTerm]
        let searchText: String

        private var sortedTerms: [MusicTerm] {
            terms.sorted { $0.term < $1.term }
        }

        var body: some View {
            if terms.isEmpty {
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "No Terms" : "No Results", systemImage: "book.closed")
                } description: {
                    Text(searchText.isEmpty ? "No terms available" : "Try a different search term")
                }
            } else {
                List {
                    // Always show flat alphabetical list
                    ForEach(sortedTerms) { term in
                        NavigationLink {
                            TermDetailView(term: term)
                        } label: {
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
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(term.term)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(term.definition)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(term.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.themeFill)
                        .cornerRadius(8)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    struct TermDetailView: View {
        let term: MusicTerm
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with symbol
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 16) {
                            // Large symbol display if available
                            if let symbol = term.symbol, !symbol.isEmpty {
                                Text(symbol)
                                    .font(FontHelper.shared.bravuraSwiftUIFont(size: 56))
                                    .fontDesign(.none)
                                    .frame(width: 80, height: 80)
                                    .offset(y: 4) // Offset down to center better
                                    .background(Color.themeTertiaryBackground)
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(term.term)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                Text(term.category)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.themeFill)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Definition
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Definition")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(term.definition)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Example
                    if let example = term.example, !example.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Example")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("\"\(example)\"")
                                .font(.body)
                                .foregroundColor(.primary)
                                .italic()
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
}

#Preview {
    MusicDictionaryView()
}

