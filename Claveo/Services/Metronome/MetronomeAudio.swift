//
//  Metronome+Audio.swift
//  Claveo
//
//  Audio engine setup and sound generation extracted from Metronome.
//
//  Copyright (c) 2025 Oliver Tran

import AVFoundation
import Foundation
import QuartzCore

extension Metronome {
    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("Failed to setup audio session: \(error)")
            #endif
        }
    }
    
    func setupAudioPlayer() {
        stopAudioEngine()
        
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else { return }
        
        engine.attach(player)
        
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        engine.connect(player, to: mainMixer, format: outputFormat)
        
        let volume = SettingsManager.shared.settings.metronomeVolume
        let emphasizedSound = createSound(for: SettingsManager.shared.metronomeEmphasizedSoundEnum, volume: volume)
        let nonEmphasizedSound = createSound(for: SettingsManager.shared.metronomeNonEmphasizedSoundEnum, volume: volume)

        accentBuffer = createAudioBuffer(from: emphasizedSound, targetFormat: outputFormat)
        normalBuffer = createAudioBuffer(from: nonEmphasizedSound, targetFormat: outputFormat)
        
        accentBufferConverted = accentBuffer
        normalBufferConverted = normalBuffer
        
        engine.prepare()
    }
    
    func stopAudioEngine() {
        playerNode?.stop()
        playerNode?.reset()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        accentBuffer = nil
        normalBuffer = nil
        accentBufferConverted = nil
        normalBufferConverted = nil
    }
    
    func createAudioBuffer(from wavData: Data, targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("metronome_temp_\(UUID().uuidString).wav")
        
        do {
            try wavData.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            
            let audioFile = try AVAudioFile(forReading: tempURL)
            let sourceFormat = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            
            guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
                return nil
            }
            
            try audioFile.read(into: sourceBuffer)
            
            if sourceFormat.isEqual(targetFormat) {
                return sourceBuffer
            }
            
            return convertBuffer(sourceBuffer, to: targetFormat)
        } catch {
            #if DEBUG
            print("Failed to create audio buffer: \(error)")
            #endif
            return nil
        }
    }
    
    func createSound(for type: MetronomeSound, volume: Double = 0.5) -> Data {
        switch type {
        case .click:
            return createPreciseClickSound(frequency: 1000.0, volume: volume)
        case .woodBlock:
            return createPreciseClickSound(frequency: 400.0, volume: volume)
        case .bell:
            return createShortBellSound(frequency: 600.0, volume: volume)
        case .beep:
            return createPreciseClickSound(frequency: 880.0, volume: volume)
        case .tick:
            return createPreciseClickSound(frequency: 2000.0, volume: volume)
        case .cowbell:
            return createCowbellSound(volume: volume)
        case .triangle:
            return createTriangleSound(volume: volume)
        case .marimba:
            return createMarimbaSound(volume: volume)
        case .drum:
            return createDrumSound(volume: volume)
        case .chimes:
            return createChimesSound(volume: volume)
        }
    }

    // Legacy method for backward compatibility
    func createSounds(for type: MetronomeSound) -> (Data, Data) {
        let sound = createSound(for: type)
        let softerSound = createSound(for: type) // Same sound for now, volume is handled differently
        return (sound, softerSound)
    }
    
    func createPreciseClickSound(frequency: Double = 1000.0, volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.01
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else {
            return Data()
        }
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let fundamental = sin(2.0 * Double.pi * frequency * t)
            let harmonic = 0.3 * sin(2.0 * Double.pi * frequency * 2.0 * t)
            let envelope = exp(-t * 100.0)
            let sample = (fundamental + harmonic) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }
        
        return convertPCMBufferToWAV(buffer)
    }
    
    func createShortBellSound(frequency: Double = 600.0, volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.015
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else {
            return Data()
        }
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let fundamental = sin(2.0 * Double.pi * frequency * t)
            let harmonic2 = 0.4 * sin(2.0 * Double.pi * frequency * 2.0 * t)
            let harmonic3 = 0.2 * sin(2.0 * Double.pi * frequency * 3.0 * t)
            let envelope = exp(-t * 60.0)
            let sample = (fundamental + harmonic2 + harmonic3) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }
        
        return convertPCMBufferToWAV(buffer)
    }

    func createCowbellSound(volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.08

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            return Data()
        }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Cowbell-like sound: fundamental at 800Hz with strong harmonics
            let fundamental = sin(2.0 * Double.pi * 800.0 * t)
            let harmonic2 = 0.6 * sin(2.0 * Double.pi * 1600.0 * t)
            let harmonic3 = 0.4 * sin(2.0 * Double.pi * 2400.0 * t)
            let envelope = exp(-t * 20.0)
            let sample = (fundamental + harmonic2 + harmonic3) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }

        return convertPCMBufferToWAV(buffer)
    }

    func createTriangleSound(volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.1

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            return Data()
        }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Triangle-like sound: bright, metallic
            let fundamental = sin(2.0 * Double.pi * 1200.0 * t)
            let harmonic2 = 0.5 * sin(2.0 * Double.pi * 2400.0 * t)
            let harmonic3 = 0.3 * sin(2.0 * Double.pi * 3600.0 * t)
            let harmonic4 = 0.2 * sin(2.0 * Double.pi * 4800.0 * t)
            let envelope = exp(-t * 15.0)
            let sample = (fundamental + harmonic2 + harmonic3 + harmonic4) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }

        return convertPCMBufferToWAV(buffer)
    }

    func createMarimbaSound(volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.15

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            return Data()
        }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Marimba-like sound: warm, woody tone
            let fundamental = sin(2.0 * Double.pi * 300.0 * t)
            let harmonic2 = 0.8 * sin(2.0 * Double.pi * 600.0 * t)
            let harmonic3 = 0.6 * sin(2.0 * Double.pi * 900.0 * t)
            let harmonic4 = 0.4 * sin(2.0 * Double.pi * 1200.0 * t)
            let envelope = exp(-t * 8.0) * (1.0 - exp(-t * 50.0)) // Attack envelope
            let sample = (fundamental + harmonic2 + harmonic3 + harmonic4) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }

        return convertPCMBufferToWAV(buffer)
    }

    func createDrumSound(volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.12

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            return Data()
        }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Drum-like sound: low frequency with noise component
            let fundamental = sin(2.0 * Double.pi * 100.0 * t)
            let harmonic2 = 0.5 * sin(2.0 * Double.pi * 200.0 * t)
            let noise = (Double.random(in: -1...1)) * 0.2
            let envelope = exp(-t * 12.0)
            let sample = (fundamental + harmonic2 + noise) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }

        return convertPCMBufferToWAV(buffer)
    }

    func createChimesSound(volume: Double = 0.5) -> Data {
        let sampleRate = 44100.0
        let duration = 0.2

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * duration)) else {
            return Data()
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            return Data()
        }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Chimes-like sound: bell-like with strong harmonics
            let fundamental = sin(2.0 * Double.pi * 500.0 * t)
            let harmonic2 = 0.7 * sin(2.0 * Double.pi * 1000.0 * t)
            let harmonic3 = 0.5 * sin(2.0 * Double.pi * 1500.0 * t)
            let harmonic4 = 0.3 * sin(2.0 * Double.pi * 2000.0 * t)
            let harmonic5 = 0.2 * sin(2.0 * Double.pi * 2500.0 * t)
            let envelope = exp(-t * 6.0)
            let sample = (fundamental + harmonic2 + harmonic3 + harmonic4 + harmonic5) * envelope * volume
            channelData[0][i] = Float(max(-1.0, min(1.0, sample)))
        }

        return convertPCMBufferToWAV(buffer)
    }

    func convertPCMBufferToWAV(_ buffer: AVAudioPCMBuffer) -> Data {
        let format = buffer.format
        let sampleRate = format.sampleRate
        let channels = format.channelCount
        let bitsPerSample: UInt16 = 16
        
        guard let channelData = buffer.floatChannelData else {
            return Data()
        }
        
        let frameCount = Int(buffer.frameLength)
        var audioData = [Int16]()
        
        for i in 0..<frameCount {
            let sample = channelData[0][i]
            let intSample = Int16(max(-1.0, min(1.0, sample)) * Float(Int16.max))
            audioData.append(intSample)
        }
        
        let dataSize = UInt32(audioData.count * MemoryLayout<Int16>.size)
        let fileSize = 36 + dataSize
        
        var wavData = Data()
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        
        let channelsUInt = UInt16(channels)
        let byteRate = UInt32(sampleRate * Double(channelsUInt) * Double(bitsPerSample) / 8.0)
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        
        let blockAlign = UInt16(channelsUInt * bitsPerSample / 8)
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        wavData.append("data".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        
        audioData.withUnsafeBytes { buffer in
            wavData.append(contentsOf: buffer)
        }
        
        return wavData
    }
    
    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format.isEqual(format) {
            return buffer
        }
        
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            return nil
        }
        
        let inputSampleRate = buffer.format.sampleRate
        let outputSampleRate = format.sampleRate
        let ratio = outputSampleRate / inputSampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputCapacity) else {
            return nil
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            #if DEBUG
            print("Buffer conversion error: \(error)")
            #endif
            return nil
        }
        
        return outputBuffer
    }
}


