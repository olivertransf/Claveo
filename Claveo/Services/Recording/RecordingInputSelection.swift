//
//  RecordingInputSelection.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Foundation

nonisolated struct RecordingInputDataSourceSnapshot: Equatable, Sendable {
    var id: String
    var name: String
}

nonisolated struct RecordingInputPortSnapshot: Equatable, Sendable {
    var uid: String
    var name: String
    var portType: String
    var channelCount: Int
    var hasStereoPolarPattern: Bool
    var dataSources: [RecordingInputDataSourceSnapshot]
}

nonisolated struct RecordingInputChoice: Identifiable, Equatable, Sendable {
    var portUID: String
    var dataSourceID: String?
    var name: String
    var portType: String
    var supportsStereo: Bool

    var id: String {
        if let dataSourceID {
            return "\(portUID)\n\(dataSourceID)"
        }
        return portUID
    }

    var isExternal: Bool {
        Self.externalPortTypes.contains(portType)
    }

    static let externalPortTypes: Set<String> = [
        AVAudioSession.Port.usbAudio.rawValue,
        AVAudioSession.Port.lineIn.rawValue,
        AVAudioSession.Port.headsetMic.rawValue,
        AVAudioSession.Port.bluetoothHFP.rawValue
    ]

    static func choices(from ports: [RecordingInputPortSnapshot]) -> [RecordingInputChoice] {
        ports.flatMap { port in
            let supportsStereo = port.portType == AVAudioSession.Port.usbAudio.rawValue
                || port.portType == AVAudioSession.Port.lineIn.rawValue
                || port.channelCount >= 2
                || port.hasStereoPolarPattern
            if port.portType == AVAudioSession.Port.usbAudio.rawValue, port.dataSources.count > 1 {
                return port.dataSources.map { source in
                    RecordingInputChoice(
                        portUID: port.uid,
                        dataSourceID: source.id,
                        name: "\(port.name): \(source.name)",
                        portType: port.portType,
                        supportsStereo: supportsStereo
                    )
                }
            }
            return [
                RecordingInputChoice(
                    portUID: port.uid,
                    dataSourceID: nil,
                    name: port.name,
                    portType: port.portType,
                    supportsStereo: supportsStereo
                )
            ]
        }
    }
}

extension RecordingInputPortSnapshot {
    nonisolated init(port: AVAudioSessionPortDescription) {
        let sources = port.dataSources ?? []
        self.init(
            uid: port.uid,
            name: port.portName,
            portType: port.portType.rawValue,
            channelCount: port.channels?.count ?? 0,
            hasStereoPolarPattern: sources.contains { source in
                source.supportedPolarPatterns?.contains(.stereo) == true
            },
            dataSources: sources.map { source in
                RecordingInputDataSourceSnapshot(
                    id: source.dataSourceID.stringValue,
                    name: source.dataSourceName
                )
            }
        )
    }
}

nonisolated struct RecordingInputPreference: Equatable, Sendable {
    var portUID: String
    var dataSourceID: String?
}

nonisolated enum RecordingInputPreferenceStore {
    static let portUIDKey = "preferredRecordingInputPortUID"
    static let dataSourceIDKey = "preferredRecordingInputDataSourceID"

    static func load(defaults: UserDefaults = .standard) -> RecordingInputPreference? {
        guard let portUID = defaults.string(forKey: portUIDKey), !portUID.isEmpty else {
            return nil
        }
        let dataSourceID = defaults.string(forKey: dataSourceIDKey)
        return RecordingInputPreference(
            portUID: portUID,
            dataSourceID: dataSourceID?.isEmpty == false ? dataSourceID : nil
        )
    }

    static func save(_ preference: RecordingInputPreference?, defaults: UserDefaults = .standard) {
        if let preference {
            defaults.set(preference.portUID, forKey: portUIDKey)
            if let dataSourceID = preference.dataSourceID {
                defaults.set(dataSourceID, forKey: dataSourceIDKey)
            } else {
                defaults.removeObject(forKey: dataSourceIDKey)
            }
        } else {
            defaults.removeObject(forKey: portUIDKey)
            defaults.removeObject(forKey: dataSourceIDKey)
        }
    }
}

nonisolated enum RecordingInputSelection {
    /// Saved choice wins when that port is still connected. Otherwise a USB interface
    /// beats a wired headset, which beats a Bluetooth headset mic, which beats the built-in mic.
    static func resolved(
        available: [RecordingInputChoice],
        saved: RecordingInputPreference?
    ) -> RecordingInputChoice? {
        guard !available.isEmpty else { return nil }
        if let saved {
            if let exact = available.first(where: {
                $0.portUID == saved.portUID && $0.dataSourceID == saved.dataSourceID
            }) {
                return exact
            }
            if let port = available.first(where: { $0.portUID == saved.portUID }) {
                return port
            }
        }
        return available.min { lhs, rhs in
            automaticRank(lhs) < automaticRank(rhs)
        }
    }

    /// Measurement mode keeps the built-in mic flat. External interfaces stay on the default mode
    /// so iOS does not pin capture to the built-in microphone.
    static func usesMeasurementMode(choice: RecordingInputChoice?, wantsStereo: Bool) -> Bool {
        choice?.isExternal != true && !wantsStereo
    }

    private static func automaticRank(_ choice: RecordingInputChoice) -> Int {
        switch choice.portType {
        case AVAudioSession.Port.usbAudio.rawValue:
            return 0
        case AVAudioSession.Port.lineIn.rawValue:
            return 1
        case AVAudioSession.Port.headsetMic.rawValue:
            return 2
        case AVAudioSession.Port.bluetoothHFP.rawValue:
            return 3
        default:
            return 4
        }
    }
}
