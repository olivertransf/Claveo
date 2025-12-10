//
//  RecordingListView+Navigation.swift
//  Claveo
//
//  Navigation-specific subviews for RecordingListView.
//

import SwiftUI

extension RecordingListView {
    var iPadView: some View {
        NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
            sidebarView
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
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
                            .padding(.bottom, 40)
                    }
                }
                .navigationTitle("Recordings")
            }
        }
        .searchable(text: $searchText, prompt: "Search recordings")
    }
    
    var iPhoneView: some View {
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
        }
    }
    
    var sidebarView: some View {
        NavigationStack {
            List {
                Section("Filters") {
                    if selectedTag != nil || selectedPiece != nil {
                        if let tag = selectedTag {
                            HStack {
                                Label(tag, systemImage: "tag.fill")
                                    .foregroundColor(themeManager.accentColor)
                                Spacer()
                                Button {
                                    selectedTag = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if let piece = selectedPiece {
                            HStack {
                                Label(piece, systemImage: "music.note")
                                    .foregroundColor(themeManager.accentColor)
                                Spacer()
                                Button {
                                    selectedPiece = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Button {
                            selectedTag = nil
                            selectedPiece = nil
                        } label: {
                            Label("Clear All Filters", systemImage: "xmark.circle")
                        }
                        .foregroundColor(.red)
                    }
                    
                    Menu {
                        Menu {
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
                            if filteredSidebarPieces.isEmpty {
                                Text("No pieces")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(filteredSidebarPieces, id: \.id) { piece in
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
                    } label: {
                        Label("Add Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                
                Section("Pieces") {
                    if filteredSidebarPieces.isEmpty {
                        Text(pieceSearchText.isEmpty ? "No pieces yet" : "No matching pieces")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(filteredSidebarPieces, id: \.id) { piece in
                            Button {
                                editingPiece = piece
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(piece.name)
                                            .font(.body)
                                        if let composer = piece.composer, !composer.isEmpty {
                                            Text(composer)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("(\(recordingCount(for: piece.name)))")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    if selectedPiece == piece.name {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(themeManager.accentColor)
                                            .padding(.leading, 4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Button {
                        availablePieces = loadAvailablePieces()
                        showingPiecesManagement = true
                    } label: {
                        Label("Manage Pieces", systemImage: "gearshape")
                    }
                    .foregroundColor(themeManager.accentColor)
                }
            }
            .listStyle(.sidebar)
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

