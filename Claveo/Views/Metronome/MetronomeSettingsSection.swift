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

    private var volume: Double {
        settingsManager.settings.metronomeVolume
    }

    var body: some View {
        Section {
            soundPicker(
                title: String(localized: "Emphasized Sound"),
                systemImage: "speaker.wave.3.fill",
                selection: settingsManager.metronomeEmphasizedSoundEnum
            ) { settingsManager.setMetronomeEmphasizedSound($0) }

            soundPicker(
                title: String(localized: "Non-Emphasized Sound"),
                systemImage: "speaker.wave.1.fill",
                selection: settingsManager.metronomeNonEmphasizedSoundEnum
            ) { settingsManager.setMetronomeNonEmphasizedSound($0) }

            volumeControl

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
        } header: {
            Text("Metronome")
        } footer: {
            Text("Tap a sound to hear it. Metronome volume is combined with the system volume.")
        }
    }

    private func soundPicker(
        title: String,
        systemImage: String,
        selection: MetronomeSound,
        onChange: @escaping (MetronomeSound) -> Void
    ) -> some View {
        Picker(selection: Binding(
            get: { selection },
            set: { sound in
                onChange(sound)
                MetronomeSoundPreview.shared.play(sound, gain: volume)
            }
        )) {
            ForEach(MetronomeSound.allCases, id: \.self) { sound in
                Text(sound.localizedName).tag(sound)
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private var volumeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Volume", systemImage: "speaker.wave.2")
                Spacer()
                Text("\(Int((volume * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { volume },
                        // Persisting every drag step writes settings to iCloud
                        // repeatedly, so only the released value is committed.
                        set: { settingsManager.updateLive(\.metronomeVolume, value: $0) }
                    ),
                    in: 0.0...1.0,
                    step: 0.05,
                    onEditingChanged: { isEditing in
                        guard !isEditing else { return }
                        settingsManager.update(\.metronomeVolume, value: volume)
                        MetronomeSoundPreview.shared.play(
                            settingsManager.metronomeEmphasizedSoundEnum,
                            gain: volume
                        )
                    }
                )
                .accessibilityLabel(String(localized: "Metronome Volume"))
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
