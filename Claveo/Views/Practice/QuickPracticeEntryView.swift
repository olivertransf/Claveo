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
            ScrollView {
                VStack(spacing: 24) {
                    // Date header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(existingEntry != nil ? "Edit Session" : "Log Session")
                                .font(.title2.weight(.bold))
                            Text(formattedDate(date))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    // Duration card
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Duration", systemImage: "clock")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(duration)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("min")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                        }

                        if !durationOptions.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(durationOptions, id: \.self) { mins in
                                    Button { duration = mins } label: {
                                        Text("\(mins)")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(duration == mins ? .white : themeManager.accentColor)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(duration == mins ? themeManager.accentColor : themeManager.accentColor.opacity(0.1))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Slider(value: .init(get: { Double(duration) }, set: { duration = Int($0) }), in: 5...180, step: 5)
                            .tint(themeManager.accentColor)
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                    .padding(.horizontal, 20)

                    // Rating card
                    VStack(alignment: .leading, spacing: 14) {
                        Label("How did it go?", systemImage: "star")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 0) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                        rating = (rating == star) ? nil : star
                                    }
                                } label: {
                                    Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                                        .font(.system(size: 32))
                                        .foregroundStyle(star <= (rating ?? 0) ? .yellow : Color(.tertiaryLabel))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                        .scaleEffect(star <= (rating ?? 0) ? 1.1 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                    .padding(.horizontal, 20)

                    // Notes card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Notes", systemImage: "note.text")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("What did you practice today?")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 2)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $notes)
                                .font(.body)
                                .frame(minHeight: 90)
                                .scrollContentBackground(.hidden)
                        }
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                    .padding(.horizontal, 20)

                    // Link recordings
                    if !recorder.recordings.isEmpty {
                        Button {
                            showingRecordings = true
                        } label: {
                            HStack {
                                Label("Link Recording", systemImage: "waveform")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if !selectedRecordings.isEmpty {
                                    Text("\(selectedRecordings.count) linked")
                                        .font(.subheadline)
                                        .foregroundStyle(themeManager.accentColor)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(18)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }

                    // Delete
                    if existingEntry != nil {
                        Button(role: .destructive) {
                            if let entry = existingEntry { practiceService.deleteEntry(entry) }
                            dismiss()
                        } label: {
                            Text("Delete Entry")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.red.opacity(0.1)))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                        dismiss()
                    }
                    .fontWeight(.semibold)
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
