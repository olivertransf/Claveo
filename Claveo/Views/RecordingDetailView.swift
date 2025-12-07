//
//  RecordingDetailView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

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
        }
        .tint(themeManager.accentColor)
        .accentColor(themeManager.accentColor)
        .id(themeManager.accentColorOption)
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
}

struct PieceManagementView: View {
    @Binding var pieces: [Piece]
    @State private var newPieceName = ""
    @State private var newPieceComposer = ""
    @State private var editingPiece: Piece?
    @State private var editingName = ""
    @State private var editingComposer = ""
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
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
                            if editingPiece?.id == piece.id {
                                // Edit mode
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("Piece Name", text: $editingName)
                                    TextField("Composer (optional)", text: $editingComposer)
                                    
                                    HStack {
                                        Button("Cancel") {
                                            editingPiece = nil
                                            editingName = ""
                                            editingComposer = ""
                                        }
                                        .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Button("Save") {
                                            if let index = pieces.firstIndex(where: { $0.id == piece.id }) {
                                                pieces[index] = Piece(
                                                    id: piece.id,
                                                    name: editingName,
                                                    composer: editingComposer.isEmpty ? nil : editingComposer,
                                                    createdAt: piece.createdAt
                                                )
                                                savePieces()
                                            }
                                            editingPiece = nil
                                            editingName = ""
                                            editingComposer = ""
                                        }
                                        .fontWeight(.semibold)
                                        .disabled(editingName.isEmpty)
                                    }
                                }
                            } else {
                                // Display mode
                                Button(action: {
                                    editingPiece = piece
                                    editingName = piece.name
                                    editingComposer = piece.composer ?? ""
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
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func savePieces() {
        guard let encoded = try? JSONEncoder().encode(pieces) else { return }
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
