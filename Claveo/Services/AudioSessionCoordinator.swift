import AVFoundation
import Foundation

extension Notification.Name {
    /// Posted before the tuner takes exclusive `.record` session ownership.
    static let claveoPlaybackShouldYieldForTuner = Notification.Name("Claveo.playbackShouldYieldForTuner")
    /// Posted after the tuner releases the audio session.
    static let claveoPlaybackMayResumeAfterTuner = Notification.Name("Claveo.playbackMayResumeAfterTuner")
}

/// Coordinates exclusive mic use (tuner) with app playback (metronome / tone).
@MainActor
enum AudioSessionCoordinator {
    static func prepareForTuner() {
        NotificationCenter.default.post(name: .claveoPlaybackShouldYieldForTuner, object: nil)
    }

    static func tunerDidReleaseSession() {
        NotificationCenter.default.post(name: .claveoPlaybackMayResumeAfterTuner, object: nil)
    }

    /// Deactivates only when no other Claveo feature still needs the session.
    static func deactivateIfIdle(metronomePlaying: Bool, tonePlaying: Bool) {
        guard !metronomePlaying, !tonePlaying else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Session activation blocks. Call it from a detached task, and use the async API on iOS 27.
nonisolated enum AudioSessionActivation {
    static func activate(_ session: AVAudioSession) async throws {
        if #available(iOS 27, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                session.activate(options: []) { activated, error in
                    if activated {
                        continuation.resume()
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            }
        } else {
            try session.setActive(true)
        }
    }
}
