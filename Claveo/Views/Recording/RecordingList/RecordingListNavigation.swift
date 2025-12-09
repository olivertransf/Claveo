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
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            NavigationStack {
                mainContentView
                    .navigationBarTitleDisplayMode(.inline)
                    .searchable(text: $searchText, prompt: "Search recordings...")
            }
        }
    }
    
    var iPhoneView: some View {
        NavigationStack {
            mainContentView
                .navigationBarTitleDisplayMode(.inline)
                .if(isSearchPresented) { view in
                    view.searchable(
                        text: $searchText,
                        isPresented: $isSearchPresented,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search recordings..."
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if !isSearchPresented {
                            Button {
                                let loaded = loadAvailablePieces()
                                availablePieces = loaded
                                showingPiecesManagement = true
                            } label: {
                                Image(systemName: "music.note.list")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                    }
                    
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        if !isSearchPresented {
                            Button {
                                withAnimation {
                                    isSearchPresented = true
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(themeManager.accentColor)
                            }
                            
                            filterButton
                        }
                    }
                }
        }
    }
    
    var sidebarView: some View {
        List {
            Section {
                Button(action: {
                    let loaded = loadAvailablePieces()
                    availablePieces = loaded
                    showingPiecesManagement = true
                }) {
                    Label {
                        Text("Pieces")
                            .foregroundColor(.primary)
                    } icon: {
                        Image(systemName: "music.note.list")
                            .foregroundColor(themeManager.accentColor)
                    }
                }
                
                Button(action: {
                    showingFilterSheet = true
                }) {
                    Label {
                        HStack {
                            Text("Filter")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedTag != nil || selectedPiece != nil {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    } icon: {
                        Image(systemName: selectedTag != nil || selectedPiece != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor((selectedTag != nil || selectedPiece != nil) ? themeManager.accentColor : .secondary)
                    }
                }
            }
            
            Section {
                Button(action: {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        Task {
                            await recorder.startRecording()
                        }
                    }
                }) {
                    Label {
                        Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                            .foregroundColor(recorder.isRecording ? .red : themeManager.accentColor)
                    } icon: {
                        Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .foregroundColor(recorder.isRecording ? .red : themeManager.accentColor)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    var filterButton: some View {
        Button(action: {
            showingFilterSheet = true
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: selectedTag != nil || selectedPiece != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(themeManager.accentColor)
                
                if selectedTag != nil || selectedPiece != nil {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
}


