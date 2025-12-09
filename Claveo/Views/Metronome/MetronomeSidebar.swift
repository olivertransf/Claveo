//
//  MetronomeView+Sidebar.swift
//  Claveo
//
//  Sidebar content split from MetronomeView.
//

import SwiftUI

extension MetronomeView {
    var sidebarView: some View {
        GeometryReader { geometry in
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Text("Time Signature")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(TimeSignature.allCases, id: \.self) { signature in
                            Button(action: {
                                metronome.setTimeSignature(signature)
                            }) {
                                HStack {
                                    Text(signature.rawValue)
                                    if metronome.timeSignature == signature {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(metronome.timeSignature.rawValue)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.accentColor)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                
                VStack(spacing: 16) {
                    Text("Tap Tempo")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Button(action: tapTempo) {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 48, weight: .medium))
                            Text("Tap")
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(themeManager.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                VStack(spacing: 12) {
                    Text("Beat Pattern")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    let spacing: CGFloat = 6
                    let circleSize: CGFloat = 44
                    let _ = geometry.size.width - 48
                    
                    HStack(spacing: spacing) {
                        ForEach(0..<metronome.beatPattern.count, id: \.self) { index in
                            Circle()
                                .fill(
                                    index == metronome.currentBeat && metronome.isPlaying ?
                                    Color.red :
                                    (metronome.beatPattern[index] ? themeManager.accentColor : Color(.systemGray5))
                                )
                                .frame(width: circleSize, height: circleSize)
                                .overlay(
                                    Text("\(index + 1)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
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
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}


