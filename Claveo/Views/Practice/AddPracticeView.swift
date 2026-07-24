//
//  AddPracticeView.swift
//  Claveo
//
//  Created by Oliver Tran on 12/22/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct AddPracticeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var practiceService = PracticeService.shared
    @ObservedObject private var recorder = AudioRecorder.shared

    @State private var date = Date()
    @State private var duration = 30 // minutes
    @State private var notes = ""
    @State private var selectedRecordings: Set<UUID> = []
    @State private var rating: Int? = nil
    @State private var showingRecordingPicker = false

    var body: some View {
        NavigationStack {
            Form {
                // Date and Duration
                Section("Practice Session") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                        .datePickerStyle(.graphical)

                    VStack(alignment: .leading) {
                        Text("Duration: \(formatDuration(duration))")
                            .font(.headline)
                        Slider(value: .init(get: { Double(duration) }, set: { duration = Int($0) }),
                               in: 5...480, step: 5)
                        HStack {
                            Text("5 min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("8 hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Notes
                Section("Journal Entry") {
                    TextEditor(text: $notes)
                        .claveoFormTextEditor(minHeight: 100)
                        .placeholder(when: notes.isEmpty) {
                            Text("What did you practice today? Any goals, challenges, or progress notes...")
                                .foregroundColor(.secondary)
                        }
                }

                // Linked Recordings
                Section("Linked Recordings") {
                    if !recorder.recordings.isEmpty {
                        Button {
                            showingRecordingPicker = true
                        } label: {
                            HStack {
                                Text("Link Recordings")
                                Spacer()
                                Text("\(selectedRecordings.count) selected")
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }

                        if !selectedRecordings.isEmpty {
                            ForEach(recorder.recordings.filter { selectedRecordings.contains($0.id) }) { recording in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(recording.name.isEmpty ? String(localized: "Untitled") : recording.name)
                                            .font(.subheadline)
                                        Text(recording.formattedDuration)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button {
                                        selectedRecordings.remove(recording.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .frame(width: 44, height: 44)
                                    }
                                    .accessibilityLabel(
                                        String(localized: "Remove recording \(recording.displayName)")
                                    )
                                }
                            }
                        }
                    } else {
                        Text("No recordings available")
                            .foregroundColor(.secondary)
                    }
                }

                // Rating
                Section("How did you feel?") {
                    VStack(spacing: 16) {
                        Text("Rate your practice session")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
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
                                .accessibilityLabel(String(localized: "Rating, \(star) out of 5"))
                                .accessibilityAddTraits(rating == star ? .isSelected : [])
                            }
                        }

                        if let rating = rating {
                            Text(ratingDescription(rating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Practice Entry")
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
                    .disabled(duration == 0)
                }
            }
            .sheet(isPresented: $showingRecordingPicker) {
                RecordingPickerView(selectedRecordings: $selectedRecordings, recordings: recorder.recordings)
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
        practiceService.addEntry(entry)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return String(localized: "\(minutes) minutes")
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return hours == 1
                ? String(localized: "\(hours) hour")
                : String(localized: "\(hours) hours")
        }
        return String(localized: "\(hours) hours \(mins) min")
    }

    private func ratingDescription(_ rating: Int) -> String {
        switch rating {
        case 1: return String(localized: "Really struggled")
        case 2: return String(localized: "Had some challenges")
        case 3: return String(localized: "Decent session")
        case 4: return String(localized: "Good practice")
        case 5: return String(localized: "Amazing session!")
        default: return ""
        }
    }
}

// Recording Picker Sheet
struct RecordingPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedRecordings: Set<UUID>
    let recordings: [Recording]

    var body: some View {
        NavigationStack {
            List(recordings) { recording in
                Button {
                    if selectedRecordings.contains(recording.id) {
                        selectedRecordings.remove(recording.id)
                    } else {
                        selectedRecordings.insert(recording.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(recording.name.isEmpty ? String(localized: "Untitled") : recording.name)
                                .font(.headline)
                            Text(recording.formattedDate)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(recording.formattedDuration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedRecordings.contains(recording.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(selectedRecordings.contains(recording.id) ? .isSelected : [])
            }
            .navigationTitle("Select Recordings")
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
}

#Preview {
    AddPracticeView()
}
