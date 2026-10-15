import AVFoundation
import XCTest
@testable import Claveo

final class RecordingInputSelectionTests: XCTestCase {
    private let builtIn = RecordingInputChoice(
        portUID: "builtin",
        dataSourceID: nil,
        name: "iPhone Microphone",
        portType: AVAudioSession.Port.builtInMic.rawValue,
        supportsStereo: false
    )
    private let motu = RecordingInputChoice(
        portUID: "motu-m2",
        dataSourceID: nil,
        name: "MOTU M2",
        portType: AVAudioSession.Port.usbAudio.rawValue,
        supportsStereo: true
    )
    private let headset = RecordingInputChoice(
        portUID: "headset",
        dataSourceID: nil,
        name: "Headset Microphone",
        portType: AVAudioSession.Port.headsetMic.rawValue,
        supportsStereo: false
    )

    func testAutomaticChoicePrefersUSBOverBuiltInAndHeadset() {
        let resolved = RecordingInputSelection.resolved(
            available: [builtIn, headset, motu],
            saved: nil
        )
        XCTAssertEqual(resolved, motu)
    }

    func testSavedBuiltInMicWinsOverConnectedInterface() {
        let resolved = RecordingInputSelection.resolved(
            available: [builtIn, motu],
            saved: RecordingInputPreference(portUID: builtIn.portUID, dataSourceID: nil)
        )
        XCTAssertEqual(resolved, builtIn)
    }

    func testMissingSavedPortFallsBackToConnectedInterface() {
        let resolved = RecordingInputSelection.resolved(
            available: [builtIn, motu],
            saved: RecordingInputPreference(portUID: "unplugged", dataSourceID: nil)
        )
        XCTAssertEqual(resolved, motu)
    }

    func testUSBDataSourcesBecomeSeparateChoices() {
        let choices = RecordingInputChoice.choices(from: [
            RecordingInputPortSnapshot(
                uid: "motu-m2",
                name: "MOTU M2",
                portType: AVAudioSession.Port.usbAudio.rawValue,
                channelCount: 2,
                hasStereoPolarPattern: false,
                dataSources: [
                    RecordingInputDataSourceSnapshot(id: "1", name: "Input 1"),
                    RecordingInputDataSourceSnapshot(id: "2", name: "Input 2")
                ]
            )
        ])
        XCTAssertEqual(choices.map(\.name), ["MOTU M2: Input 1", "MOTU M2: Input 2"])
        XCTAssertTrue(choices.allSatisfy(\.supportsStereo))
    }

    func testBuiltInDataSourcesStayOneChoice() {
        let choices = RecordingInputChoice.choices(from: [
            RecordingInputPortSnapshot(
                uid: "builtin",
                name: "iPhone Microphone",
                portType: AVAudioSession.Port.builtInMic.rawValue,
                channelCount: 1,
                hasStereoPolarPattern: true,
                dataSources: [
                    RecordingInputDataSourceSnapshot(id: "front", name: "Front"),
                    RecordingInputDataSourceSnapshot(id: "back", name: "Back")
                ]
            )
        ])
        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices.first?.name, "iPhone Microphone")
        XCTAssertEqual(choices.first?.supportsStereo, true)
        XCTAssertNil(choices.first?.dataSourceID)
    }

    func testMeasurementModeStaysOffForExternalInputs() {
        XCTAssertFalse(RecordingInputSelection.usesMeasurementMode(choice: motu, wantsStereo: false))
        XCTAssertTrue(RecordingInputSelection.usesMeasurementMode(choice: builtIn, wantsStereo: false))
        XCTAssertFalse(RecordingInputSelection.usesMeasurementMode(choice: builtIn, wantsStereo: true))
    }

    func testPreferenceRoundTrip() {
        let defaults = UserDefaults(suiteName: "RecordingInputSelectionTests")!
        defaults.removePersistentDomain(forName: "RecordingInputSelectionTests")
        XCTAssertNil(RecordingInputPreferenceStore.load(defaults: defaults))

        RecordingInputPreferenceStore.save(
            RecordingInputPreference(portUID: "motu-m2", dataSourceID: "1"),
            defaults: defaults
        )
        XCTAssertEqual(
            RecordingInputPreferenceStore.load(defaults: defaults),
            RecordingInputPreference(portUID: "motu-m2", dataSourceID: "1")
        )

        RecordingInputPreferenceStore.save(nil, defaults: defaults)
        XCTAssertNil(RecordingInputPreferenceStore.load(defaults: defaults))
    }
}
