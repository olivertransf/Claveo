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
                            Menu {
                                Button {
                                    selectedTag = nil
                                } label: {
                                    HStack {
                                        Text("All")
                                        if selectedTag == nil {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                
                                ForEach(RecordingTag.allCases, id: \.self) { tag in
                                    Button {
                                        selectedTag = tag.rawValue
                                    } label: {
                                        HStack {
                                            Text(tag.rawValue)
                                            if selectedTag == tag.rawValue {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label("Tags", systemImage: "tag")
                            }
                            
                            Menu {
                                Button {
                                    selectedPiece = nil
                                } label: {
                                    HStack {
                                        Text("All")
                                        if selectedPiece == nil {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                
                                if availablePieces.isEmpty {
                                    Text("No pieces")
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(availablePieces, id: \.id) { piece in
                                        Button {
                                            selectedPiece = piece.name
                                        } label: {
                                            HStack {
                                                Text(piece.displayName)
                                                if selectedPiece == piece.name {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label("Pieces", systemImage: "music.note")
                            }
                            
                            if selectedTag != nil || selectedPiece != nil {
                                Divider()
                                
                                Button(role: .destructive) {
                                    selectedTag = nil
                                    selectedPiece = nil
                                } label: {
                                    Label("Clear All Filters", systemImage: "xmark.circle")
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
            
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .opacity(recorder.isRecording ? 1 : 0.5)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: recorder.isRecording)
                        .shadow(color: Color.red.opacity(0.5), radius: 4, x: 0, y: 0)
                    
                    Text(formatTime(recorder.recordingTime))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                LiveWaveformView(audioLevels: recorder.waveformLevels, maxBars: maxBars)
                    .frame(height: waveformHeight)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, isPhone ? 20 : 28)
            .padding(.vertical, isPhone ? 20 : 24)
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
            ZStack(alignment: .center) {
                if recorder.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .blur(radius: 8)
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 72, height: 72)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .blur(radius: 8)
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 80, height: 80)
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
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

