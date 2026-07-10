//
//  OMRScannerView.swift
//  Claveo
//

import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers
import ImageIO

struct OMRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var model: MusicScannerModel?
    @State private var status = String(localized: "Loading model...")
    @State private var renderedImage: UIImage?
    @State private var detections: [OMRBoundingBox] = []
    @State private var isProcessing = false
    @State private var showFileImporter = false
    @State private var currentFileName: String?
    @State private var pdfPageCount = 1
    @State private var currentPage = 1
    @State private var selectedLabel: String?
    @State private var currentDocumentURL: URL?

    private static let boxColors: [UIColor] = [
        .systemRed, .systemBlue, .systemGreen, .systemOrange,
        .systemPurple, .systemTeal, .systemPink, .systemYellow,
        .systemIndigo, .systemBrown, .cyan, .magenta
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Open", systemImage: "doc.badge.plus")
                    }
                    .disabled(model == nil || isProcessing)

                    if pdfPageCount > 1 {
                        HStack(spacing: 8) {
                            Button {
                                currentPage = max(1, currentPage - 1)
                                Task { await loadCurrentPage() }
                            } label: { Image(systemName: "chevron.left") }
                            .disabled(currentPage <= 1 || isProcessing)

                            Text("Page \(currentPage) / \(pdfPageCount)")
                                .font(.caption)

                            Button {
                                currentPage = min(pdfPageCount, currentPage + 1)
                                Task { await loadCurrentPage() }
                            } label: { Image(systemName: "chevron.right") }
                            .disabled(currentPage >= pdfPageCount || isProcessing)
                        }
                    }
                }

                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if isProcessing {
                    ProgressView("Running detection...")
                }

                if let image = renderedImage {
                    let result = drawBoxes(on: image, detections: detections)
                    let width = UIScreen.main.bounds.width - 32
                    FitWidthImageView(image: result, width: width, detections: detections) { box in
                        selectedLabel = box?.label
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .top) {
                        if let label = selectedLabel {
                            Text(label)
                                .font(.subheadline.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .padding(.top, 8)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedLabel)
                } else {
                    emptyStateView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text("OMR Scanner")
                            .font(.headline)
                        Text("BETA")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadModelOnly()
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .png, .jpeg, .image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await processDocument(at: url) }
                case .failure(let error):
                    status = String(localized: "Error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadCurrentPage() async {
        guard let url = currentDocumentURL else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url) else { return }
        pdfPageCount = doc.pageCount
        guard let rawPage = imageFromPDF(url: url, page: currentPage) else { return }
        await runDetection(on: rawPage)
    }

    private func processDocument(at url: URL) async {
        guard url.startAccessingSecurityScopedResource() else {
            status = String(localized: "Cannot access file")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        currentDocumentURL = url
        currentFileName = url.lastPathComponent
        pdfPageCount = 1

        if url.pathExtension.lowercased() == "pdf" {
            guard let doc = PDFDocument(url: url) else {
                status = String(localized: "Failed to load PDF")
                return
            }
            pdfPageCount = doc.pageCount
            currentPage = 1
            guard let rawPage = imageFromPDF(url: url, page: 1) else {
                status = String(localized: "Failed to render PDF page")
                return
            }
            await runDetection(on: rawPage)
        } else {
            guard let cgImage = loadImage(from: url) else {
                status = String(localized: "Failed to load image")
                return
            }
            await runDetection(on: cgImage)
        }
    }

    private func loadImage(from url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return cgImage
    }

    private func runDetection(on cgImage: CGImage) async {
        guard let m = model else { return }
        let resized = resizeIfLarge(cgImage)
        renderedImage = UIImage(cgImage: resized)
        status = String(localized: "Detecting...")
        isProcessing = true
        do {
            let results = try await Task.detached(priority: .userInitiated) {
                try m.predict(image: resized, confidenceThreshold: 0.15)
            }.value
            detections = results
            if let name = currentFileName {
                status = String(localized: "\(results.count) detections · \(name)")
            } else {
                status = String(localized: "\(results.count) detections")
            }
        } catch {
            status = String(localized: "Error: \(error.localizedDescription)")
        }
        isProcessing = false
    }

    private func loadModelOnly() async {
        do {
            let m = try MusicScannerModel()
            model = m
            status = String(localized: "Tap Open to select sheet music (PDF or image)")
        } catch {
            status = String(localized: "Error loading model: \(error.localizedDescription)")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Optical Music Recognition")
                .font(.title2.bold())
            Text("Load a PDF or image of sheet music to detect musical symbols. Tap Open to browse your files, then tap any detection box to see its label.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func imageFromPDF(url: URL, page: Int) -> CGImage? {
        guard let document = PDFDocument(url: url),
              let pdfPage = document.page(at: page - 1) else { return nil }
        let rect = pdfPage.bounds(for: .mediaBox)
        let scale: CGFloat = 200.0 / 72.0
        let w = Int(rect.width * scale)
        let h = Int(rect.height * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.scaleBy(x: scale, y: scale)
        pdfPage.draw(with: .mediaBox, to: ctx)
        guard let raw = ctx.makeImage() else { return nil }
        guard let normCtx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return raw }
        normCtx.translateBy(x: 0, y: CGFloat(h))
        normCtx.scaleBy(x: 1, y: -1)
        normCtx.draw(raw, in: CGRect(x: 0, y: 0, width: w, height: h))
        return normCtx.makeImage() ?? raw
    }

    private func resizeIfLarge(_ img: CGImage, maxDim: Int = 3500) -> CGImage {
        let w = img.width, h = img.height
        guard max(w, h) > maxDim else { return img }
        let scale = CGFloat(maxDim) / CGFloat(max(w, h))
        let nw = Int(CGFloat(w) * scale), nh = Int(CGFloat(h) * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: nw, height: nh, bitsPerComponent: 8,
            bytesPerRow: nw * 4, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return img }
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        return ctx.makeImage() ?? img
    }

    private func drawBoxes(on image: UIImage, detections: [OMRBoundingBox]) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let srcW = CGFloat(cgImage.width)
        let srcH = CGFloat(cgImage.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: srcW, height: srcH), format: format)
        return renderer.image { ctx in
            UIImage(cgImage: cgImage, scale: 1, orientation: .up).draw(in: CGRect(x: 0, y: 0, width: srcW, height: srcH))
            let cg = ctx.cgContext
            cg.setLineWidth(3)
            for box in detections {
                Self.boxColors[box.classId % Self.boxColors.count].setStroke()
                cg.stroke(CGRect(
                    x: CGFloat(box.x1),
                    y: CGFloat(box.y1),
                    width: CGFloat(box.x2 - box.x1),
                    height: CGFloat(box.y2 - box.y1)
                ))
            }
        }
    }
}
