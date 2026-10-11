//
//  VoiceMemoTranscriptStatus.swift
//  Claveo
//
//  Copyright (c) 2026 Oliver Tran

import SwiftUI

struct VoiceMemoTranscriptStatus: View {
    var isTranscribing: Bool
    var message: String?

    var body: some View {
        if isTranscribing || message != nil {
            status
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isTranscribing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Transcribing voice memo…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VoiceMemoTranscriptBox: View {
    var transcript: String

    private var trimmed: String {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if !trimmed.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcript from voice memo")
                    .font(.subheadline.weight(.semibold))
                Text(trimmed)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Text("(\(PracticeMemoTranscript.disclaimer))")
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct VoiceMemoTranscriptionTask: View {
    @Binding var transcript: String
    @Binding var transcribedFileNames: [String]
    var memoFileNames: [String]
    @Binding var isTranscribing: Bool
    @Binding var message: String?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: memoFileNames) {
                let pending = memoFileNames.filter { !transcribedFileNames.contains($0) }
                guard !pending.isEmpty else { return }
                isTranscribing = true
                message = nil
                defer { isTranscribing = false }
                let batch = await PracticeMemoNoteTranscription.transcribe(
                    fileNames: memoFileNames,
                    alreadyTranscribed: transcribedFileNames
                )
                guard !Task.isCancelled else { return }
                PracticeMemoNoteTranscription.apply(
                    batch,
                    transcript: &transcript,
                    transcribedFileNames: &transcribedFileNames
                )
                message = batch.message
            }
    }
}
