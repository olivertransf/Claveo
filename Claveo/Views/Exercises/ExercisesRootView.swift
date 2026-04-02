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
                    NavigationLink {
                        KeySignatureIdentificationExerciseView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Key Signature Identification")
                                    .font(.body)
                                Text("Name major or minor keys from the treble key signature.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "key.horizontal")
                                .foregroundStyle(themeManager.accentColor)
                        }
                    }
                    NavigationLink {
                        IntervalEarTrainingExerciseView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Interval Ear Training")
                                    .font(.body)
                                Text("Identify intervals from two short notes near octave 4.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.left.and.right")
                                .foregroundStyle(themeManager.accentColor)
                        }
                    }
                } header: {
                    Text("Pitch")
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ExercisesRootView()
        .environmentObject(ThemeManager.shared)
}
