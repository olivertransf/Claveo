import AVFoundation
import Foundation

enum WaveformExtractor {
    /// Returns normalized amplitudes in the range [0, 1] with `bars` samples.
    static func extractBars(from url: URL, bars: Int = 200) async throws -> [Float] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        return try await Task.detached(priority: .utility) {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat

            let totalFrames = Int(file.length)
            guard totalFrames > 0 else { return [] }

            let targetBars = max(10, bars)
            let framesPerBar = max(1, totalFrames / targetBars)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(framesPerBar)
            ) else {
                return []
            }

            var results: [Float] = []
            results.reserveCapacity(targetBars)

            while Int(file.framePosition) < totalFrames {
                let remaining = totalFrames - Int(file.framePosition)
                let toRead = min(framesPerBar, remaining)
                buffer.frameLength = AVAudioFrameCount(toRead)

                // For compressed sources (e.g. m4a), AVAudioFile decodes into processingFormat.
                // Reading in small chunks avoids huge allocations and avoids format mismatch errors.
                try file.read(into: buffer)

                guard let channelData = buffer.floatChannelData else { continue }

                let channels = Int(format.channelCount)
                let frames = Int(buffer.frameLength)

                var peak: Float = 0
                if frames > 0, channels > 0 {
                    for ch in 0..<channels {
                        let data = channelData[ch]
                        var localPeak: Float = 0
                        for i in 0..<frames {
                            let v = abs(data[i])
                            if v > localPeak { localPeak = v }
                        }
                        if localPeak > peak { peak = localPeak }
                    }
                }

                results.append(peak)
            }

            let maxValue = results.max() ?? 0
            if maxValue > 0 {
                return results.map { min(1, max(0, $0 / maxValue)) }
            }
            return results
        }.value
    }
}

