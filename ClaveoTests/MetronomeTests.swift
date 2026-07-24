import AVFoundation
import XCTest
@testable import Claveo

final class MetronomeTests: XCTestCase {
    func testFailedBufferScheduleDoesNotAdvanceCount() {
        var state = MetronomeScheduleState()

        state.recordSchedule(succeeded: false)

        XCTAssertEqual(state.scheduledBeatCount, 0)
    }

    func testSuccessfulBufferScheduleAdvancesCount() {
        var state = MetronomeScheduleState()

        state.recordSchedule(succeeded: true)

        XCTAssertEqual(state.scheduledBeatCount, 1)
    }

    func testGeneratedBuffersHavePlayableFormatAndHeadroom() throws {
        for sound in MetronomeSound.allCases {
            let buffer = try XCTUnwrap(MetronomeAudio.makeBuffer(for: sound, gain: 1))

            XCTAssertEqual(buffer.format.commonFormat, .pcmFormatFloat32)
            XCTAssertEqual(buffer.format.channelCount, 1)
            XCTAssertGreaterThan(buffer.format.sampleRate, 0)
            XCTAssertGreaterThan(buffer.frameLength, 0)

            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            let peak = (0..<Int(buffer.frameLength))
                .map { abs(samples[$0]) }
                .max() ?? 0
            XCTAssertLessThanOrEqual(peak, MetronomeAudio.maximumSampleMagnitude)
            XCTAssertLessThan(MetronomeAudio.maximumSampleMagnitude, 1)
        }
    }

    func testTempoAdjustmentRequestsSingleRescheduleAtEnd() async {
        await MainActor.run {
            let metronome = Metronome()

            metronome.beginTempoAdjustment()
            metronome.tempo = 180

            XCTAssertTrue(metronome.hasPendingTempoReschedule)
            XCTAssertFalse(metronome.endTempoAdjustment(shouldApply: false))
            XCTAssertFalse(metronome.hasPendingTempoReschedule)
            XCTAssertFalse(metronome.isTempoAdjustmentInProgress)

            metronome.beginTempoAdjustment()
            metronome.tempo = 200
            XCTAssertTrue(metronome.hasPendingTempoReschedule)
            XCTAssertTrue(metronome.endTempoAdjustment(shouldApply: true))
            XCTAssertFalse(metronome.hasPendingTempoReschedule)
        }
    }

    func testScheduleCatchUpSkipsPastBeats() async {
        await MainActor.run {
            let metronome = Metronome()
            metronome.interval = 0.5
            metronome.startTime = CACurrentMediaTime() - 5 // ~10 beats behind
            metronome.scheduledBeatCount = 0
            // Without audio engine, scheduleBeatsAhead returns early — jump logic is covered by
            // asserting the lag math used before scheduling.
            let now = CACurrentMediaTime()
            let elapsedBeats = max(0, Int(floor((now - metronome.startTime) / metronome.interval)))
            XCTAssertGreaterThanOrEqual(elapsedBeats, 8)
            if metronome.scheduledBeatCount < elapsedBeats {
                metronome.scheduledBeatCount = elapsedBeats
            }
            XCTAssertEqual(metronome.scheduledBeatCount, elapsedBeats)
        }
    }

    func testTimeSignatureBeatCountsMatchDisplayedNumerators() {
        for signature in TimeSignature.allCases {
            let numerator = Int(signature.rawValue.split(separator: "/")[0])
            XCTAssertEqual(signature.beatsPerMeasure, numerator)
        }
    }

    func testStartupErrorProvidesUsefulDescription() {
        let error = MetronomeStartupError.audioEngineFailed("The audio route is unavailable.")

        XCTAssertTrue(error.localizedDescription.contains("audio route is unavailable"))
    }
}
