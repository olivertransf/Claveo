//
//  RecordingFilterView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct RecordingFilter {
    var searchText: String = ""
    var selectedTag: String? = nil
    var selectedPiece: String? = nil
    var minDuration: TimeInterval? = nil
    var maxDuration: TimeInterval? = nil
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
    
    func matches(_ recording: Recording) -> Bool {
        // Search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            let matchesName = recording.name.lowercased().contains(searchLower)
            let matchesPiece = recording.piece?.lowercased().contains(searchLower) ?? false
            if !matchesName && !matchesPiece {
                return false
            }
        }
        
        // Tag filter
        if let selectedTag = selectedTag {
            if !recording.tags.contains(selectedTag) {
                return false
            }
        }
        
        // Piece filter
        if let selectedPiece = selectedPiece {
            if recording.piece != selectedPiece {
                return false
            }
        }
        
        // Duration filter
        if let minDuration = minDuration {
            if recording.duration < minDuration {
                return false
            }
        }
        if let maxDuration = maxDuration {
            if recording.duration > maxDuration {
                return false
            }
        }
        
        // Date filter
        if let dateFrom = dateFrom {
            if recording.createdAt < dateFrom {
                return false
            }
        }
        if let dateTo = dateTo {
            if recording.createdAt > dateTo {
                return false
            }
        }
        
        return true
    }
}

struct RecordingFilterView: View {
    @Binding var filter: RecordingFilter
    @State private var availablePieces: [Piece] = []
    @State private var showingFilters = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search recordings...", text: $filter.searchText)
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if filter.selectedTag != nil || filter.selectedPiece != nil || filter.minDuration != nil || filter.maxDuration != nil || filter.dateFrom != nil || filter.dateTo != nil {
                        Button(action: {
                            filter = RecordingFilter()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear Filters")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        }
                    }
                    
                    if filter.selectedTag != nil {
                        FilterChip(
                            title: filter.selectedTag!,
                            onRemove: { filter.selectedTag = nil }
                        )
                    }
                    
                    if filter.selectedPiece != nil {
                        FilterChip(
                            title: filter.selectedPiece!,
                            onRemove: { filter.selectedPiece = nil }
                        )
                    }
                    
                    Button(action: {
                        showingFilters = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filters")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemBlue))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingFilters) {
            FilterOptionsView(filter: $filter, availablePieces: availablePieces)
        }
        .onAppear {
            loadPieces()
        }
    }
    
    private func loadPieces() {
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("pieces.json")
        
        // Try to load from iCloud first
        do {
            let data = try iCloudManager.shared.readFile(from: fileURL)
            if let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
                availablePieces = decoded.sorted { $0.name < $1.name }
                // Update local cache
                UserDefaults.standard.set(data, forKey: "pieces_cache")
                return
            }
        } catch {
            // iCloud file doesn't exist or can't be read - try fallback
        }
        
        // Fallback to direct read from iCloud directory
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
            availablePieces = decoded.sorted { $0.name < $1.name }
            // Update local cache
            UserDefaults.standard.set(data, forKey: "pieces_cache")
            return
        }
        
        // Last resort: load from local cache (for offline access)
        if let cachedData = UserDefaults.standard.data(forKey: "pieces_cache"),
           let decoded = try? JSONDecoder().decode([Piece].self, from: cachedData) {
            availablePieces = decoded.sorted { $0.name < $1.name }
        }
    }
}

struct FilterChip: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
}

struct FilterOptionsView: View {
    @Binding var filter: RecordingFilter
    let availablePieces: [Piece]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var minMinutes: String = ""
    @State private var maxMinutes: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tag") {
                    Picker("Tag", selection: Binding(
                        get: { filter.selectedTag ?? "" },
                        set: { newValue in
                            filter.selectedTag = newValue.isEmpty ? nil : newValue
                        }
                    )) {
                        Text("All").tag("")
                        ForEach(RecordingTag.allCases, id: \.self) { tag in
                            Text(tag.rawValue).tag(tag.rawValue)
                        }
                    }
                }
                
                Section("Piece") {
                    Picker("Piece", selection: Binding(
                        get: { filter.selectedPiece ?? "" },
                        set: { newValue in
                            filter.selectedPiece = newValue.isEmpty ? nil : newValue
                        }
                    )) {
                        Text("All").tag("")
                        ForEach(availablePieces, id: \.id) { piece in
                            Text(piece.displayName).tag(piece.name)
                        }
                    }
                }
                
                Section("Duration") {
                    HStack {
                        Text("Min (minutes)")
                        Spacer()
                        TextField("0", text: $minMinutes)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: minMinutes) { _, newValue in
                                if let minutes = Double(newValue) {
                                    filter.minDuration = minutes * 60
                                } else {
                                    filter.minDuration = nil
                                }
                            }
                    }
                    
                    HStack {
                        Text("Max (minutes)")
                        Spacer()
                        TextField("∞", text: $maxMinutes)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: maxMinutes) { _, newValue in
                                if let minutes = Double(newValue) {
                                    filter.maxDuration = minutes * 60
                                } else {
                                    filter.maxDuration = nil
                                }
                            }
                    }
                }
                
                Section("Date Range") {
                    DatePicker("From", selection: Binding(
                        get: { filter.dateFrom ?? Date() },
                        set: { filter.dateFrom = $0 }
                    ), displayedComponents: .date)
                    
                    DatePicker("To", selection: Binding(
                        get: { filter.dateTo ?? Date() },
                        set: { filter.dateTo = $0 }
                    ), displayedComponents: .date)
                    
                    Button("Clear Date Range") {
                        filter.dateFrom = nil
                        filter.dateTo = nil
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
            .accentColor(themeManager.accentColor)
            .id(themeManager.accentColorOption)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

