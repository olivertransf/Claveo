//
//  MetronomeView+Logic.swift
//  Claveo
//
//  Helper methods separated from the main view.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation
import SwiftUI

extension MetronomeView {
    func syncSettingsFromManager() {
        let hapticEnabled = settingsManager.settings.metronomeHapticEnabled
        if metronome.hapticEnabled != hapticEnabled {
            metronome.hapticEnabled = hapticEnabled
        }
    }
    
    func toggleBeat(_ index: Int) {
        HapticFeedback.lightImpact()
        withAnimation(.easeOut(duration: 0.15)) {
            metronome.toggleBeatAccent(at: index)
        }
    }

    /// Derives selectedNoteIndex and selectedToneOctave from the current tone generator frequency.
    /// Uses the same MIDI formula as tonePitchButton: midi = 24 + (octave - 1) * 12 + noteIndex.
    func syncNoteSelection() {
        let a4 = settingsManager.settings.a4ReferenceFrequency
        let hz = toneGenerator.frequency
        let rawMidi = 69.0 + 12.0 * log2(hz / a4)
        let midi = Int(rawMidi.rounded())
        let relMidi = midi - 24
        guard relMidi >= 0 else { return }
        let octave = relMidi / 12 + 1
        let noteIndex = relMidi % 12
        guard (1...6).contains(octave) else { return }
        selectedNoteIndex = noteIndex
        selectedToneOctave = octave
    }
    
    func tapTempo() {
        HapticFeedback.lightImpact()
        let now = Date()
        // A long pause means a new count-in, not a very slow tempo.
        if let last = tapTimes.last, now.timeIntervalSince(last) > 2 {
            tapTimes.removeAll()
        }
        tapTimes.append(now)
        
        if tapTimes.count > 4 {
            tapTimes.removeFirst()
        }
        
        if tapTimes.count >= 2 {
            let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0.timeIntervalSince($1) }
            let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
            let calculatedTempo = Int(60.0 / averageInterval)
            metronome.tempo = max(20, min(300, calculatedTempo))
        }

        let clearAfter = now
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard let last = tapTimes.last, last <= clearAfter else { return }
            tapTimes.removeAll()
        }
    }
    
    func prepareCustomTimeSignature() {
        customTop = metronome.customTimeSignature?.top ?? metronome.beatsPerMeasure
        customBottom = metronome.customTimeSignature?.bottom ?? 4
        showingCustomTimeSignatureSheet = true
    }
    
    func saveCustomTimeSignature() {
        HapticFeedback.lightImpact()
        metronome.setCustomTimeSignature(top: customTop, bottom: customBottom)
        showingCustomTimeSignatureSheet = false
    }
}


