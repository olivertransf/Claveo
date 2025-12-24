//
//  PracticeEntryDetailView.swift
//  Claveo
//
//  Created by Oliver Tran on 12/22/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct PracticeEntryDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var practiceService = PracticeService.shared
    @State private var currentEntry: PracticeEntry
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var player = AudioPlayer()
    @State private var showingEditSheet = false
    @State private var expandedRecordingId: UUID?

    init(entry: PracticeEntry) {
        _currentEntry = State(initialValue: entry)
    }

    var linkedRecordings: [Recording] {
        recorder.recordings.filter { currentEntry.linkedRecordingIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with date, duration, and rating in one row
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentEntry.formattedDate)
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text(currentEntry.formattedDuration)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if let rating = currentEntry.rating {
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                    }
                                }

                                Text(ratingDescription(rating))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeSecondaryBackground)
                    .cornerRadius(12)

                    // Notes Section
                    if let notes = currentEntry.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Practice Notes")
                                .font(.headline)

                            Text(notes)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.themeSecondaryBackground)
                        .cornerRadius(12)
                    }

                    // Linked Recordings Section
                    if !linkedRecordings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Linked Recordings")
                                .font(.headline)

                            VStack(spacing: 8) {
                                ForEach(linkedRecordings) { recording in
                                    PracticeRecordingPlayer(
                                        recording: recording,
                                        player: player,
                                        isExpanded: Binding(
                                            get: { expandedRecordingId == recording.id },
                                            set: { expandedRecordingId = $0 ? recording.id : nil }
                                        ),
                                        isPlaying: player.isPlaying && player.currentRecording?.id == recording.id,
                                        currentTime: player.currentRecording?.id == recording.id ? player.currentTime : nil,
                                        playbackRate: player.playbackRate
                                    )
                                    .environmentObject(themeManager)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.themeSecondaryBackground)
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)

                            Text("No recordings linked")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Practice Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditPracticeView(entry: currentEntry) { updatedEntry in
                    currentEntry = updatedEntry
                }
            }
        }
    }

    private func ratingDescription(_ rating: Int) -> String {
        switch rating {
        case 1: return "Really struggled"
        case 2: return "Had some challenges"
        case 3: return "Decent session"
        case 4: return "Good practice"
        case 5: return "Amazing session!"
        default: return ""
        }
    }
}

// Practice Recording Player - similar to RecordingRowView
struct PracticeRecordingPlayer: View {
    @EnvironmentObject var themeManager: ThemeManager
    let recording: Recording
    let player: AudioPlayer
    @Binding var isExpanded: Bool
    let isPlaying: Bool
    let currentTime: TimeInterval?
    let playbackRate: Float
    
    @State private var isDragging = false
    @State private var dragValue: TimeInterval = 0
    
    var body: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: { isDragging ? dragValue : (currentTime ?? 0) },
                                    set: { newValue in
                                        dragValue = newValue
                                        if !isDragging {
                                            isDragging = true
                                        }
                                        player.seek(to: newValue)
                                    }
                                ),
                                in: 0...max(recording.duration, 0.1)
                            )
                            .tint(themeManager.accentColor)
                            .onChange(of: currentTime) { _, newValue in
                                guard let newValue = newValue else { return }
                                
                                if isDragging {
                                    if abs(newValue - dragValue) < 0.5 {
                                        isDragging = false
                                    }
                                } else {
                                    dragValue = newValue
                                }
                            }
                            
                            HStack {
                                Text(formatTime(isDragging ? dragValue : (currentTime ?? 0)))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                let remaining = max(0, recording.duration - (isDragging ? dragValue : (currentTime ?? 0)))
                                Text(isPlaying ? "-\(formatTime(remaining))" : formatTime(recording.duration))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Picker("Speed", selection: Binding(
                            get: { playbackRate },
                            set: { player.playbackRate = $0 }
                        )) {
                            Text("0.75x").tag(0.75 as Float)
                            Text("1x").tag(1.0 as Float)
                            Text("1.25x").tag(1.25 as Float)
                            Text("1.5x").tag(1.5 as Float)
                        }
                        .pickerStyle(.segmented)
                        .tint(themeManager.accentColor)
                    }
                    .padding(.vertical, 8)
                    
                    HStack(spacing: 0) {
                        Button(action: { player.skipBackward(seconds: 15) }) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        
                        Button(action: {
                            if isPlaying {
                                player.pause()
                            } else {
                                player.play(recording)
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        
                        Button(action: { player.skipForward(seconds: 15) }) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .padding(.horizontal, -20)
                }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recording.displayName)
                            .font(.headline)
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(recording.shortDateString)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(recording.formattedDuration)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .monospacedDigit()
                        
                        if isPlaying {
                            Image(systemName: "waveform")
                                .foregroundColor(themeManager.accentColor)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .padding()
        .background(Color.themeTertiaryBackground)
        .cornerRadius(8)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Edit Practice View
struct EditPracticeView: View {
    @Environment(\.dismiss) var dismiss
    let entry: PracticeEntry
    let onSave: (PracticeEntry) -> Void
    @StateObject private var practiceService = PracticeService.shared
    @StateObject private var recorder = AudioRecorder()

    @State private var date: Date
    @State private var duration: Int
    @State private var notes: String
    @State private var selectedRecordings: Set<UUID>
    @State private var rating: Int?
    @State private var showingRecordingPicker = false

    init(entry: PracticeEntry, onSave: @escaping (PracticeEntry) -> Void = { _ in }) {
        self.entry = entry
        self.onSave = onSave
        _date = State(initialValue: entry.date)
        _duration = State(initialValue: entry.duration)
        _notes = State(initialValue: entry.notes ?? "")
        _selectedRecordings = State(initialValue: Set(entry.linkedRecordingIds))
        _rating = State(initialValue: entry.rating)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Date and Duration
                Section("Practice Session") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                        .datePickerStyle(.compact)

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
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .overlay(
                            Group {
                                if notes.isEmpty {
                                    VStack {
                                        HStack {
                                            Text("What did you practice today? Any goals, challenges, or progress notes...")
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
                                        Text(recording.name.isEmpty ? "Untitled" : recording.name)
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
                                    }
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
                                .buttonStyle(.plain)
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

                // Delete Button
                Section {
                    Button(role: .destructive) {
                        practiceService.deleteEntry(entry)
                        dismiss()
                    } label: {
                        Text("Delete Practice Entry")
                    }
                }
            }
            .navigationTitle("Edit Practice Entry")
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
        var updatedEntry = PracticeEntry(
            date: date,
            duration: duration,
            notes: notes.isEmpty ? nil : notes,
            linkedRecordingIds: Array(selectedRecordings),
            rating: rating
        )
        // Preserve the original ID
        updatedEntry.id = entry.id
        practiceService.updateEntry(updatedEntry)
        onSave(updatedEntry)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                return "\(hours) hour\(hours == 1 ? "" : "s") \(mins) min"
            }
        }
    }

    private func ratingDescription(_ rating: Int) -> String {
        switch rating {
        case 1: return "Really struggled"
        case 2: return "Had some challenges"
        case 3: return "Decent session"
        case 4: return "Good practice"
        case 5: return "Amazing session!"
        default: return ""
        }
    }
}

#Preview {
    PracticeEntryDetailView(entry: PracticeEntry(date: Date(), duration: 45, notes: "Great practice session today!", linkedRecordingIds: [], rating: 4))
}
