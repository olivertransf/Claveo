//
//  PracticeMemoTranscriber.swift
//  Claveo
//
//  Copyright (c) 2026 Oliver Tran

import AVFoundation
import Foundation
import Speech

nonisolated enum PracticeMemoTranscriber {
    static func transcript(for fileName: String) async -> PracticeMemoTranscriptOutcome {
        guard await requestAuthorization() else { return .denied }
        await PracticeAttachmentStore.prepare(fileName)
        let url = await PracticeAttachmentStore.fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return .failed }

        if #available(iOS 26, *) {
            let analyzed = await transcriptWithAnalyzer(at: url)
            if case .failed = analyzed {
            } else {
                return analyzed
            }
        }
        return await transcriptWithRecognizer(at: url)
    }

    private static func requestAuthorization() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }
        if status == .denied || status == .restricted { return false }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { newStatus in
                continuation.resume(returning: newStatus == .authorized)
            }
        }
    }

    @available(iOS 26, *)
    private static func transcriptWithAnalyzer(at url: URL) async -> PracticeMemoTranscriptOutcome {
        let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
            ?? Locale(identifier: "en_US")
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        do {
            if await AssetInventory.status(forModules: [transcriber]) != .installed {
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    try await request.downloadAndInstall()
                }
            }
            let audioFile = try AVAudioFile(forReading: url)
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
            var text = ""
            for try await result in transcriber.results {
                guard result.isFinal else { continue }
                append(String(result.text.characters), to: &text)
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? .empty : .text(trimmed)
        } catch {
            return .failed
        }
    }

    private static func transcriptWithRecognizer(at url: URL) async -> PracticeMemoTranscriptOutcome {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else { return .failed }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        let spoken = await recognize(request, with: recognizer)
        guard let spoken else { return .failed }
        let trimmed = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .empty : .text(trimmed)
    }

    private static func recognize(
        _ request: SFSpeechURLRecognitionRequest,
        with recognizer: SFSpeechRecognizer
    ) async -> String? {
        let resume = ResumeOnce()
        let taskBox = RecognitionTaskBox()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                taskBox.task = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        resume.run {
                            continuation.resume(returning: result.bestTranscription.formattedString)
                        }
                    } else if error != nil {
                        resume.run {
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
        } onCancel: {
            taskBox.task?.cancel()
        }
    }

    private static func append(_ piece: String, to text: inout String) {
        let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if text.isEmpty {
            text = trimmed
        } else {
            text += " " + trimmed
        }
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func run(_ body: () -> Void) {
        lock.lock()
        let shouldRun = !resumed
        resumed = true
        lock.unlock()
        if shouldRun { body() }
    }
}

private final class RecognitionTaskBox: @unchecked Sendable {
    var task: SFSpeechRecognitionTask?
}
