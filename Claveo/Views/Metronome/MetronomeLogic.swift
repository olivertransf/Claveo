//
//  MetronomeView+Logic.swift
//  Claveo
//
//  Helper methods separated from the main view.
//

import Foundation
import SwiftUI

extension MetronomeView {
    func syncSettingsFromManager() {
        let sound = settingsManager.metronomeSoundEnum
        if metronome.soundType != sound {
            metronome.soundType = sound
        }
        let hapticEnabled = settingsManager.settings.metronomeHapticEnabled
        if metronome.hapticEnabled != hapticEnabled {
            metronome.hapticEnabled = hapticEnabled
        }
    }
    
    func toggleBeat(_ index: Int) {
        metronome.beatPattern[index].toggle()
    }
    
    func tapTempo() {
        let now = Date()
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if tapTimes.count > 0 {
                tapTimes.removeAll()
            }
        }
    }
}


