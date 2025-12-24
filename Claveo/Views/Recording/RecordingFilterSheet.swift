//
//  RecordingFilterSheet.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct RecordingFilterSheet: View {
    @Binding var selectedTag: String?
    @Binding var selectedPiece: String?
    let availablePieces: [Piece]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tag") {
                    Picker("Tag", selection: Binding(
                        get: { selectedTag ?? "" },
                        set: { newValue in
                            selectedTag = newValue.isEmpty ? nil : newValue
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
                        get: { selectedPiece ?? "" },
                        set: { newValue in
                            selectedPiece = newValue.isEmpty ? nil : newValue
                        }
                    )) {
                        Text("All").tag("")
                        ForEach(availablePieces, id: \.id) { piece in
                            Text(piece.displayName).tag(piece.name)
                        }
                    }
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

