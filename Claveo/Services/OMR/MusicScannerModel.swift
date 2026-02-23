//
//  MusicScannerModel.swift
//  Claveo
//

import Foundation
import CoreML
import UIKit

final class MusicScannerModel {
    private let model: MLModel
    private let inputName: String
    private let outputName: String
    static let inputSize = 640

    init() throws {
        guard let url = Bundle.main.url(forResource: "best", withExtension: "mlpackage")
            ?? Bundle.main.url(forResource: "best", withExtension: "mlmodelc") else {
            throw NSError(domain: "MusicScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "best.mlpackage not found in bundle"])
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        let loadedModel = try MLModel(contentsOf: url, configuration: config)
        self.model = loadedModel

        let desc = loadedModel.modelDescription
        self.inputName = desc.inputDescriptionsByName.keys.first ?? "image"
        self.outputName = desc.outputDescriptionsByName.keys.first ?? "var_1205"
    }

    nonisolated func predict(image: UIImage, confidenceThreshold: Float = 0.4) throws -> [OMRBoundingBox] {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "MusicScanner", code: 4, userInfo: [NSLocalizedDescriptionKey: "UIImage has no CGImage"])
        }
        return try predict(image: cgImage, confidenceThreshold: confidenceThreshold)
    }

    nonisolated func predict(image: CGImage, confidenceThreshold: Float = 0.4) throws -> [OMRBoundingBox] {
        let inputSize = Self.inputSize
        let w = image.width
        let h = image.height
        if w <= inputSize && h <= inputSize {
            return try predictSingle(image: image, confidenceThreshold: confidenceThreshold)
        }
        return try predictWithSlicing(image: image, confidenceThreshold: confidenceThreshold)
    }

    private func predictSingle(image: CGImage, confidenceThreshold: Float) throws -> [OMRBoundingBox] {
        let inputSize = Self.inputSize
        let resized = resizeImage(image, targetSize: CGSize(width: inputSize, height: inputSize))
        guard let pixelBuffer = resized.toCVPixelBuffer(width: inputSize, height: inputSize) else {
            throw NSError(domain: "MusicScanner", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"])
        }
        let input = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: pixelBuffer)])
        let output = try model.prediction(from: input)
        guard let array = output.featureValue(for: outputName)?.multiArrayValue else {
            throw NSError(domain: "MusicScanner", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid model output"])
        }
        let boxes = parseOutput(array, confidenceThreshold: confidenceThreshold)
        let scaleX = Float(image.width) / Float(inputSize)
        let scaleY = Float(image.height) / Float(inputSize)
        return boxes.map { box in
            OMRBoundingBox(
                x1: box.x1 * scaleX,
                y1: box.y1 * scaleY,
                x2: box.x2 * scaleX,
                y2: box.y2 * scaleY,
                confidence: box.confidence,
                label: box.label,
                classId: box.classId
            )
        }
    }

    private func predictWithSlicing(image: CGImage, confidenceThreshold: Float) throws -> [OMRBoundingBox] {
        let sliceSize = Self.inputSize
        let stepH = Int(Float(sliceSize) * 0.8)
        let stepW = Int(Float(sliceSize) * 0.5)
        let w = image.width
        let h = image.height
        var allBoxes: [OMRBoundingBox] = []
        var y = 0
        while y < h {
            var x = 0
            while x < w {
                let cropW = min(sliceSize, w - x)
                let cropH = min(sliceSize, h - y)
                let slice = cropOrPad(image: image, x: x, y: y, width: cropW, height: cropH, targetSize: sliceSize)
                guard let pixelBuffer = slice.toCVPixelBuffer(width: sliceSize, height: sliceSize) else {
                    x += stepW
                    continue
                }
                let input = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: pixelBuffer)])
                let output = try model.prediction(from: input)
                guard let array = output.featureValue(for: outputName)?.multiArrayValue else {
                    x += stepW
                    continue
                }
                let boxes = parseOutput(array, confidenceThreshold: confidenceThreshold, applyNMS: false)
                let scaleX = Float(cropW) / Float(sliceSize)
                let scaleY = Float(cropH) / Float(sliceSize)
                let maxX = Float(w)
                let maxY = Float(h)
                for box in boxes {
                    var x1 = Float(x) + box.x1 * scaleX
                    var y1 = Float(y) + box.y1 * scaleY
                    var x2 = Float(x) + box.x2 * scaleX
                    var y2 = Float(y) + box.y2 * scaleY
                    x1 = max(0, min(x1, maxX))
                    y1 = max(0, min(y1, maxY))
                    x2 = max(0, min(x2, maxX))
                    y2 = max(0, min(y2, maxY))
                    if x2 > x1 && y2 > y1 {
                        allBoxes.append(OMRBoundingBox(x1: x1, y1: y1, x2: x2, y2: y2, confidence: box.confidence, label: box.label, classId: box.classId))
                    }
                }
                x += stepW
            }
            y += stepH
        }
        let nmsFiltered = nms(allBoxes, iouThreshold: 0.45)
        return nmmIOS(boxes: nmsFiltered, threshold: 0.1)
    }

    private func cropOrPad(image: CGImage, x: Int, y: Int, width: Int, height: Int, targetSize: Int) -> CGImage {
        guard let cropped = image.cropping(to: CGRect(x: x, y: y, width: width, height: height)) else {
            return createBlankImage(width: targetSize, height: targetSize)
        }
        if width == targetSize && height == targetSize {
            return cropped
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil, width: targetSize, height: targetSize, bitsPerComponent: 8,
            bytesPerRow: targetSize * 4, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return cropped
        }
        context.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: targetSize, height: targetSize))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? cropped
    }

    private func createBlankImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else {
            fatalError("Cannot create blank image")
        }
        context.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func nmmIOS(boxes: [OMRBoundingBox], threshold: Float) -> [OMRBoundingBox] {
        let sorted = boxes.sorted { $0.confidence > $1.confidence }
        var keep: [OMRBoundingBox] = []
        for box in sorted {
            var isDuplicate = false
            for kept in keep {
                if box.classId != kept.classId { continue }
                let interX1 = max(box.x1, kept.x1)
                let interY1 = max(box.y1, kept.y1)
                let interX2 = min(box.x2, kept.x2)
                let interY2 = min(box.y2, kept.y2)
                let interArea = max(0, interX2 - interX1) * max(0, interY2 - interY1)
                let areaBox = (box.x2 - box.x1) * (box.y2 - box.y1)
                let areaKept = (kept.x2 - kept.x1) * (kept.y2 - kept.y1)
                let ios = interArea / min(areaBox, areaKept)
                if ios > threshold {
                    isDuplicate = true
                    break
                }
            }
            if !isDuplicate {
                keep.append(box)
            }
        }
        return keep
    }

    private func parseOutput(_ array: MLMultiArray, confidenceThreshold: Float, applyNMS: Bool = true) -> [OMRBoundingBox] {
        let shape = array.shape
        let numBoxes: Int
        let stride: Int
        if shape.count >= 3 {
            numBoxes = shape[shape.count - 2].intValue
            stride = shape[shape.count - 1].intValue
        } else if shape.count == 2 {
            numBoxes = shape[0].intValue
            stride = shape[1].intValue
        } else {
            return []
        }
        guard stride >= 6 else { return [] }
        var boxes: [OMRBoundingBox] = []
        let ptr = array.dataPointer.assumingMemoryBound(to: Float.self)
        for i in 0..<numBoxes {
            let base = i * stride
            let x1 = ptr[base]
            let y1 = ptr[base + 1]
            let x2 = ptr[base + 2]
            let y2 = ptr[base + 3]
            let conf = ptr[base + 4]
            let classId = Int(ptr[base + 5].rounded())
            guard conf >= confidenceThreshold else { continue }
            guard classId >= 0, classId < OMRClassLabels.names.count else { continue }
            let label = OMRClassLabels.names[classId]
            boxes.append(OMRBoundingBox(x1: x1, y1: y1, x2: x2, y2: y2, confidence: conf, label: label, classId: classId))
        }
        return applyNMS ? nms(boxes, iouThreshold: 0.45) : boxes
    }

    private func nms(_ boxes: [OMRBoundingBox], iouThreshold: Float) -> [OMRBoundingBox] {
        let sorted = boxes.sorted { $0.confidence > $1.confidence }
        var keep: [OMRBoundingBox] = []
        for box in sorted {
            var overlap = false
            for kept in keep {
                if box.classId == kept.classId && iou(box, kept) > iouThreshold {
                    overlap = true
                    break
                }
            }
            if !overlap {
                keep.append(box)
            }
        }
        return keep
    }

    private func iou(_ a: OMRBoundingBox, _ b: OMRBoundingBox) -> Float {
        let x1 = max(a.x1, b.x1)
        let y1 = max(a.y1, b.y1)
        let x2 = min(a.x2, b.x2)
        let y2 = min(a.y2, b.y2)
        let interArea = max(0, x2 - x1) * max(0, y2 - y1)
        let areaA = (a.x2 - a.x1) * (a.y2 - a.y1)
        let areaB = (b.x2 - b.x1) * (b.y2 - b.y1)
        return interArea / (areaA + areaB - interArea)
    }

    private func resizeImage(_ image: CGImage, targetSize: CGSize) -> CGImage {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return image
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}

private extension CGImage {
    func toCVPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo) else { return nil }
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
