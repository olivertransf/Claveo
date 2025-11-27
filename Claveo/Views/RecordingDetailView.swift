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
    @Environment(\.dismiss) private var dismiss
    
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
                
                Section("Pieces") {
                    ForEach(pieces) { piece in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(piece.name)
                                .font(.body)
                            if let composer = piece.composer {
                                Text(composer)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        pieces.remove(atOffsets: indexSet)
                        savePieces()
                    }
                }
            }
            .navigationTitle("Manage Pieces")
            .navigationBarTitleDisplayMode(.inline)
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
