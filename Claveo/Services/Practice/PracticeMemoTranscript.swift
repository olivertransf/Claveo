//
//  PracticeMemoTranscript.swift
//  Claveo
//
//  Copyright (c) 2026 Oliver Tran

import Foundation

enum PracticeMemoTranscript {
    static var disclaimer: String {
        String(localized: "Transcript may be inaccurate.")
    }

    static func append(_ transcript: String, to existing: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return existing }
        let current = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty { return trimmed }
        return current + "\n\n" + trimmed
    }

    /// Pulls a transcript that was previously written into the notes back out.
    static func detached(_ entry: PracticeEntry) -> PracticeEntry {
        let split = splitEmbedded(notes: entry.notes, transcript: entry.voiceMemoTranscript)
        var copy = entry
        copy.notes = split.notes
        copy.voiceMemoTranscript = split.transcript
        return copy
    }

    static func splitEmbedded(notes: String?, transcript: String?) -> (notes: String?, transcript: String?) {
        guard let notes else { return (nil, blankToNil(transcript)) }
        guard let range = notes.range(of: disclaimer) else {
            return (blankToNil(notes), blankToNil(transcript))
        }
        let userNotes = String(notes[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let spoken = String(notes[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = append(spoken, to: transcript ?? "")
        return (userNotes.isEmpty ? nil : userNotes, blankToNil(combined))
    }

    private static func blankToNil(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

enum PracticeMemoTranscriptOutcome: Sendable {
    case text(String)
    case empty
    case denied
    case failed
}

struct TranscribedVoiceMemo: Sendable {
    var fileName: String
    /// Empty when the memo had no speech. Those memos are marked done and left out of the notes.
    var text: String
}

struct VoiceMemoTranscriptionBatch: Sendable {
    var completed: [TranscribedVoiceMemo] = []
    var message: String?
}

enum PracticeMemoNoteTranscription {
    static func transcribe(
        fileNames: [String],
        alreadyTranscribed: [String]
    ) async -> VoiceMemoTranscriptionBatch {
        var batch = VoiceMemoTranscriptionBatch()
        for fileName in fileNames where !alreadyTranscribed.contains(fileName) {
            if Task.isCancelled { return batch }
            switch await PracticeMemoTranscriber.transcript(for: fileName) {
            case .text(let text):
                batch.completed.append(TranscribedVoiceMemo(fileName: fileName, text: text))
            case .empty:
                batch.completed.append(TranscribedVoiceMemo(fileName: fileName, text: ""))
            case .denied:
                batch.message = String(localized: "Speech recognition is turned off.")
                return batch
            case .failed:
                batch.message = String(localized: "The voice memo could not be transcribed.")
            }
        }
        return batch
    }

    static func apply(
        _ batch: VoiceMemoTranscriptionBatch,
        transcript: inout String,
        transcribedFileNames: inout [String]
    ) {
        for memo in batch.completed where !transcribedFileNames.contains(memo.fileName) {
            if !memo.text.isEmpty {
                transcript = PracticeMemoTranscript.append(memo.text, to: transcript)
            }
            transcribedFileNames.append(memo.fileName)
        }
    }
}
