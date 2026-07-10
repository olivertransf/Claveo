//
//  MetronomeSettingsSection.swift
//  Claveo
//
//  Shared metronome settings used in Settings and on the Metronome tab.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct MetronomeSettingsSection: View {
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some View {
        Section("Metronome") {
            Picker("Emphasized Sound", selection: Binding(
                get: { settingsManager.metronomeEmphasizedSoundEnum },
                set: { settingsManager.setMetronomeEmphasizedSound($0) }
            )) {
                ForEach(MetronomeSound.allCases, id: \.self) { sound in
                    Text(sound.localizedName).tag(sound)
                }
            }

            Picker("Non-Emphasized Sound", selection: Binding(
                get: { settingsManager.metronomeNonEmphasizedSoundEnum },
                set: { settingsManager.setMetronomeNonEmphasizedSound($0) }
            )) {
                ForEach(MetronomeSound.allCases, id: \.self) { sound in
                    Text(sound.localizedName).tag(sound)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                    Spacer()
                    Text("\(Int(settingsManager.settings.metronomeVolume * 100))%")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Slider(
                    value: Binding(
                        get: { settingsManager.settings.metronomeVolume },
                        set: { settingsManager.update(\.metronomeVolume, value: $0) }
                    ),
                    in: 0.0...1.0,
                    step: 0.05
                )
                HStack {
                    Text("Quiet").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Loud").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            Toggle("Haptic Feedback", isOn: Binding(
                get: { settingsManager.settings.metronomeHapticEnabled },
                set: { settingsManager.update(\.metronomeHapticEnabled, value: $0) }
            ))

            Toggle("Auto-stop when switching tabs", isOn: Binding(
                get: { settingsManager.settings.metronomeAutoStopOnTabSwitch },
                set: { settingsManager.update(\.metronomeAutoStopOnTabSwitch, value: $0) }
            ))

            Toggle("Stop tone when leaving Metronome", isOn: Binding(
                get: { settingsManager.settings.stopToneWhenLeavingMetronomeTab },
                set: { settingsManager.update(\.stopToneWhenLeavingMetronomeTab, value: $0) }
            ))
        }
    }
}
