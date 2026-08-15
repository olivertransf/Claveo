//
//  RecordingListView+Navigation.swift
//  Claveo
//
//  Navigation-specific subviews for RecordingListView.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

extension RecordingListView {
    var unifiedView: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                mainContentView
                    .refreshable {
                        await recorder.refreshRecordings()
                    }
            }
            .overlay {
                if recorder.isRecording {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.5),
                            Color.black.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    if recorder.isRecording {
                        recordingIndicatorView
                    }

                    recordingButtonOverlay
                        .padding(.top, recorder.isRecording ? 0 : 8)
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                if isSelectingRecordings {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            exitRecordingSelectionMode()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            exportSelectedRecordings()
                        } label: {
                            if selectedRecordingIds.isEmpty {
                                Text("Export")
                            } else {
                                Text("Export (\(selectedRecordingIds.count))")
                            }
                        }
                        .disabled(selectedRecordingIds.isEmpty)
                    }
                } else {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button {
                            availablePieces = loadAvailablePieces()
                            showingPiecesManagement = true
                        } label: {
                            Label("Pieces", systemImage: "music.note.list")
                                .symbolRenderingMode(.monochrome)
                        }
                    }
                    
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Menu {
                            Section {
                                Button {
                                    selectedTag = nil
                                } label: {
                                    filterMenuRow(title: String(localized: "Any tag"), selected: selectedTag == nil)
                                }

                                ForEach(RecordingTag.allCases, id: \.self) { tag in
                                    Button {
                                        selectedTag = tag.rawValue
                                    } label: {
                                        filterMenuRow(title: tag.localizedName, selected: selectedTag == tag.rawValue)
                                    }
                                }
                            } header: {
                                Label("Tags", systemImage: "tag.fill")
                            }

                            Section {
                                Button {
                                    selectedPiece = nil
                                } label: {
                                    filterMenuRow(title: String(localized: "Any piece"), selected: selectedPiece == nil)
                                }

                                if availablePieces.isEmpty {
                                    Text("No pieces in library")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(availablePieces, id: \.id) { piece in
                                        Button {
                                            selectedPiece = piece.name
                                        } label: {
                                            filterMenuRow(
                                                title: piece.displayName,
                                                selected: selectedPiece == piece.name
                                            )
                                        }
                                    }
                                }
                            } header: {
                                Label("Pieces", systemImage: "music.note.list")
                            }

                            if selectedTag != nil || selectedPiece != nil {
                                Section {
                                    Button(role: .destructive) {
                                        selectedTag = nil
                                        selectedPiece = nil
                                    } label: {
                                        Label("Clear all filters", systemImage: "xmark.circle.fill")
                                    }
                                }
                            }
                        } label: {
                            Label("Filter", systemImage: filterToolbarIcon)
                                .symbolRenderingMode(.monochrome)
                        }

                        Button {
                            beginRecordingSelectionMode()
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                                .symbolRenderingMode(.monochrome)
                        }

                    }
                }
            }
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
            .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search recordings")
        }

        .sheet(isPresented: $showingStorageInfo) {
            StorageInfoView()
                .environmentObject(themeManager)
        }
    }


    struct StorageInfoView: View {
        @Environment(\.dismiss) private var dismiss
        @EnvironmentObject var themeManager: ThemeManager
        @StateObject private var settingsManager = SettingsManager.shared

        var body: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your recordings are stored in:")
                        .font(.headline)

                    Text(iCloudManager.shared.getStoragePath())
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.themeTertiaryBackground)
                        .cornerRadius(8)

                    if settingsManager.settings.storeFilesOnDeviceOnly {
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Label("Files are stored on this iPad only", systemImage: "ipad")
                                .foregroundColor(.secondary)
                        } else {
                            Label("Files are stored on this iPhone only", systemImage: "iphone")
                                .foregroundColor(.secondary)
                        }
                    } else if iCloudManager.shared.isAvailable {
                        Label("Files will automatically sync to iCloud Drive", systemImage: "icloud.fill")
                            .foregroundColor(themeManager.accentColor)
                    } else {
                        Label("iCloud Drive is not available. Files are stored locally.", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    }

                    if !settingsManager.settings.storeFilesOnDeviceOnly && iCloudManager.shared.isAvailable {
                        Text("You can access your recordings in the Files app under:")
                            .font(.subheadline)
                            .foregroundColor(.themeSecondaryLabel)

                        Text("iCloud Drive → Claveo → Documents")
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.themeTertiaryBackground)
                            .cornerRadius(8)
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("Storage Information")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    func recordingCount(for pieceName: String) -> Int {
        recorder.recordings.filter { $0.piece == pieceName }.count
    }

    private var filterToolbarIcon: String {
        selectedTag != nil || selectedPiece != nil
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
    }
    
    var recordingIndicatorView: some View {
        GeometryReader { geometry in
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            let horizontalPadding: CGFloat = 48
            let waveformWidth = isPhone
                ? geometry.size.width - horizontalPadding
                : (geometry.size.width - horizontalPadding) * 0.5
            let waveformHeight = isPhone ? min(waveformWidth * 0.12, 50) : 60
            let barPitch: CGFloat = 5.5
            let maxBars = max(isPhone ? 60 : 70, Int(waveformWidth / barPitch))

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .opacity(recorder.isRecording ? 1 : 0.45)
                        .symbolEffect(.pulse, options: .repeating, isActive: recorder.isRecording)

                    Text(formatTime(recorder.recordingTime))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                LiveWaveformView(audioLevels: recorder.waveformLevels, maxBars: maxBars)
                    .frame(width: waveformWidth, height: waveformHeight)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 96)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    var recordingButtonOverlay: some View {
        Button(action: {
            if recorder.isRecording {
                recorder.stopRecording()
            } else {
                Task {
                    await recorder.startRecording()
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.18))
                    .frame(width: 76, height: 76)

                Circle()
                    .fill(Color.red)
                    .frame(width: 64, height: 64)

                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 76, height: 76)
        }
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }

    func filterMenuRow(title: String, selected: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 10)
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(themeManager.accentColor)
            }
        }
    }
}

struct ConditionalSearchableModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var searchText: String
    
    func body(content: Content) -> some View {
        if isPresented {
            content
                .searchable(text: $searchText, isPresented: $isPresented, prompt: "Search recordings")
        } else {
            content
        }
    }
}

