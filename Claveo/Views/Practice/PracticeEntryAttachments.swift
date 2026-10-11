//
//  PracticeEntryAttachments.swift
//  Claveo
//
//  Copyright (c) 2026 Oliver Tran

import PhotosUI
import SwiftUI
import UIKit

struct PracticeEntryAttachmentsEditor: View {
    @Binding var photoFileNames: [String]
    @Binding var voiceMemoFileNames: [String]
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var memoRecorder = PracticeMemoRecorder()
    @StateObject private var memoPlayer = PracticeMemoPlayer()
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var previewName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            photoSection
            memoSection
        }
        .task(id: photoFileNames) {
            for name in photoFileNames {
                await PracticeAttachmentStore.prepare(name)
            }
        }
        .task(id: voiceMemoFileNames) {
            for name in voiceMemoFileNames {
                await PracticeAttachmentStore.prepare(name)
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Photos", systemImage: "photo")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if !photoFileNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photoFileNames, id: \.self) { name in
                            photoThumb(name)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker { image in
                savePhoto(image)
            }
        }
        .sheet(item: previewBinding) { name in
            PracticePhotoPreview(fileName: name.value)
        }
    }

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Voice Memos", systemImage: "mic")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(voiceMemoFileNames, id: \.self) { name in
                HStack {
                    Button {
                        memoPlayer.toggle(name)
                    } label: {
                        Label(
                            memoPlayer.playingFileName == name
                                ? String(localized: "Stop")
                                : String(localized: "Play"),
                            systemImage: memoPlayer.playingFileName == name ? "stop.fill" : "play.fill"
                        )
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                    }
                    Button(role: .destructive) {
                        if memoPlayer.playingFileName == name { memoPlayer.stop() }
                        voiceMemoFileNames.removeAll { $0 == name }
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(String(localized: "Delete voice memo"))
                }
            }

            Button {
                Task {
                    if let fileName = await memoRecorder.toggle() {
                        voiceMemoFileNames.append(fileName)
                    }
                }
            } label: {
                Label(
                    memoRecorder.isRecording
                        ? String(localized: "Stop Memo \(memoClock)")
                        : String(localized: "Record Memo"),
                    systemImage: memoRecorder.isRecording ? "stop.circle.fill" : "mic.circle"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(memoRecorder.isRecording ? Color.white : themeManager.onAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(memoRecorder.isRecording ? Color.themeStop : themeManager.accentColor)

            if let errorMessage = memoRecorder.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var memoClock: String {
        let seconds = Int(memoRecorder.elapsed)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var previewBinding: Binding<PhotoName?> {
        Binding(
            get: { previewName.map(PhotoName.init) },
            set: { previewName = $0?.value }
        )
    }

    private func photoThumb(_ name: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                previewName = name
            } label: {
                PracticePhotoImage(fileName: name)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel(String(localized: "Practice photo"))

            Button {
                photoFileNames.removeAll { $0 == name }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "Remove photo"))
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        savePhoto(image)
    }

    private func savePhoto(_ image: UIImage) {
        guard let name = try? PracticeAttachmentStore.savePhoto(image) else { return }
        photoFileNames.append(name)
    }
}

struct PracticeEntryAttachmentsSummary: View {
    let photoFileNames: [String]
    let voiceMemoFileNames: [String]
    @StateObject private var memoPlayer = PracticeMemoPlayer()
    @State private var previewName: String?

    var body: some View {
        if photoFileNames.isEmpty && voiceMemoFileNames.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if !photoFileNames.isEmpty {
                    Text("Photos")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(photoFileNames, id: \.self) { name in
                                Button {
                                    previewName = name
                                } label: {
                                    PracticePhotoImage(fileName: name)
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .accessibilityLabel(String(localized: "Practice photo"))
                            }
                        }
                    }
                }
                if !voiceMemoFileNames.isEmpty {
                    Text("Voice Memos")
                        .font(.headline)
                    ForEach(voiceMemoFileNames, id: \.self) { name in
                        Button {
                            memoPlayer.toggle(name)
                        } label: {
                            Label(
                                memoPlayer.playingFileName == name
                                    ? String(localized: "Stop")
                                    : String(localized: "Play"),
                                systemImage: memoPlayer.playingFileName == name ? "stop.fill" : "play.fill"
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.themeSecondaryBackground)
            .cornerRadius(12)
            .task(id: photoFileNames + voiceMemoFileNames) {
                for name in photoFileNames + voiceMemoFileNames {
                    await PracticeAttachmentStore.prepare(name)
                }
            }
            .sheet(item: Binding(
                get: { previewName.map(PhotoName.init) },
                set: { previewName = $0?.value }
            )) { name in
                PracticePhotoPreview(fileName: name.value)
            }
        }
    }
}

private struct PhotoName: Identifiable {
    let value: String
    var id: String { value }
}

private struct PracticePhotoImage: View {
    let fileName: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.tertiarySystemFill)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task(id: fileName) {
            await PracticeAttachmentStore.prepare(fileName)
            image = UIImage(contentsOfFile: PracticeAttachmentStore.fileURL(for: fileName).path)
        }
    }
}

private struct PracticePhotoPreview: View {
    let fileName: String
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await PracticeAttachmentStore.prepare(fileName)
                image = UIImage(contentsOfFile: PracticeAttachmentStore.fileURL(for: fileName).path)
            }
        }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
