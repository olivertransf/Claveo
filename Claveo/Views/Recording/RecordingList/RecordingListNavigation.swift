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
                mainContentView
                    .refreshable {
                        await recorder.refreshRecordings()
                    }
                
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
                
                if recorder.isRecording {
                    VStack {
                        Spacer()
                        recordingIndicatorView
                            .padding(.bottom, 100)
                    }
                }
                
                VStack {
                    Spacer()
                    recordingButtonOverlay
                        .padding(.bottom, 10)
                }
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
                            showingOMRScanner = true
                        } label: {
                            HStack(spacing: 4) {
                                Label("OMR", systemImage: "doc.text.viewfinder")
                                Text("BETA")
                                    .font(.caption2.bold())
                                    .foregroundColor(.orange)
                            }
                        }

                        Button {
                            availablePieces = loadAvailablePieces()
                            showingPiecesManagement = true
                        } label: {
                            Label("Pieces", systemImage: "music.note.list")
                        }
                    }
                    
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Menu {
                            Section {
                                Button {
                                    selectedTag = nil
                                } label: {
                                    filterMenuRow(title: "Any tag", selected: selectedTag == nil)
                                }

                                ForEach(RecordingTag.allCases, id: \.self) { tag in
                                    Button {
                                        selectedTag = tag.rawValue
                                    } label: {
                                        filterMenuRow(title: tag.rawValue, selected: selectedTag == tag.rawValue)
                                    }
                                }
                            } header: {
                                Label("Tags", systemImage: "tag.fill")
                            }

                            Section {
                                Button {
                                    selectedPiece = nil
                                } label: {
                                    filterMenuRow(title: "Any piece", selected: selectedPiece == nil)
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
                            Label("Filter", systemImage: selectedTag != nil || selectedPiece != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }

                        Button {
                            beginRecordingSelectionMode()
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }

                    }
                }
            }
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search recordings")
        }

        .fullScreenCover(isPresented: $showingOMRScanner) {
            OMRScannerView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingStorageInfo) {
            StorageInfoView()
                .environmentObject(themeManager)
        }
    }


    struct StorageInfoView: View {
        @Environment(\.dismiss) private var dismiss
        @EnvironmentObject var themeManager: ThemeManager

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

                    if iCloudManager.shared.isAvailable {
                        Label("Files will automatically sync to iCloud Drive", systemImage: "icloud.fill")
                            .foregroundColor(themeManager.accentColor)
                    } else {
                        Label("iCloud Drive is not available. Files are stored locally.", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    }

                    Text("You can access your recordings in the Files app under:")
                        .font(.subheadline)
                        .foregroundColor(.themeSecondaryLabel)

                    Text("iCloud Drive → Claveo → Documents")
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.themeTertiaryBackground)
                        .cornerRadius(8)

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
    
    var recordingIndicatorView: some View {
        GeometryReader { geometry in
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            let waveformHeight = isPhone ? min(geometry.size.width * 0.12, 50) : 60
            let maxBars = isPhone ? 60 : 80
            
            VStack(spacing: 16) {
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
                    .frame(height: waveformHeight)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 120)
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
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }

    @ViewBuilder
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

