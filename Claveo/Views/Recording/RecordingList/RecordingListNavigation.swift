//
//  RecordingListView+Navigation.swift
//  Claveo
//
//  Navigation-specific subviews for RecordingListView.
//

import SwiftUI

extension RecordingListView {
    var unifiedView: some View {
        NavigationStack {
            ZStack {
                mainContentView
                
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        availablePieces = loadAvailablePieces()
                        showingPiecesManagement = true
                    } label: {
                        Label("Pieces", systemImage: "music.note.list")
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isSearchFocused = true
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    
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
                }
            }
            .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search recordings")
        }
    }
    
    func recordingCount(for pieceName: String) -> Int {
        recorder.recordings.filter { $0.piece == pieceName }.count
    }
    
    var recordingIndicatorView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(recorder.isRecording ? 1 : 0.5)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: recorder.isRecording)
            
            Text(formatTime(recorder.recordingTime))
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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

