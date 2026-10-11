//
//  PracticeMemoRecorder.swift
//  Claveo
//
//  Copyright (c) 2026 Oliver Tran

import AVFoundation
import Combine
import Foundation

@MainActor
final class PracticeMemoRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?

    func toggle() async -> String? {
        if isRecording {
            return stop()
        }
        await start()
        return nil
    }

    func start() async {
        guard !isRecording else { return }
        errorMessage = nil
        if AVAudioApplication.shared.recordPermission != .granted {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else {
                errorMessage = String(localized: "Microphone access is required to record a voice memo.")
                return
            }
        }
        let url = PracticeAttachmentStore.newMemoURL()
        do {
            let started = try await Self.startRecorder(at: url)
            self.recorder = started.recorder
            fileURL = url
            elapsed = 0
            isRecording = true
            let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.elapsed = self?.recorder?.currentTime ?? 0
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } catch {
            errorMessage = String(localized: "The voice memo could not start.")
        }
    }

    private nonisolated static func startRecorder(at url: URL) async throws -> StartedMemo {
        try await Task.detached {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try await AudioSessionActivation.activate(session)
            let recorder = try AVAudioRecorder(url: url, settings: PracticeAttachmentStore.memoSettings())
            guard recorder.prepareToRecord(), recorder.record() else {
                throw CocoaError(.fileWriteUnknown)
            }
            return StartedMemo(recorder)
        }.value
    }

    func stop() -> String? {
        timer?.invalidate()
        timer = nil
        let duration = recorder?.currentTime ?? 0
        recorder?.stop()
        recorder = nil
        isRecording = false
        guard let fileURL else { return nil }
        self.fileURL = nil
        guard duration >= 0.3 else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        return fileURL.lastPathComponent
    }
}

private nonisolated final class StartedMemo: @unchecked Sendable {
    let recorder: AVAudioRecorder

    init(_ recorder: AVAudioRecorder) {
        self.recorder = recorder
    }
}

@MainActor
final class PracticeMemoPlayer: ObservableObject {
    @Published private(set) var playingFileName: String?

    private var player: AVAudioPlayer?

    func toggle(_ fileName: String) {
        if playingFileName == fileName {
            stop()
            return
        }
        stop()
        let url = PracticeAttachmentStore.fileURL(for: fileName)
        Task { await beginPlayback(of: fileName, url: url) }
    }

    private func beginPlayback(of fileName: String, url: URL) async {
        guard let playback = await Self.loadPlayer(at: url) else { return }
        guard playingFileName == nil else { return }
        playback.player.delegate = FinishProxy.shared
        FinishProxy.shared.onFinish = { [weak self] in
            self?.stop()
        }
        player = playback.player
        playingFileName = fileName
        await playback.play()
    }

    private nonisolated static func loadPlayer(at url: URL) async -> MemoPlayback? {
        await Task.detached {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try await AudioSessionActivation.activate(session)
                return MemoPlayback(try AVAudioPlayer(contentsOf: url))
            } catch {
                return nil
            }
        }.value
    }

    func stop() {
        player?.stop()
        player = nil
        playingFileName = nil
    }
}

private nonisolated final class MemoPlayback: @unchecked Sendable {
    let player: AVAudioPlayer

    init(_ player: AVAudioPlayer) {
        self.player = player
    }

    func play() async {
        let player = player
        await Task.detached {
            _ = player.play()
        }.value
    }
}

private final class FinishProxy: NSObject, AVAudioPlayerDelegate {
    static let shared = FinishProxy()
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finish = onFinish
        Task { @MainActor in
            finish?()
        }
    }
}
