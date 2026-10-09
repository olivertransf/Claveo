//
//  RecordingQuality.swift
//  Claveo
//
//  Capture presets for practice takes and audition excerpts.
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Foundation

enum RecordingQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case high
    case lossless
    case uncompressed

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .standard: return String(localized: "Standard")
        case .high: return String(localized: "High")
        case .lossless: return String(localized: "Lossless")
        case .uncompressed: return String(localized: "Uncompressed")
        }
    }

    var detail: String {
        switch self {
        case .standard:
            return String(localized: "AAC at 128 kbps. Smaller files for everyday practice.")
        case .high:
            return String(localized: "AAC at 256 kbps. Clear practice takes.")
        case .lossless:
            return String(localized: "Apple Lossless, 24-bit, 48 kHz. Full range for auditions and excerpts.")
        case .uncompressed:
            return String(localized: "WAV, 24-bit, 48 kHz. No compression. Largest files.")
        }
    }

    var fileExtension: String {
        switch self {
        case .standard, .high, .lossless:
            return "m4a"
        case .uncompressed:
            return "wav"
        }
    }

    func approxMegabytesPerMinute(channelCount: Int) -> Double {
        let channels = Double(max(channelCount, 1))
        switch self {
        case .standard:
            return 128_000.0 / 8.0 * 60.0 / 1_000_000.0
        case .high:
            return 256_000.0 / 8.0 * 60.0 / 1_000_000.0
        case .lossless:
            return 5.2 * channels
        case .uncompressed:
            return 48_000.0 * 3.0 * channels * 60.0 / 1_000_000.0
        }
    }

    func audioSettings(channelCount: Int) -> [String: Any] {
        let channels = max(channelCount, 1)
        switch self {
        case .standard:
            return [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 48_000.0,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: 128_000
            ]
        case .high:
            return [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 48_000.0,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: 256_000
            ]
        case .lossless:
            return [
                AVFormatIDKey: Int(kAudioFormatAppleLossless),
                AVSampleRateKey: 48_000.0,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitDepthHintKey: 24
            ]
        case .uncompressed:
            return [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 48_000.0,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 24,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        }
    }
}

enum RecordingMicMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case natural
    case stereo

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .natural: return String(localized: "Natural")
        case .stereo: return String(localized: "Stereo")
        }
    }

    var detail: String {
        switch self {
        case .natural:
            return String(localized: "Primary microphone, no automatic gain or EQ.")
        case .stereo:
            return String(localized: "Stereo pair when the device supports it.")
        }
    }

    var channelCount: Int {
        switch self {
        case .natural: return 1
        case .stereo: return 2
        }
    }
}
