import AVFoundation
import XCTest
@testable import Claveo

final class PracticeFeedbackTests: XCTestCase {
    func testDurationClampFollowsMaximumAndRejectsPastOneDay() {
        XCTAssertEqual(PracticeDuration.clamp(600, maximum: 480), 480)
        XCTAssertEqual(PracticeDuration.clamp(2000, maximum: PracticeDuration.absoluteMaximum), 24 * 60)
        XCTAssertEqual(PracticeDuration.clampMaximum(3_000), 24 * 60)
        XCTAssertEqual(PracticeDuration.clamp(3, maximum: 480), 5)
    }

    func testDurationOptionsStayInsideTheMaximum() {
        let options = PracticeDuration.sanitizedOptions([15, 30, 600, 600], maximum: 240)
        XCTAssertEqual(options, [15, 30, 240])
    }

    func testPracticeEntryWithoutAttachmentKeysStillDecodes() throws {
        let json = """
        {"id":"\(UUID().uuidString)","date":0,"duration":30}
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(PracticeEntry.self, from: json)
        XCTAssertEqual(entry.duration, 30)
        XCTAssertTrue(entry.photoFileNames.isEmpty)
        XCTAssertTrue(entry.voiceMemoFileNames.isEmpty)
        XCTAssertTrue(entry.transcribedVoiceMemoFileNames.isEmpty)
    }

    func testVoiceMemoTranscriptStaysOutOfExistingNotes() {
        let embedded = "Focused on bowing.\n\n\(PracticeMemoTranscript.disclaimer)\nWorked on the Allemande"
        let entry = PracticeEntry(duration: 30, notes: embedded)
        let separated = PracticeMemoTranscript.detached(entry)
        XCTAssertEqual(separated.notes, "Focused on bowing.")
        XCTAssertEqual(separated.voiceMemoTranscript, "Worked on the Allemande")
        XCTAssertFalse(separated.notes?.contains(PracticeMemoTranscript.disclaimer) == true)

        let appended = PracticeMemoTranscript.append("Then the Sarabande", to: separated.voiceMemoTranscript ?? "")
        XCTAssertTrue(appended.hasSuffix("Then the Sarabande"))
        XCTAssertFalse(appended.contains(PracticeMemoTranscript.disclaimer))
        XCTAssertEqual(PracticeMemoTranscript.append("   ", to: appended), appended)
    }

    func testVoiceMemoSettingsStaySpeechSized() {
        let settings = PracticeAttachmentStore.memoSettings()
        XCTAssertEqual(settings[AVFormatIDKey] as? Int, Int(kAudioFormatMPEG4AAC))
        XCTAssertEqual(settings[AVNumberOfChannelsKey] as? Int, 1)
        XCTAssertEqual(settings[AVEncoderBitRateKey] as? Int, 64_000)
        let lossless = RecordingQuality.lossless.audioSettings(channelCount: 1)
        XCTAssertNotEqual(settings[AVFormatIDKey] as? Int, lossless[AVFormatIDKey] as? Int)
    }

    func testPlaceholderIsNotATransferUntilTheUserAsks() {
        XCTAssertFalse(RecordingTransferPolicy.shouldStartDownload(userRequested: false, isPlaceholder: true))
        XCTAssertTrue(RecordingTransferPolicy.shouldStartDownload(userRequested: true, isPlaceholder: true))
        XCTAssertFalse(RecordingTransferPolicy.shouldStartDownload(userRequested: true, isPlaceholder: false))
    }

    func testUnchangedLibraryDoesNotReplaceTheArray() {
        let recording = Recording(fileName: "take.m4a", duration: 1, name: "Take")
        let merged = AudioRecorder.mergeRecordings([recording], with: [recording])
        XCTAssertEqual(merged, [recording])
        XCTAssertFalse(merged != [recording])
    }

    func testSampleClicksProduceABuffer() throws {
        for sound in [MetronomeSound.clickKicker, .keys] {
            let buffer = try XCTUnwrap(MetronomeAudio.makeBuffer(for: sound, gain: 1))
            XCTAssertGreaterThan(buffer.frameLength, 0)
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            XCTAssertEqual(samples[Int(buffer.frameLength) - 1], 0, accuracy: 0.001)
        }
    }
}
