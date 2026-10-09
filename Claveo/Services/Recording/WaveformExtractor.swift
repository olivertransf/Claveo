import AVFoundation
import Foundation

enum WaveformExtractor {
    private static let cachedBarCount = 512

    /// Returns normalized amplitudes in the range [0, 1] with exactly `bars` samples,
    /// each aligned to an equal slice of the file timeline.
    /// Full-resolution bars are cached under Caches/waveforms and downsampled for smaller requests.
    static func extractBars(from url: URL, bars: Int = 200) async throws -> [Float] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let stamp = Int(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
        let size = values?.fileSize ?? 0
        let cacheURL = cacheFileURL(fileName: url.lastPathComponent, stamp: stamp, size: size)

        let full: [Float]
        if let cached = readCache(at: cacheURL), cached.count == cachedBarCount {
            full = cached
        } else {
            full = try await computeBars(from: url, bars: cachedBarCount)
            writeCache(full, to: cacheURL)
        }

        let target = max(10, bars)
        if target == full.count { return full }
        return WaveformDrawing.resample(full, to: target)
    }

    private static func computeBars(from url: URL, bars: Int) async throws -> [Float] {
        try await Task.detached(priority: .utility) {
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

    private static func cacheFileURL(fileName: String, stamp: Int, size: Int) -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("waveforms", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeName = fileName.replacingOccurrences(of: "/", with: "-")
        return directory.appendingPathComponent("\(safeName)-\(stamp)-\(size).bin")
    }

    private static func readCache(at url: URL) -> [Float]? {
        guard let data = try? Data(contentsOf: url),
              !data.isEmpty,
              data.count.isMultiple(of: MemoryLayout<Float>.size) else { return nil }
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }

    private static func writeCache(_ samples: [Float], to url: URL) {
        let data = samples.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        try? data.write(to: url, options: .atomic)
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
