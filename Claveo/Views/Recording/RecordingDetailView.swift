//
//  RecordingDetailView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct RecordingDetailView: View {
    @State var recording: Recording
    let onSave: (Recording) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var availablePieces: [Piece] = []
    @State private var showingPiecePicker = false
    @State private var measureStartText = ""
    /// Grows with Dynamic Type so measure numbers are never clipped.
    @ScaledMetric(relativeTo: .body) private var measureFieldWidth: CGFloat = 72
    @State private var measureEndText = ""
    @State private var showingTrimSheet = false
    @State private var showingRestoreAlert = false
    @State private var isRestoring = false
    @State private var restoreErrorMessage: String?
    @State private var showingRestoreError = false
    
    var body: some View {
        Form {
                Section {
                    TextField("Name", text: $recording.name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                }
                
                Section {
                    // Tags
                    if !recording.tags.isEmpty {
                        ForEach(recording.tags, id: \.self) { tag in
                            HStack {
                                Text(RecordingTag.localizedName(for: tag))
                                Spacer()
                                Button(action: {
                                    recording.tags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Picker("Add Tag", selection: Binding(
                        get: { "" },
                        set: { newValue in
                            if !newValue.isEmpty && !recording.tags.contains(newValue) {
                                recording.tags.append(newValue)
                            }
                        }
                    )) {
                        Text("Add Tag").tag("")
                        ForEach(RecordingTag.allCases, id: \.self) { tag in
                            if !recording.tags.contains(tag.rawValue) {
                                Text(tag.localizedName).tag(tag.rawValue)
                            }
                        }
                    }
                } header: {
                    Text("Tags")
                }
                
                Section {
                    Picker("Piece", selection: Binding(
                        get: { recording.piece ?? "" },
                        set: { newValue in
                            recording.piece = newValue.isEmpty ? nil : newValue
                        }
                    )) {
                        Text("None").tag("")
                        ForEach(availablePieces, id: \.id) { piece in
                            Text(piece.displayName).tag(piece.name)
                        }
                    }
                    
                    Button {
                        showingPiecePicker = true
                    } label: {
                        Label("Edit piece library", systemImage: "music.note.list")
                    }
                } header: {
                    Text("Piece")
                }
                
                Section {
                    HStack {
                        Text("Start")
                        Spacer()
                        TextField("mm.", text: $measureStartText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.claveoCompact)
                            .multilineTextAlignment(.trailing)
                            .frame(width: measureFieldWidth)
                            .onChange(of: measureStartText) { _, newValue in
                                let digitsOnly = newValue.filter(\.isNumber)
                                if digitsOnly != newValue {
                                    measureStartText = digitsOnly
                                }
                            }
                    }
                    
                    HStack {
                        Text("End")
                        Spacer()
                        TextField("mm.", text: $measureEndText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.claveoCompact)
                            .multilineTextAlignment(.trailing)
                            .frame(width: measureFieldWidth)
                            .onChange(of: measureEndText) { _, newValue in
                                let digitsOnly = newValue.filter(\.isNumber)
                                if digitsOnly != newValue {
                                    measureEndText = digitsOnly
                                }
                            }
                    }
                } header: {
                    Text("Measures")
                }
                
                Section {
                    DatePicker("Date", selection: $recording.createdAt, displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Text("Date & Time")
                }
                
                Section {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(recording.formattedDuration)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                } header: {
                    Text("Duration")
                }

                Section {
                    Button {
                        showingTrimSheet = true
                    } label: {
                        Label("Trim Recording", systemImage: "scissors")
                    }
                    .disabled(!FileManager.default.fileExists(atPath: recording.fileURL.path))
                    
                    if recording.hasTrimHistory, let originalURL = recording.originalFileURL, FileManager.default.fileExists(atPath: originalURL.path) {
                        Button {
                            showingRestoreAlert = true
                        } label: {
                            Label("Restore Original", systemImage: "arrow.counterclockwise")
                        }
                        .disabled(isRestoring)
                    }
                } header: {
                    Text("Audio")
                } footer: {
                    if !FileManager.default.fileExists(atPath: recording.fileURL.path) {
                        Text("Recording file not found.")
                    } else if recording.hasTrimHistory {
                        Text("Original audio is preserved. You can restore it anytime.")
                    } else {
                        Text("Trimming preserves the original audio for restoration.")
                    }
                }
                
                Section {
                    TextEditor(text: $recording.notes)
                        .claveoFormTextEditor(minHeight: 100)
                } header: {
                    Text("Notes")
                }
                
                Section {
                    if FileManager.default.fileExists(atPath: recording.fileURL.path) {
                        ShareLink(
                            item: RecordingFileTransferable(recording: recording),
                            preview: SharePreview(recording.displayName, icon: Image(systemName: "waveform"))
                        ) {
                            Label("Export Recording", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        HStack {
                            Label("Export Recording", systemImage: "square.and.arrow.up")
                            Spacer()
                            Text("File not found")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Export")
                }
        }
        .tint(themeManager.accentColor)
        .navigationTitle("Recording Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveAndDismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            loadPieces()
            measureStartText = recording.measureStart.map { String($0) } ?? ""
            measureEndText = recording.measureEnd.map { String($0) } ?? ""
        }
        .sheet(isPresented: $showingTrimSheet) {
            RecordingTrimView(recording: recording) { updatedRecording in
                recording.duration = updatedRecording.duration
                recording.originalFileName = updatedRecording.originalFileName
                recording.originalDuration = updatedRecording.originalDuration
                saveRecording()
            }
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingPiecePicker) {
            PieceManagementView(pieces: $availablePieces)
                .environmentObject(themeManager)
        }
        .onChange(of: showingPiecePicker) { _, isPresented in
            if !isPresented {
                // Reload pieces when sheet is dismissed to ensure we have the latest
                loadPieces()
            }
        }
        .alert("Restore Original Recording", isPresented: $showingRestoreAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restore") {
                Task { await restoreOriginal() }
            }
        } message: {
            if let originalDuration = recording.originalDuration {
                Text("Restore the original \(formatDuration(originalDuration)) recording? This will replace the current trimmed version.")
            } else {
                Text("Restore the original recording? This will replace the current trimmed version.")
            }
        }
        .alert("Restore Failed", isPresented: $showingRestoreError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(restoreErrorMessage ?? String(localized: "Could not restore the original recording."))
        }
    }
    
    private func restoreOriginal() async {
        guard let originalURL = recording.originalFileURL,
              FileManager.default.fileExists(atPath: originalURL.path) else {
            return
        }
        
        isRestoring = true
        
        do {
            try await RecordingTrimmer.restoreOriginal(
                recordingURL: recording.fileURL,
                backupURL: originalURL
            )
            
            var updated = recording
            updated.duration = updated.originalDuration ?? recording.duration
            updated.originalFileName = nil
            updated.originalDuration = nil
            updated.applyMeasureNumbers(startText: measureStartText, endText: measureEndText)
            updated.name = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            try? FileManager.default.removeItem(at: originalURL)
            
            onSave(updated)
            dismiss()
        } catch {
            restoreErrorMessage = error.localizedDescription
            showingRestoreError = true
        }
        
        isRestoring = false
    }

    private func saveAndDismiss() {
        commitEditableFields()
        onSave(recording)
        dismiss()
    }

    private func saveRecording() {
        commitEditableFields()
        onSave(recording)
    }

    private func commitEditableFields() {
        recording.name = recording.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let piece = recording.piece?.trimmingCharacters(in: .whitespacesAndNewlines), !piece.isEmpty {
            recording.piece = piece
        } else {
            recording.piece = nil
        }
        recording.applyMeasureNumbers(startText: measureStartText, endText: measureEndText)

        measureStartText = recording.measureStart.map(String.init) ?? ""
        measureEndText = recording.measureEnd.map(String.init) ?? ""
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadPieces() {
        availablePieces = PieceService.load()
    }
}
