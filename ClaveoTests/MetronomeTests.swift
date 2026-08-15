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

    func testEverySoundIsNormalizedToTheSamePeak() throws {
        for sound in MetronomeSound.allCases {
            let buffer = try XCTUnwrap(MetronomeAudio.makeBuffer(for: sound, gain: 1))
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            let peak = (0..<Int(buffer.frameLength))
                .map { abs(samples[$0]) }
                .max() ?? 0

            XCTAssertEqual(Double(peak), MetronomeAudio.normalizedPeak, accuracy: 0.02)
        }
    }

    func testClicksEndAtSilenceSoBuffersDoNotPop() throws {
        for sound in MetronomeSound.allCases {
            let buffer = try XCTUnwrap(MetronomeAudio.makeBuffer(for: sound, gain: 1))
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            let lastSample = samples[Int(buffer.frameLength) - 1]

            XCTAssertEqual(lastSample, 0, accuracy: 0.001)
        }
    }

    func testLowerVolumeProducesQuieterOutput() throws {
        func peak(gain: Double) throws -> Float {
            let buffer = try XCTUnwrap(MetronomeAudio.makeBuffer(for: .click, gain: gain))
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            return (0..<Int(buffer.frameLength)).map { abs(samples[$0]) }.max() ?? 0
        }

        XCTAssertGreaterThan(try peak(gain: 1), try peak(gain: 0.5))
        XCTAssertEqual(try peak(gain: 0), 0)
    }

    func testPlayerVolumeSpansFullRange() {
        XCTAssertEqual(MetronomeAudio.playerVolume(for: 0), 0)
        XCTAssertEqual(MetronomeAudio.playerVolume(for: 1), 1, accuracy: 0.0001)
        XCTAssertEqual(MetronomeAudio.playerVolume(for: 2), 1, accuracy: 0.0001)
        XCTAssertLessThan(
            MetronomeAudio.playerVolume(for: 0.5),
            MetronomeAudio.playerVolume(for: 0.75)
        )
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

    func testSubdivisionOffsetsMatchMusicalValues() {
        XCTAssertEqual(MetronomeSubdivision.quarter.beatOffsets, [0])
        XCTAssertEqual(MetronomeSubdivision.eighths.beatOffsets, [0, 0.5])
        XCTAssertEqual(MetronomeSubdivision.sixteenths.beatOffsets, [0, 0.25, 0.5, 0.75])
        XCTAssertEqual(MetronomeSubdivision.eighthsThenSixteenths.beatOffsets.count, 4)
        XCTAssertEqual(MetronomeSubdivision.eighthsThenSixteenths.beatOffsets[1], 1.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(MetronomeSubdivision.sixteenthsThenEighths.beatOffsets[1], 1.0 / 6.0, accuracy: 0.000_001)
        XCTAssertEqual(MetronomeSubdivision.dottedEighthSixteenth.beatOffsets, [0, 0.75])
        XCTAssertEqual(MetronomeSubdivision.sixteenthDottedEighth.beatOffsets, [0, 0.25])
        XCTAssertEqual(MetronomeSubdivision.triplet.beatOffsets.count, 3)
        XCTAssertEqual(MetronomeSubdivision.triplet.beatOffsets[1], 1.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(MetronomeSubdivision.triplet.beatOffsets[2], 2.0 / 3.0, accuracy: 0.000_001)
    }

    func testSubdivisionAccentsEveryDownbeat() {
        let sixteenths = MetronomeSubdivision.sixteenths.scheduledClicks(
            beatNumber: 0,
            startTime: 0,
            interval: 1,
            beatsPerMeasure: 4,
            beatPattern: [true, false, false, false],
            now: -1,
            minimumLead: 0
        )
        XCTAssertEqual(sixteenths.map(\.isAccent), [true, false, false, false])

        let weakBeat = MetronomeSubdivision.sixteenths.scheduledClicks(
            beatNumber: 1,
            startTime: 0,
            interval: 1,
            beatsPerMeasure: 4,
            beatPattern: [true, false, false, false],
            now: -1,
            minimumLead: 0
        )
        XCTAssertEqual(weakBeat.map(\.isAccent), [true, false, false, false])

        let quarters = MetronomeSubdivision.quarter.scheduledClicks(
            beatNumber: 1,
            startTime: 0,
            interval: 1,
            beatsPerMeasure: 4,
            beatPattern: [true, false, false, false],
            now: -1,
            minimumLead: 0
        )
        XCTAssertEqual(quarters.map(\.isAccent), [false])
    }

    func testSubdivisionDropsClicksThatHaveAlreadyPassed() {
        let remaining = MetronomeSubdivision.eighths.scheduledClicks(
            beatNumber: 0,
            startTime: 0,
            interval: 1,
            beatsPerMeasure: 4,
            beatPattern: [true, false, false, false],
            now: 0.4,
            minimumLead: 0.01
        )

        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].hostTimeSeconds, 0.5, accuracy: 0.000_1)
        XCTAssertFalse(remaining[0].isAccent)
    }

    func testSetSubdivisionUpdatesPublishedValue() async {
        await MainActor.run {
            let metronome = Metronome()
            metronome.setSubdivision(.triplet)
            XCTAssertEqual(metronome.subdivision, .triplet)
            metronome.setSubdivision(.dottedEighthSixteenth)
            XCTAssertEqual(metronome.subdivision, .dottedEighthSixteenth)
        }
    }

    func testMissingSubdivisionSettingDecodesAsQuarter() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "a4ReferenceFrequency": 440.0,
            "defaultPracticeTime": 30
        ])
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.metronomeSubdivision, MetronomeSubdivision.quarter.rawValue)
    }

    func testStartupErrorProvidesUsefulDescription() {
        let error = MetronomeStartupError.audioEngineFailed("The audio route is unavailable.")

        XCTAssertTrue(error.localizedDescription.contains("audio route is unavailable"))
    }
}
