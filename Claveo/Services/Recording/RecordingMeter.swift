import Foundation
import Combine

@MainActor
final class RecordingMeter: ObservableObject {
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var waveformLevels: [Float] = []

    func reset() {
        recordingTime = 0
        audioLevel = 0
        waveformLevels = []
    }
}
