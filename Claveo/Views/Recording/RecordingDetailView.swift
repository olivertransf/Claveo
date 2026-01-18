//
//  RecordingDetailView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct RecordingDetailView: View {
    @State var recording: Recording
    let onSave: (Recording) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var availablePieces: [Piece] = []
    @State private var showingPiecePicker = false
    @State private var measureStartText = ""
    @State private var measureEndText = ""
    
    var body: some View {
        Form {
                Section {
                    TextField("Name", text: $recording.name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                }
                
                Section {
                    // Tags
                    if !recording.tags.isEmpty {
                        ForEach(recording.tags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button(action: {
                                    recording.tags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Picker("Add Tag", selection: Binding(
                        get: { "" },
                        set: { newValue in
                            if !newValue.isEmpty && !recording.tags.contains(newValue) {
                                recording.tags.append(newValue)
                            }
                        }
                    )) {
                        Text("Add Tag").tag("")
                        ForEach(RecordingTag.allCases, id: \.self) { tag in
                            if !recording.tags.contains(tag.rawValue) {
                                Text(tag.rawValue).tag(tag.rawValue)
                            }
                        }
                    }
                } header: {
                    Text("Tags")
                }
                
                Section {
                    Picker("Piece", selection: Binding(
                        get: { recording.piece ?? "" },
                        set: { newValue in
                            recording.piece = newValue.isEmpty ? nil : newValue
                        }
                    )) {
                        Text("None").tag("")
                        ForEach(availablePieces, id: \.id) { piece in
                            Text(piece.displayName).tag(piece.name)
                        }
                    }
                    
                    Button("Manage Pieces") {
                        showingPiecePicker = true
                    }
                } header: {
                    Text("Piece")
                }
                
                Section {
                    HStack {
                        Text("Start")
                        Spacer()
                        TextField("mm.", text: $measureStartText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: measureStartText) { _, newValue in
                                recording.measureStart = Int(newValue)
                            }
                    }
                    
                    HStack {
                        Text("End")
                        Spacer()
                        TextField("mm.", text: $measureEndText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: measureEndText) { _, newValue in
                                recording.measureEnd = Int(newValue)
                            }
                    }
                } header: {
                    Text("Measures")
                }
                
                Section {
                    DatePicker("Date", selection: $recording.createdAt, displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Text("Date & Time")
                }
                
                Section {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(recording.formattedDuration)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                } header: {
                    Text("Duration")
                }
                
                Section {
                    TextEditor(text: $recording.notes)
                        .frame(minHeight: 100)
                } header: {
                    Text("Notes")
                }
                
                Section {
                    if FileManager.default.fileExists(atPath: recording.fileURL.path) {
                        ShareLink(
                            item: RecordingFileTransferable(recording: recording),
                            preview: SharePreview(recording.displayName, icon: Image(systemName: "waveform"))
                        ) {
                            Label("Export Recording", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        HStack {
                            Label("Export Recording", systemImage: "square.and.arrow.up")
                            Spacer()
                            Text("File not found")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Export")
                }
        }
        .tint(themeManager.accentColor)
        .navigationTitle("Recording Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    onSave(recording)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            loadPieces()
            measureStartText = recording.measureStart.map { String($0) } ?? ""
            measureEndText = recording.measureEnd.map { String($0) } ?? ""
        }
        .sheet(isPresented: $showingPiecePicker) {
            PieceManagementView(pieces: $availablePieces)
                .environmentObject(themeManager)
        }
        .onChange(of: showingPiecePicker) { _, isPresented in
            if !isPresented {
                // Reload pieces when sheet is dismissed to ensure we have the latest
                loadPieces()
            }
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
            UserDefaults.standard.set(data, forKey: "pieces_cache")
            return
        }
        
        // Last resort: load from local cache (for offline access)
        if let cachedData = UserDefaults.standard.data(forKey: "pieces_cache"),
           let decoded = try? JSONDecoder().decode([Piece].self, from: cachedData) {
            availablePieces = decoded.sorted { $0.name < $1.name }
        }
    }
    
    private func loadPiecesFromDisk() {
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("pieces.json")
        
        // Try to load from iCloud first
        do {
            let data = try iCloudManager.shared.readFile(from: fileURL)
            if let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
                availablePieces = decoded.sorted { $0.name < $1.name }
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

extension PieceManagementView {
    private func loadPiecesFromBinding() {
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("pieces.json")
        
        // Try to load from iCloud first
        do {
            let data = try iCloudManager.shared.readFile(from: fileURL)
            if let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
                pieces = decoded.sorted { $0.name < $1.name }
                UserDefaults.standard.set(data, forKey: "pieces_cache")
                return
            }
        } catch {
            // iCloud file doesn't exist or can't be read - try fallback
        }
        
        // Fallback to direct read from iCloud directory
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
            pieces = decoded.sorted { $0.name < $1.name }
            UserDefaults.standard.set(data, forKey: "pieces_cache")
            return
        }
        
        // Last resort: load from local cache (for offline access)
        if let cachedData = UserDefaults.standard.data(forKey: "pieces_cache"),
           let decoded = try? JSONDecoder().decode([Piece].self, from: cachedData) {
            pieces = decoded.sorted { $0.name < $1.name }
        }
    }
}

struct PieceManagementView: View {
    @Binding var pieces: [Piece]
    @State private var newPieceName = ""
    @State private var newPieceComposer = ""
    @State private var editingPiece: Piece?
    @State private var searchText = ""
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    private var filteredPieces: [Piece] {
        if searchText.isEmpty {
            return pieces.sorted { $0.name < $1.name }
        } else {
            return pieces.filter { piece in
                piece.name.localizedCaseInsensitiveContains(searchText) ||
                (piece.composer?.localizedCaseInsensitiveContains(searchText) ?? false)
            }.sorted { $0.name < $1.name }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Add New Piece") {
                    TextField("Piece Name", text: $newPieceName)
                    TextField("Composer (optional)", text: $newPieceComposer)
                    
                    Button("Add") {
                        let piece = Piece(name: newPieceName, composer: newPieceComposer.isEmpty ? nil : newPieceComposer)
                        pieces.append(piece)
                        pieces.sort { $0.name < $1.name }
                        savePieces()
                        newPieceName = ""
                        newPieceComposer = ""
                    }
                    .disabled(newPieceName.isEmpty)
                }
                
                Section {
                    if filteredPieces.isEmpty {
                        Text(searchText.isEmpty ? "No pieces" : "No matching pieces")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(filteredPieces) { piece in
                            Button(action: {
                                editingPiece = piece
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(piece.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        if let composer = piece.composer {
                                            Text(composer)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let sorted = filteredPieces
                            for index in indexSet {
                                if index < sorted.count {
                                    pieces.removeAll { $0.id == sorted[index].id }
                                }
                            }
                            pieces.sort { $0.name < $1.name }
                            savePieces()
                        }
                    }
                } header: {
                    HStack {
                        Text("Pieces")
                        Spacer()
                        if !pieces.isEmpty {
                            Text("\(pieces.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } footer: {
                    if !searchText.isEmpty {
                        Text("Searching: \"\(searchText)\"")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Manage Pieces")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search pieces")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                // Always load pieces when sheet appears to ensure we have the latest
                loadPiecesFromBinding()
            }
            .sheet(item: $editingPiece) { piece in
                PieceEditSheet(
                    piece: piece,
                    onSave: { updatedPiece in
                        if let index = pieces.firstIndex(where: { $0.id == updatedPiece.id }) {
                            pieces[index] = updatedPiece
                            pieces.sort { $0.name < $1.name }
                            savePieces()
                        }
                        editingPiece = nil
                    },
                    onDelete: {
                        pieces.removeAll { $0.id == piece.id }
                        pieces.sort { $0.name < $1.name }
                        savePieces()
                        editingPiece = nil
                    },
                    onCancel: {
                        editingPiece = nil
                    }
                )
                .environmentObject(themeManager)
            }
        }
    }
    
    private func savePieces() {
        // Ensure pieces are sorted
        pieces.sort { $0.name < $1.name }
        
        guard let encoded = try? JSONEncoder().encode(pieces) else {
            #if DEBUG
            print("Failed to encode pieces")
            #endif
            return
        }
        
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("pieces.json")
        
        // Save to local cache first (UserDefaults) for offline access
        UserDefaults.standard.set(encoded, forKey: "pieces_cache")
        
        // Then save to iCloud (will queue if offline)
        do {
            try iCloudManager.shared.writeFile(data: encoded, to: fileURL)
        } catch {
            #if DEBUG
            print("Failed to save pieces to iCloud: \(error.localizedDescription)")
            #endif
            // Fallback to direct write if coordination fails (iOS will queue for sync)
            try? encoded.write(to: fileURL, options: [.atomic])
        }
    }
}

struct PieceEditSheet: View {
    let piece: Piece
    let onSave: (Piece) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void
    
    @State private var name: String
    @State private var composer: String
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    init(piece: Piece, onSave: @escaping (Piece) -> Void, onDelete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.piece = piece
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _name = State(initialValue: piece.name)
        _composer = State(initialValue: piece.composer ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Piece Name", text: $name)
                    TextField("Composer (optional)", text: $composer)
                } header: {
                    Text("Edit Piece")
                }
                
                Section {
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete Piece")
                            Spacer()
                        }
                    }
                }
            }
            .tint(themeManager.accentColor)
            .navigationTitle("Edit Piece")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let updatedPiece = Piece(
                            id: piece.id,
                            name: name,
                            composer: composer.isEmpty ? nil : composer,
                            createdAt: piece.createdAt
                        )
                        onSave(updatedPiece)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
            .alert("Delete Piece", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete \"\(piece.name)\"? This cannot be undone.")
            }
        }
    }
}
