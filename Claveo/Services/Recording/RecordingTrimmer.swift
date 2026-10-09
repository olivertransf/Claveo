import AVFoundation
import Foundation

enum RecordingTrimmerError: LocalizedError {
    case fileNotFound
    case invalidRange
    case exportSessionUnavailable
    case exportFailed(underlying: Error?)
    case replaceFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return String(localized: "Recording file not found.")
        case .invalidRange:
            return String(localized: "Invalid trim range.")
        case .exportSessionUnavailable:
            return String(localized: "Unable to create export session for this audio file.")
        case .exportFailed(let underlying):
            if let underlying {
                return String(localized: "Failed to trim recording: \(underlying.localizedDescription)")
            }
            return String(localized: "Failed to trim recording.")
        case .replaceFailed:
            return String(localized: "Trim completed, but replacing the original file failed.")
        }
    }
}

enum RecordingTrimmer {
    private final class ExportSessionHolder: @unchecked Sendable {
        let session: AVAssetExportSession

        init(_ session: AVAssetExportSession) {
            self.session = session
        }
    }

    static func trimNonDestructive(recordingURL: URL, startTime: TimeInterval, endTime: TimeInterval) async throws -> (trimmedURL: URL, backupURL: URL, originalDuration: TimeInterval) {
        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            throw RecordingTrimmerError.fileNotFound
        }
        
        let asset = AVURLAsset(url: recordingURL)
        let assetDurationSeconds: TimeInterval
        do {
            assetDurationSeconds = try await asset.load(.duration).seconds
        } catch {
            throw RecordingTrimmerError.exportSessionUnavailable
        }
        guard assetDurationSeconds.isFinite, assetDurationSeconds > 0 else {
            throw RecordingTrimmerError.exportSessionUnavailable
        }
        
        let documentsPath = iCloudManager.shared.getDocumentsURL()
        let backupFileName = "original_\(UUID().uuidString).\(fileExtension(of: recordingURL))"
        let backupURL = documentsPath.appendingPathComponent(backupFileName)
        
        if FileManager.default.fileExists(atPath: backupURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
        }
        
        try FileManager.default.copyItem(at: recordingURL, to: backupURL)
        
        do {
            let trimmedURL = try await trimToTemp(
                recordingURL: recordingURL,
                startTime: startTime,
                endTime: endTime,
                assetDuration: assetDurationSeconds
            )
            return (
                trimmedURL: trimmedURL,
                backupURL: backupURL,
                originalDuration: assetDurationSeconds
            )
        } catch {
            try? deleteBackup(at: backupURL)
            throw error
        }
    }
    
    static func restoreOriginal(recordingURL: URL, backupURL: URL) async throws {
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw RecordingTrimmerError.fileNotFound
        }
        
        let stagedURL = recordingURL.deletingLastPathComponent()
            .appendingPathComponent("restore_\(UUID().uuidString).\(fileExtension(of: backupURL))")
        do {
            try FileManager.default.copyItem(at: backupURL, to: stagedURL)
            if FileManager.default.fileExists(atPath: recordingURL.path) {
                _ = try FileManager.default.replaceItemAt(
                    recordingURL,
                    withItemAt: stagedURL
                )
            } else {
                try FileManager.default.moveItem(at: stagedURL, to: recordingURL)
            }
            try deleteBackup(at: backupURL)
        } catch {
            try? FileManager.default.removeItem(at: stagedURL)
            throw RecordingTrimmerError.replaceFailed
        }
    }

    static func deleteBackup(at backupURL: URL) throws {
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return }
        try FileManager.default.removeItem(at: backupURL)
    }
    
    private static func trimToTemp(recordingURL: URL, startTime: TimeInterval, endTime: TimeInterval, assetDuration: TimeInterval) async throws -> URL {

        let minimumDuration: TimeInterval = 0.1
        guard startTime >= 0, endTime > startTime + minimumDuration else {
            throw RecordingTrimmerError.invalidRange
        }

        let clampedStart = max(0, min(startTime, assetDuration))
        let clampedEnd = max(0, min(endTime, assetDuration))
        guard clampedEnd > clampedStart + minimumDuration else {
            throw RecordingTrimmerError.invalidRange
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString).\(fileExtension(of: recordingURL))")

        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }

        if usesFrameCopy(recordingURL) {
            try copyFrames(
                from: recordingURL,
                to: tempURL,
                startTime: clampedStart,
                endTime: clampedEnd
            )
        } else {
            try await exportPassthrough(
                recordingURL: recordingURL,
                to: tempURL,
                startTime: clampedStart,
                endTime: clampedEnd
            )
        }

        return tempURL
    }

    private static func fileExtension(of url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? "m4a" : ext
    }

    private static func usesFrameCopy(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "wav" || ext == "aiff" || ext == "caf" { return true }
        guard let file = try? AVAudioFile(forReading: url) else { return false }
        return audioFormatID(file.fileFormat.settings) == kAudioFormatAppleLossless
    }

    private static func audioFormatID(_ settings: [String: Any]) -> AudioFormatID {
        let value = settings[AVFormatIDKey]
        if let identifier = value as? AudioFormatID { return identifier }
        if let number = value as? NSNumber { return number.uint32Value }
        return 0
    }

    private static func exportPassthrough(
        recordingURL: URL,
        to tempURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) async throws {
        let asset = AVURLAsset(url: recordingURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw RecordingTrimmerError.exportSessionUnavailable
        }
        exporter.outputURL = tempURL
        exporter.outputFileType = fileExtension(of: recordingURL) == "wav" ? .wav : .m4a
        let timescale: CMTimeScale = 600
        let start = CMTime(seconds: startTime, preferredTimescale: timescale)
        let end = CMTime(seconds: endTime, preferredTimescale: timescale)
        exporter.timeRange = CMTimeRangeFromTimeToTime(start: start, end: end)

        let exportHolder = ExportSessionHolder(exporter)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportHolder.session.exportAsynchronously {
                let status = exportHolder.session.status
                let exportError = exportHolder.session.error
                switch status {
                case .completed:
                    continuation.resume()
                default:
                    continuation.resume(throwing: RecordingTrimmerError.exportFailed(underlying: exportError))
                }
            }
        }
    }

    private static func copyFrames(
        from sourceURL: URL,
        to destinationURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) throws {
        let source = try AVAudioFile(forReading: sourceURL)
        let format = source.processingFormat
        let sampleRate = format.sampleRate
        guard sampleRate > 0 else { throw RecordingTrimmerError.exportSessionUnavailable }

        let startFrame = AVAudioFramePosition(startTime * sampleRate)
        let endFrame = AVAudioFramePosition(endTime * sampleRate)
        guard endFrame > startFrame else { throw RecordingTrimmerError.invalidRange }

        source.framePosition = startFrame
        let destination = try AVAudioFile(forWriting: destinationURL, settings: source.fileFormat.settings)
        var remaining = AVAudioFrameCount(endFrame - startFrame)
        let chunkSize: AVAudioFrameCount = 8_192

        while remaining > 0 {
            let frames = min(chunkSize, remaining)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
                throw RecordingTrimmerError.exportFailed(underlying: nil)
            }
            try source.read(into: buffer, frameCount: frames)
            if buffer.frameLength == 0 { break }
            try destination.write(from: buffer)
            remaining -= buffer.frameLength
        }
    }
    
    static func trimInPlace(recordingURL: URL, startTime: TimeInterval, endTime: TimeInterval) async throws {
        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            throw RecordingTrimmerError.fileNotFound
        }

        let asset = AVURLAsset(url: recordingURL)
        let assetDurationSeconds: TimeInterval
        do {
            assetDurationSeconds = try await asset.load(.duration).seconds
        } catch {
            throw RecordingTrimmerError.exportSessionUnavailable
        }
        guard assetDurationSeconds.isFinite, assetDurationSeconds > 0 else {
            throw RecordingTrimmerError.exportSessionUnavailable
        }

        let trimmedURL = try await trimToTemp(recordingURL: recordingURL, startTime: startTime, endTime: endTime, assetDuration: assetDurationSeconds)

        do {
            _ = try FileManager.default.replaceItemAt(recordingURL, withItemAt: trimmedURL, backupItemName: nil, options: [])
        } catch {
            try? FileManager.default.removeItem(at: trimmedURL)
            throw RecordingTrimmerError.replaceFailed
        }
    }
}

