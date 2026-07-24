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
