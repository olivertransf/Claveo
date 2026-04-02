//
//  ExercisesRootView.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct ExercisesRootView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        NoteIdentificationExerciseView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Note Identification")
                                    .font(.body)
                                Text("Name treble-clef notes including sharps and flats.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "music.note")
                                .foregroundStyle(themeManager.accentColor)
                        }
                    }
                } header: {
                    Text("Pitch")
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ExercisesRootView()
        .environmentObject(ThemeManager.shared)
}
