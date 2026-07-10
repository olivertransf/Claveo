//
//  PieceManagementViews.swift
//  Claveo
//
//  Library UI for creating, editing, and deleting pieces.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct PieceManagementView: View {
    @Binding var pieces: [Piece]
    @State private var newPieceName = ""
    @State private var newPieceComposer = ""
    @State private var editingPiece: Piece?
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    private var filteredPieces: [Piece] {
        if searchText.isEmpty {
            return pieces.sorted { $0.name < $1.name }
        }
        return pieces.filter { piece in
            piece.name.localizedCaseInsensitiveContains(searchText)
                || (piece.composer?.localizedCaseInsensitiveContains(searchText) ?? false)
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Piece title", text: $newPieceName)
                            .textFieldStyle(.claveoInset)
                            .textInputAutocapitalization(.words)
                        TextField("Composer (optional)", text: $newPieceComposer)
                            .textFieldStyle(.claveoInset)
                            .textInputAutocapitalization(.words)
                        Button {
                            HapticFeedback.lightImpact()
                            let piece = Piece(
                                name: newPieceName,
                                composer: newPieceComposer.isEmpty ? nil : newPieceComposer
                            )
                            pieces.append(piece)
                            pieces.sort { $0.name < $1.name }
                            savePieces()
                            newPieceName = ""
                            newPieceComposer = ""
                        } label: {
                            Label("Add to library", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(themeManager.accentColor)
                        .disabled(newPieceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("New piece")
                }

                Section {
                    if filteredPieces.isEmpty {
                        ContentUnavailableView {
                            Label(
                                searchText.isEmpty ? String(localized: "No pieces yet") : String(localized: "No matches"),
                                systemImage: "music.note.list"
                            )
                        } description: {
                            Text(
                                searchText.isEmpty
                                    ? String(localized: "Add a title above to start your repertoire list.")
                                    : String(localized: "Try a different search.")
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredPieces) { piece in
                            Button {
                                editingPiece = piece
                            } label: {
                                pieceRow(piece)
                            }
                            .claveoListRowChrome()
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deletePiece(id: piece.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Library")
                        Spacer()
                        if !pieces.isEmpty {
                            Text("\(pieces.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                    }
                }
            }
            .claveoInsetGroupedListStyle()
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pieces")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by title or composer")
            .tint(themeManager.accentColor)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
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

    @ViewBuilder
    private func pieceRow(_ piece: Piece) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(themeManager.accentColor.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: "music.note")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeManager.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(piece.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if let composer = piece.composer, !composer.isEmpty {
                    Text(composer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func deletePiece(id: UUID) {
        pieces.removeAll { $0.id == id }
        pieces.sort { $0.name < $1.name }
        savePieces()
    }

    private func loadPiecesFromBinding() {
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("pieces.json")

        do {
            let data = try iCloudManager.shared.readFile(from: fileURL)
            if let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
                pieces = decoded.sorted { $0.name < $1.name }
                UserDefaults.standard.set(data, forKey: "pieces_cache")
                return
            }
        } catch {}

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Piece].self, from: data) {
            pieces = decoded.sorted { $0.name < $1.name }
            UserDefaults.standard.set(data, forKey: "pieces_cache")
            return
        }

        if let cachedData = UserDefaults.standard.data(forKey: "pieces_cache"),
           let decoded = try? JSONDecoder().decode([Piece].self, from: cachedData) {
            pieces = decoded.sorted { $0.name < $1.name }
        }
    }

    private func savePieces() {
        pieces.sort { $0.name < $1.name }
        guard let encoded = try? JSONEncoder().encode(pieces) else {
            #if DEBUG
            print("Failed to encode pieces")
            #endif
            return
        }
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let fileURL = documentsPath.appendingPathComponent("pieces.json")
        UserDefaults.standard.set(encoded, forKey: "pieces_cache")
        do {
            try iCloudManager.shared.writeFile(data: encoded, to: fileURL)
        } catch {
            #if DEBUG
            print("Failed to save pieces to iCloud: \(error.localizedDescription)")
            #endif
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
            List {
                Section {
                    TextField("Title", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Composer (optional)", text: $composer)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Details")
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete piece", systemImage: "trash")
                    }
                }
            }
            .claveoInsetGroupedListStyle()
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .tint(themeManager.accentColor)
            .navigationTitle("Edit piece")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete piece?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("“\(piece.name)” will be removed from your library. Recordings already tagged with it are unchanged.")
            }
        }
    }
}
