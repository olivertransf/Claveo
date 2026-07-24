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
        let backupFileName = "original_\(UUID().uuidString).m4a"
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
            .appendingPathComponent("restore_\(UUID().uuidString).m4a")
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

        let asset = AVURLAsset(url: recordingURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw RecordingTrimmerError.exportSessionUnavailable
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString).m4a")

        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }

        exporter.outputURL = tempURL
        exporter.outputFileType = AVFileType.m4a

        let timescale: CMTimeScale = 600
        let start = CMTime(seconds: clampedStart, preferredTimescale: timescale)
        let end = CMTime(seconds: clampedEnd, preferredTimescale: timescale)
        exporter.timeRange = CMTimeRangeFromTimeToTime(start: start, end: end)

        let exportHolder = ExportSessionHolder(exporter)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportHolder.session.exportAsynchronously {
                let status = exportHolder.session.status
                let exportError = exportHolder.session.error
                switch status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: RecordingTrimmerError.exportFailed(underlying: exportError))
                default:
                    continuation.resume(throwing: RecordingTrimmerError.exportFailed(underlying: exportError))
                }
            }
        }

        return tempURL
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

