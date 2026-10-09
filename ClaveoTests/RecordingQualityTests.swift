import AVFoundation
import XCTest
@testable import Claveo

final class RecordingQualityTests: XCTestCase {
    func testQualitySettingsAndExtensions() {
        XCTAssertEqual(RecordingQuality.standard.fileExtension, "m4a")
        XCTAssertEqual(RecordingQuality.high.fileExtension, "m4a")
        XCTAssertEqual(RecordingQuality.lossless.fileExtension, "m4a")
        XCTAssertEqual(RecordingQuality.uncompressed.fileExtension, "wav")

        let standard = RecordingQuality.standard.audioSettings(channelCount: 1)
        XCTAssertEqual(standard[AVFormatIDKey] as? Int, Int(kAudioFormatMPEG4AAC))
        XCTAssertEqual(standard[AVSampleRateKey] as? Double, 48_000)
        XCTAssertEqual(standard[AVEncoderBitRateKey] as? Int, 128_000)
        XCTAssertEqual(standard[AVNumberOfChannelsKey] as? Int, 1)

        let high = RecordingQuality.high.audioSettings(channelCount: 2)
        XCTAssertEqual(high[AVEncoderBitRateKey] as? Int, 256_000)
        XCTAssertEqual(high[AVNumberOfChannelsKey] as? Int, 2)

        let lossless = RecordingQuality.lossless.audioSettings(channelCount: 1)
        XCTAssertEqual(lossless[AVFormatIDKey] as? Int, Int(kAudioFormatAppleLossless))
        XCTAssertEqual(lossless[AVEncoderBitDepthHintKey] as? Int, 24)

        let wav = RecordingQuality.uncompressed.audioSettings(channelCount: 1)
        XCTAssertEqual(wav[AVFormatIDKey] as? Int, Int(kAudioFormatLinearPCM))
        XCTAssertEqual(wav[AVLinearPCMBitDepthKey] as? Int, 24)
        XCTAssertEqual(wav[AVLinearPCMIsFloatKey] as? Bool, false)

        XCTAssertEqual(RecordingMicMode.natural.channelCount, 1)
        XCTAssertEqual(RecordingMicMode.stereo.channelCount, 2)
        XCTAssertGreaterThan(RecordingQuality.uncompressed.approxMegabytesPerMinute(channelCount: 1), 8)
    }

    func testLegacySettingsJSONDefaultsRecordingQuality() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(settings.recordingQuality, .high)
        XCTAssertEqual(settings.recordingMicMode, .natural)
        XCTAssertFalse(settings.allowBluetoothHeadsetMic)
    }

    func testWAVTrimCopiesFrameRangeWithoutChangingFormat() async throws {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let settings = RecordingQuality.uncompressed.audioSettings(channelCount: 1)
        var writer: AVAudioFile? = try AVAudioFile(forWriting: sourceURL, settings: settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: writer!.processingFormat, frameCapacity: 48_000)!
        buffer.frameLength = 48_000
        try writer?.write(from: buffer)
        writer = nil

        let trimmed = try await RecordingTrimmer.trimNonDestructive(
            recordingURL: sourceURL,
            startTime: 0.25,
            endTime: 0.75
        )
        defer {
            try? FileManager.default.removeItem(at: trimmed.trimmedURL)
            try? FileManager.default.removeItem(at: trimmed.backupURL)
        }

        let trimmedFile = try AVAudioFile(forReading: trimmed.trimmedURL)
        XCTAssertEqual(trimmedFile.length, 24_000)
        XCTAssertEqual(trimmedFile.fileFormat.settings[AVFormatIDKey] as? Int, Int(kAudioFormatLinearPCM))
        XCTAssertEqual(trimmed.trimmedURL.pathExtension, "wav")
    }
}
