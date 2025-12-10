//
//  MetronomeView+Sidebar.swift
//  Claveo
//
//  Sidebar content split from MetronomeView.
//

import SwiftUI

extension MetronomeView {
    var sidebarView: some View {
        NavigationStack {
            List {
                Section {
                    Menu {
                        ForEach(TimeSignature.allCases, id: \.self) { signature in
                            Button {
                                metronome.setTimeSignature(signature)
                            } label: {
                                HStack {
                                    Text(signature.rawValue)
                                    if metronome.customTimeSignature == nil && metronome.timeSignature == signature {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            prepareCustomTimeSignature()
                        } label: {
                            HStack {
                                Text("Custom…")
                                Spacer()
                                if metronome.customTimeSignature != nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.accentColor)
                                }
                            }
                        }
                        
                        if metronome.customTimeSignature != nil {
                            Button("Clear Custom", role: .destructive) {
                                metronome.setTimeSignature(.fourFour)
                            }
                        }
                    } label: {
                        HStack {
                            Label("Time Signature", systemImage: "music.note")
                            Spacer()
                            Text(metronome.displayTimeSignature)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.accentColor)
                        }
                    }
                    .tint(themeManager.accentColor)
                }
                
                Section {
                    Button(action: tapTempo) {
                        Label("Tap Tempo", systemImage: "hand.tap")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(themeManager.accentColor)
                }
                
                Section {
                    beatPatternGrid
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Beat Pattern")
                } footer: {
                    Text("Tap a beat to accent.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Metronome")
            .listStyle(.sidebar)
        }
    }
    
    private var beatPatternGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 56), spacing: 12)]
        
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(0..<metronome.beatPattern.count, id: \.self) { index in
                Circle()
                    .fill(
                        index == metronome.currentBeat && metronome.isPlaying ?
                        Color.red :
                        (metronome.beatPattern[index] ? themeManager.accentColor : Color(.systemGray5))
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text("\(index + 1)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(
                                index == metronome.currentBeat && metronome.isPlaying ?
                                .white :
                                (metronome.beatPattern[index] ? .white : .secondary)
                            )
                    )
                    .onTapGesture {
                        toggleBeat(index)
                    }
                    .animation(.easeInOut(duration: 0.1), value: metronome.currentBeat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var customTimeSignatureSheet: some View {
        NavigationStack {
            Form {
                Section("Top Number") {
                    Stepper(value: $customTop, in: 1...16) {
                        Text("\(customTop)")
                    }
                }
                
                Section("Bottom Number") {
                    Picker("Bottom", selection: $customBottom) {
                        ForEach([1, 2, 4, 8, 16], id: \.self) { value in
                            Text("\(value)")
                                .tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Button("Save Custom Time Signature") {
                        saveCustomTimeSignature()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.accentColor)
                }
            }
            .navigationTitle("Custom Time Signature")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCustomTimeSignatureSheet = false
                    }
                }
            }
        }
    }
}


