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
    @State private var selectedCategory: String?
    
    private var filteredTerms: [MusicTerm] {
        if !searchText.isEmpty {
            return dictionaryService.searchAllTerms(query: searchText)
        }
        if let selectedCategory {
            if selectedCategory == MusicDictionaryService.allCategoryToken {
                return dictionaryService.allTerms()
            }
            return dictionaryService.terms(inCategory: selectedCategory)
        }
        return []
    }

    private var categoryTitle: String? {
        guard let selectedCategory else { return nil }
        if selectedCategory == MusicDictionaryService.allCategoryToken {
            return String(localized: "All")
        }
        return MusicDictionaryService.browseCategories.first { $0.category == selectedCategory }?.title
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
                                HapticFeedback.lightImpact()
                                dictionaryService.loadDictionary()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    }
                } else if searchText.isEmpty, selectedCategory == nil {
                    DictionaryHomeView(onSelectCategory: { selectedCategory = $0 })
                        .environmentObject(themeManager)
                } else {
                    TermsListView(
                        terms: filteredTerms,
                        searchText: searchText,
                        categoryTitle: categoryTitle
                    )
                }
            }
            .navigationTitle(selectedCategory == nil ? String(localized: "Dictionary") : (categoryTitle ?? String(localized: "Dictionary")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedCategory != nil, searchText.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") {
                            selectedCategory = nil
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dictionary")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onChange(of: searchText) { _, newValue in
                if !newValue.isEmpty {
                    selectedCategory = nil
                }
            }
            .task(id: isTabSelected) {
                guard isTabSelected else { return }
                dictionaryService.loadDictionaryIfNeeded()
            }
        }
    }

    struct DictionaryHomeView: View {
        @EnvironmentObject var themeManager: ThemeManager
        let onSelectCategory: (String) -> Void

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Browse by Topic")
                        .font(.title3.weight(.bold))

                    LazyVStack(spacing: 12) {
                        ForEach(MusicDictionaryService.browseCategories, id: \.category) { item in
                            Button {
                                HapticFeedback.lightImpact()
                                onSelectCategory(item.category)
                            } label: {
                                CategoryBrowseCard(
                                    title: item.title,
                                    systemImage: item.icon,
                                    accentColor: themeManager.accentColor
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    struct CategoryBrowseCard: View {
        let title: String
        let systemImage: String
        let accentColor: Color

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(accentColor)
                    .frame(width: 28)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
        }
    }
    
    struct TermsListView: View {
        let terms: [MusicTerm]
        let searchText: String
        var categoryTitle: String?

        private var sortedTerms: [MusicTerm] {
            terms.sorted { $0.term < $1.term }
        }

        var body: some View {
            if terms.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "book.closed")
                } description: {
                    Text(emptyMessage)
                }
            } else {
                List {
                    ForEach(sortedTerms) { term in
                        NavigationLink {
                            TermDetailView(term: term)
                        } label: {
                            TermRowView(term: term)
                        }
                        .claveoListRowChrome()
                    }
                }
                .claveoInsetGroupedListStyle()
            }
        }

        private var emptyTitle: String {
            if !searchText.isEmpty { return String(localized: "No Results") }
            if categoryTitle != nil { return String(localized: "No Terms") }
            return String(localized: "No Terms")
        }

        private var emptyMessage: String {
            if !searchText.isEmpty { return String(localized: "Try a different search term") }
            if categoryTitle != nil { return String(localized: "No terms in this topic") }
            return String(localized: "Search or pick a topic to get started")
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

                    Text(term.localizedCategory)
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
                                
                                Text(term.localizedCategory)
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

