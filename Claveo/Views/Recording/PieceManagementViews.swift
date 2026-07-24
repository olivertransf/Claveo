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
    @State private var persistenceError: String?
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
                            let trimmedName = newPieceName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedComposer = newPieceComposer.trimmingCharacters(in: .whitespacesAndNewlines)
                            let piece = Piece(
                                name: trimmedName,
                                composer: trimmedComposer.isEmpty ? nil : trimmedComposer
                            )
                            do {
                                pieces = try PieceService.upsert(piece)
                                newPieceName = ""
                                newPieceComposer = ""
                            } catch {
                                persistenceError = error.localizedDescription
                            }
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
                        do {
                            pieces = try PieceService.upsert(updatedPiece)
                        } catch {
                            persistenceError = error.localizedDescription
                        }
                        editingPiece = nil
                    },
                    onDelete: {
                        deletePiece(id: piece.id)
                        editingPiece = nil
                    },
                    onCancel: {
                        editingPiece = nil
                    }
                )
                .environmentObject(themeManager)
            }
            .alert("Unable to update piece library", isPresented: Binding(
                get: { persistenceError != nil },
                set: { if !$0 { persistenceError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(persistenceError ?? "")
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
        do {
            pieces = try PieceService.delete(id: id)
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func loadPiecesFromBinding() {
        pieces = PieceService.load()
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
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            composer: composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? nil
                                : composer.trimmingCharacters(in: .whitespacesAndNewlines),
                            createdAt: piece.createdAt,
                            lastModified: Date()
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
