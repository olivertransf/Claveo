//
//  QuickPracticeEntryView.swift
//  Claveo
//
//  Created by Oliver Tran on 12/22/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct QuickPracticeEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var practiceService = PracticeService.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var recorder = AudioRecorder()
    @State private var durationOptions: [Int] = []

    let date: Date
    @State private var duration: Int = 30
    @State private var notes = ""
    @State private var rating: Int? = nil
    @State private var showingRecordings = false
    @State private var selectedRecordings: Set<UUID> = []

    var existingEntry: PracticeEntry? {
        practiceService.entriesForDate(date).first
    }

    var body: some View {
        NavigationStack {
            Form {
                // Date Display
                Section {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(formattedDate(date))
                            .foregroundColor(.secondary)
                    }
                }

                // Duration
                Section("Duration") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(duration) min")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        HStack {
                            ForEach(durationOptions, id: \.self) { mins in
                                Button {
                                    duration = mins
                                } label: {
                                    Text("\(mins)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(duration == mins ? .white : themeManager.accentColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(duration == mins ? themeManager.accentColor : themeManager.accentColor.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Slider(value: .init(get: { Double(duration) }, set: { duration = Int($0) }),
                               in: 5...180, step: 5)
                            .tint(themeManager.accentColor)
                    }
                    .padding(.vertical, 4)
                }

                // Quick Notes
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .overlay(
                            Group {
                                if notes.isEmpty {
                                    VStack {
                                        HStack {
                                            Text("What did you practice?")
                                                .foregroundColor(.secondary)
                                                .padding(.top, 8)
                                                .padding(.leading, 5)
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                }
                            },
                            alignment: .topLeading
                        )
                }

                // Quick Rating
                Section("How did it go?") {
                    HStack(spacing: 16) {
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = (rating == star) ? nil : star
                            } label: {
                                Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundColor(.yellow)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // Linked Recordings (if any exist)
                if !recorder.recordings.isEmpty {
                    Section("Link Recording") {
                        Button {
                            showingRecordings = true
                        } label: {
                            HStack {
                                Text("Select Recordings")
                                Spacer()
                                if !selectedRecordings.isEmpty {
                                    Text("\(selectedRecordings.count)")
                                        .foregroundColor(themeManager.accentColor)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Delete existing entry
                if existingEntry != nil {
                    Section {
                        Button(role: .destructive) {
                            if let entry = existingEntry {
                                practiceService.deleteEntry(entry)
                            }
                            dismiss()
                        } label: {
                            Text("Delete Entry")
                        }
                    }
                }
            }
            .navigationTitle(existingEntry != nil ? "Edit Practice" : "Log Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingRecordings) {
                RecordingPickerView(selectedRecordings: $selectedRecordings, recordings: recorder.recordings)
            }
            .onAppear {
                durationOptions = settingsManager.settings.practiceDurationOptions
                if let entry = existingEntry {
                    duration = entry.duration
                    notes = entry.notes ?? ""
                    rating = entry.rating
                    selectedRecordings = Set(entry.linkedRecordingIds)
                } else {
                    duration = settingsManager.settings.defaultPracticeTime
                }
            }
        }
    }

    private func saveEntry() {
        let entry = PracticeEntry(
            date: date,
            duration: duration,
            notes: notes.isEmpty ? nil : notes,
            linkedRecordingIds: Array(selectedRecordings),
            rating: rating
        )

        if let existing = existingEntry {
            var updated = entry
            updated.id = existing.id
            practiceService.updateEntry(updated)
        } else {
            practiceService.addEntry(entry)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

}

#Preview {
    QuickPracticeEntryView(date: Date())
}
