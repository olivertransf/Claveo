//
//  PlaybackSpeedControl.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct PlaybackSpeedControl: View {
    @EnvironmentObject var themeManager: ThemeManager
    let onSpeedChange: (Float) -> Void
    @State private var selectedSpeed: Float = 1.0
    
    private let speeds: [(Float, String)] = [
        (0.5, "0.5x"),
        (0.75, "0.75x"),
        (1.0, "1x"),
        (1.25, "1.25x"),
        (1.5, "1.5x"),
        (2.0, "2x")
    ]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(speeds, id: \.0) { speed, label in
                Button(action: {
                    selectedSpeed = speed
                    onSpeedChange(speed)
                }) {
                    Text(label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(selectedSpeed == speed ? .white : .themeLabel)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedSpeed == speed ? Color.themeAccent : Color.themeFill)
                        .cornerRadius(8)
                }
            }
        }
    }
}

