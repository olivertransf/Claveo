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
    @ObservedObject private var recorder = AudioRecorder.shared
    @StateObject private var player = AudioPlayer()
    @State private var showingEditSheet = false
    @State private var isTranscribingMemo = false
    @State private var transcriptMessage: String?
    @State private var expandedRecordingId: UUID?

    init(entry: PracticeEntry) {
        _currentEntry = State(initialValue: PracticeMemoTranscript.detached(entry))
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
                                            .foregroundColor(star <= rating ? Color.themeRating : Color.secondary.opacity(0.45))
                                            .font(.caption)
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(String(localized: "Rating, \(rating) out of 5"))

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

                    PracticeEntryAttachmentsSummary(
                        photoFileNames: currentEntry.photoFileNames,
                        voiceMemoFileNames: currentEntry.voiceMemoFileNames
                    )

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

                    if isTranscribingMemo || transcriptMessage != nil || currentEntry.voiceMemoTranscript?.isEmpty == false {
                        VStack(alignment: .leading, spacing: 12) {
                            VoiceMemoTranscriptBox(transcript: currentEntry.voiceMemoTranscript ?? "")
                            VoiceMemoTranscriptStatus(
                                isTranscribing: isTranscribingMemo,
                                message: transcriptMessage
                            )
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
                                            set: { newValue in
                                                if newValue {
                                                    if let current = player.currentRecording, current.id != recording.id {
                                                        player.pause()
                                                    }
                                                    expandedRecordingId = recording.id
                                                } else {
                                                    player.pauseIfPlaying(recording)
                                                    if expandedRecordingId == recording.id {
                                                        expandedRecordingId = nil
                                                    }
                                                }
                                            }
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
            .task(id: showingEditSheet ? [] : currentEntry.voiceMemoFileNames) {
                guard !showingEditSheet else { return }
                await transcribeVoiceMemos()
            }
        }
    }

    private func transcribeVoiceMemos() async {
        var transcript = currentEntry.voiceMemoTranscript ?? ""
        var transcribed = currentEntry.transcribedVoiceMemoFileNames
        let originalTranscript = transcript
        let originalTranscribed = transcribed
        isTranscribingMemo = true
        defer { isTranscribingMemo = false }
        let batch = await PracticeMemoNoteTranscription.transcribe(
            fileNames: currentEntry.voiceMemoFileNames,
            alreadyTranscribed: transcribed
        )
        guard !Task.isCancelled else { return }
        PracticeMemoNoteTranscription.apply(
            batch,
            transcript: &transcript,
            transcribedFileNames: &transcribed
        )
        transcriptMessage = batch.message
        guard transcript != originalTranscript || transcribed != originalTranscribed else { return }
        var updated = currentEntry
        updated.voiceMemoTranscript = transcript.isEmpty ? nil : transcript
        updated.transcribedVoiceMemoFileNames = transcribed
        currentEntry = updated
        practiceService.updateEntry(updated)
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
                                        player.seek(recording, to: newValue)
                                    }
                                ),
                                in: 0...max(recording.duration, 0.1)
                            )
                            .tint(themeManager.accentColor)
                            .accessibilityLabel("Playback position")
                            .accessibilityValue(
                                formatTime(isDragging ? dragValue : (currentTime ?? 0))
                            )
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
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .accessibilityLabel("Skip back 15 seconds")
                        
                        Button(action: {
                            if isPlaying {
                                player.pause()
                            } else {
                                player.play(recording)
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .accessibilityLabel(isPlaying ? "Pause recording" : "Play recording")
                        
                        Button(action: { player.skipForward(seconds: 15) }) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 20))
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .accessibilityLabel("Skip forward 15 seconds")
                    }
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
    @ObservedObject private var recorder = AudioRecorder.shared

    @State private var date: Date
    @State private var duration: Int
    @State private var notes: String
    @State private var selectedRecordings: Set<UUID>
    @State private var photoFileNames: [String]
    @State private var voiceMemoFileNames: [String]
    @State private var transcribedVoiceMemoFileNames: [String]
    @State private var voiceMemoTranscript: String
    @State private var isTranscribingMemo = false
    @State private var transcriptMessage: String?
    @State private var originalAttachmentNames: Set<String>
    @State private var rating: Int?
    @State private var showingRecordingPicker = false

    init(entry: PracticeEntry, onSave: @escaping (PracticeEntry) -> Void = { _ in }) {
        let separated = PracticeMemoTranscript.detached(entry)
        self.entry = separated
        self.onSave = onSave
        _date = State(initialValue: separated.date)
        _duration = State(initialValue: separated.duration)
        _notes = State(initialValue: separated.notes ?? "")
        _selectedRecordings = State(initialValue: Set(separated.linkedRecordingIds))
        _photoFileNames = State(initialValue: separated.photoFileNames)
        _voiceMemoFileNames = State(initialValue: separated.voiceMemoFileNames)
        _transcribedVoiceMemoFileNames = State(initialValue: separated.transcribedVoiceMemoFileNames)
        _voiceMemoTranscript = State(initialValue: separated.voiceMemoTranscript ?? "")
        _originalAttachmentNames = State(initialValue: Set(separated.photoFileNames + separated.voiceMemoFileNames))
        _rating = State(initialValue: separated.rating)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Date and Duration
                Section("Practice Session") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                        .datePickerStyle(.compact)

                    PracticeDurationControls(
                        title: String(localized: "Duration"),
                        minutes: $duration,
                        maximum: SettingsManager.shared.settings.maximumPracticeMinutes
                    )
                    .padding(.vertical, 8)
                }

                Section("Photos and Voice Memos") {
                    PracticeEntryAttachmentsEditor(
                        photoFileNames: $photoFileNames,
                        voiceMemoFileNames: $voiceMemoFileNames
                    )
                }

                // Notes
                Section("Journal Entry") {
                    TextEditor(text: $notes)
                        .claveoFormTextEditor(minHeight: 120)
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
                    VoiceMemoTranscriptStatus(
                        isTranscribing: isTranscribingMemo,
                        message: transcriptMessage
                    )
                }
                .background {
                    VoiceMemoTranscriptionTask(
                        transcript: $voiceMemoTranscript,
                        transcribedFileNames: $transcribedVoiceMemoFileNames,
                        memoFileNames: voiceMemoFileNames,
                        isTranscribing: $isTranscribingMemo,
                        message: $transcriptMessage
                    )
                }
                if !voiceMemoTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        VoiceMemoTranscriptBox(transcript: voiceMemoTranscript)
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
                                        .foregroundColor(star <= (rating ?? 0) ? Color.themeRating : Color.secondary.opacity(0.45))
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
                        let current = Set(photoFileNames + voiceMemoFileNames)
                        PracticeAttachmentStore.remove(Array(current.subtracting(originalAttachmentNames)))
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
        let currentNames = Set(photoFileNames + voiceMemoFileNames)
        PracticeAttachmentStore.remove(Array(originalAttachmentNames.subtracting(currentNames)))
        var updatedEntry = PracticeEntry(
            date: date,
            duration: duration,
            notes: notes.isEmpty ? nil : notes,
            linkedRecordingIds: Array(selectedRecordings),
            photoFileNames: photoFileNames,
            voiceMemoFileNames: voiceMemoFileNames,
            transcribedVoiceMemoFileNames: transcribedVoiceMemoFileNames,
            voiceMemoTranscript: voiceMemoTranscript.isEmpty ? nil : voiceMemoTranscript,
            rating: rating
        )
        // Preserve the original ID
        updatedEntry.id = entry.id
        practiceService.updateEntry(updatedEntry)
        onSave(updatedEntry)
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

#Preview {
    PracticeEntryDetailView(entry: PracticeEntry(date: Date(), duration: 45, notes: "Great practice session today!", linkedRecordingIds: [], rating: 4))
}
