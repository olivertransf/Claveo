//
//  PracticeAttachmentStore.swift
//  Claveo
//
//  Copyright (c) 2026 Oliver Tran

import AVFoundation
import Foundation
import UIKit

enum PracticeAttachmentStore {
    static func fileURL(for fileName: String) -> URL {
        iCloudManager.shared.getDocumentsURL().appendingPathComponent(fileName)
    }

    static func savePhoto(_ image: UIImage) throws -> String {
        let fileName = "practice-photo-\(UUID().uuidString).jpg"
        guard let data = jpegData(from: image) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try iCloudManager.shared.writeFile(data: data, to: fileURL(for: fileName))
        return fileName
    }

    nonisolated static func memoSettings() -> [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48_000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000
        ]
    }

    static func newMemoURL() -> URL {
        fileURL(for: "practice-memo-\(UUID().uuidString).m4a")
    }

    static func remove(_ fileNames: [String]) {
        for fileName in fileNames where !fileName.isEmpty {
            try? FileManager.default.removeItem(at: fileURL(for: fileName))
        }
    }

    static func prepare(_ fileName: String) async {
        let url = fileURL(for: fileName)
        guard RecordingDownload.isPlaceholder(at: url) else { return }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        _ = await RecordingDownload.waitUntilLocal(at: url, timeout: 20, onProgress: { _ in })
    }

    private static func jpegData(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 2000
        let size = image.size
        let longest = max(size.width, size.height)
        let rendered: UIImage
        if longest > maxSide, longest > 0 {
            let scale = maxSide / longest
            let target = CGSize(width: size.width * scale, height: size.height * scale)
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
        } else {
            rendered = image
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }
}
