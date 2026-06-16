import AVFoundation
import Foundation

enum WaveformExtractor {
    /// Returns normalized amplitudes in the range [0, 1] with exactly `bars` samples,
    /// each aligned to an equal slice of the file timeline.
    static func extractBars(from url: URL, bars: Int = 200) async throws -> [Float] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        return try await Task.detached(priority: .utility) {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let totalFrames = Int(file.length)
            guard totalFrames > 0 else { return [] }

            let targetBars = max(10, bars)
            var results = [Float]()
            results.reserveCapacity(targetBars)

            for barIndex in 0..<targetBars {
                let startFrame = (barIndex * totalFrames) / targetBars
                let endFrame = ((barIndex + 1) * totalFrames) / targetBars
                let frameCount = endFrame - startFrame

                guard frameCount > 0 else {
                    results.append(0)
                    continue
                }

                file.framePosition = AVAudioFramePosition(startFrame)

                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: AVAudioFrameCount(frameCount)
                ) else {
                    results.append(0)
                    continue
                }

                buffer.frameLength = AVAudioFrameCount(frameCount)
                try file.read(into: buffer)

                results.append(amplitude(for: buffer, format: format))
            }

            return normalize(results)
        }.value
    }

    private static func amplitude(for buffer: AVAudioPCMBuffer, format: AVAudioFormat) -> Float {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }

        if let channelData = buffer.floatChannelData {
            return amplitudeFromFloatChannels(channelData, channels: Int(format.channelCount), frames: frames)
        }

        if let channelData = buffer.int16ChannelData {
            return amplitudeFromInt16Channels(channelData, channels: Int(format.channelCount), frames: frames)
        }

        return 0
    }

    private static func amplitudeFromFloatChannels(
        _ channelData: UnsafePointer<UnsafeMutablePointer<Float>>,
        channels: Int,
        frames: Int
    ) -> Float {
        guard channels > 0 else { return 0 }

        var sumSquares: Float = 0
        var peak: Float = 0
        var sampleCount = 0

        for channel in 0..<channels {
            let data = channelData[channel]
            for index in 0..<frames {
                let sample = abs(data[index])
                sumSquares += sample * sample
                peak = max(peak, sample)
                sampleCount += 1
            }
        }

        let rms = sqrt(sumSquares / Float(max(sampleCount, 1)))
        return max(rms, peak * 0.4)
    }

    private static func amplitudeFromInt16Channels(
        _ channelData: UnsafePointer<UnsafeMutablePointer<Int16>>,
        channels: Int,
        frames: Int
    ) -> Float {
        guard channels > 0 else { return 0 }

        var sumSquares: Float = 0
        var peak: Float = 0
        var sampleCount = 0
        let scale: Float = 1.0 / Float(Int16.max)

        for channel in 0..<channels {
            let data = channelData[channel]
            for index in 0..<frames {
                let sample = abs(Float(data[index]) * scale)
                sumSquares += sample * sample
                peak = max(peak, sample)
                sampleCount += 1
            }
        }

        let rms = sqrt(sumSquares / Float(max(sampleCount, 1)))
        return max(rms, peak * 0.4)
    }

    private static func normalize(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }

        let sorted = samples.sorted()
        let referenceIndex = min(sorted.count - 1, Int(Double(sorted.count) * 0.95))
        let reference = max(sorted[referenceIndex], 0.0001)

        return samples.map { min(1, max(0, $0 / reference)) }
    }
}
