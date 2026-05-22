@preconcurrency import AVFAudio
import AVFoundation
import Combine
import SwiftUI

@MainActor
final class TrimPreviewPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var stopAtTime: TimeInterval?

    func load(url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentTime = 0
        } catch {
            player = nil
            duration = 0
            currentTime = 0
        }
    }

    func play(from start: TimeInterval, to end: TimeInterval) {
        guard let player else { return }
        stopAtTime = end
        player.currentTime = max(0, min(start, player.duration))
        player.play()
        isPlaying = true
        startTimer(player: player, stopAt: end)
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopAtTime = nil
        timer?.invalidate()
        timer = nil
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = max(0, min(time, player.duration))
        currentTime = player.currentTime
    }

    private func startTimer(player: AVAudioPlayer, stopAt: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                let t = player.currentTime
                self.currentTime = t
                if t >= stopAt {
                    self.pause()
                }
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            pause()
            seek(to: 0)
        }
    }
}

struct RecordingTrimView: View {
    let recording: Recording
    let onApply: (Recording) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @StateObject private var previewPlayer = TrimPreviewPlayer()
    @State private var waveformBars: [Float] = []
    @State private var isLoadingWaveform = true
    @State private var startTime: TimeInterval
    @State private var endTime: TimeInterval
    @State private var isTrimming = false
    @State private var errorMessage: String?
    @State private var showingError = false

    init(recording: Recording, onApply: @escaping (Recording) -> Void) {
        self.recording = recording
        self.onApply = onApply
        _startTime = State(initialValue: 0)
        _endTime = State(initialValue: max(recording.duration, 0))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    if !FileManager.default.fileExists(atPath: recording.fileURL.path) {
                        Label("File not found", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    } else if isLoadingWaveform {
                        ProgressView()
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                    } else {
                        TrimWaveformView(
                            bars: waveformBars,
                            duration: effectiveDuration,
                            currentTime: previewPlayer.currentTime,
                            selectionStart: $startTime,
                            selectionEnd: $endTime,
                            accentColor: themeManager.accentColor,
                            onSeek: { t in
                                previewPlayer.seek(to: t)
                            }
                        )
                        .frame(height: 160)
                        .padding(.horizontal, 16)
                    }

                    HStack {
                        Text(formatTime(startTime))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(max(0, endTime - startTime)))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(endTime))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                HStack(spacing: 18) {
                    Button {
                        if previewPlayer.isPlaying {
                            previewPlayer.pause()
                        } else {
                            previewPlayer.play(from: startTime, to: endTime)
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(themeManager.accentColor)
                                .frame(width: 64, height: 64)
                            Image(systemName: previewPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isTrimming || !FileManager.default.fileExists(atPath: recording.fileURL.path) || !canApply)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trim")
                            .font(.headline)
                        Text("Drag the handles to keep a section.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        previewPlayer.pause()
                        startTime = 0
                        endTime = effectiveDuration
                        previewPlayer.seek(to: 0)
                    } label: {
                        Text("Reset")
                    }
                    .disabled(isTrimming)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("Trim Recording")
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isTrimming)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await applyTrim() }
                    } label: {
                        if isTrimming {
                            ProgressView()
                        } else {
                            Text("Trim")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isTrimming || !canApply)
                }
            }
            .onAppear {
                previewPlayer.load(url: recording.fileURL)
                startTime = 0
                endTime = effectiveDuration
                Task { await loadWaveform() }
            }
            .onDisappear {
                previewPlayer.stop()
            }
            .alert("Unable to Trim", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
    }

    private var canApply: Bool {
        FileManager.default.fileExists(atPath: recording.fileURL.path) && (endTime - startTime) >= 0.1
    }

    private var effectiveDuration: TimeInterval {
        let d = previewPlayer.duration > 0 ? previewPlayer.duration : recording.duration
        return max(0, d)
    }

    private func loadWaveform() async {
        guard FileManager.default.fileExists(atPath: recording.fileURL.path) else {
            isLoadingWaveform = false
            waveformBars = []
            return
        }
        isLoadingWaveform = true
        do {
            let bars = try await WaveformExtractor.extractBars(from: recording.fileURL, bars: 260)
            waveformBars = bars
        } catch {
            #if DEBUG
            print("Failed to load waveform: \(error)")
            #endif
            waveformBars = []
        }
        isLoadingWaveform = false
    }

    private func applyTrim() async {
        guard canApply else { return }
        isTrimming = true
        previewPlayer.pause()

        do {
            let result = try await RecordingTrimmer.trimNonDestructive(
                recordingURL: recording.fileURL,
                startTime: startTime,
                endTime: endTime
            )
            
            if FileManager.default.fileExists(atPath: recording.fileURL.path) {
                try FileManager.default.removeItem(at: recording.fileURL)
            }
            try FileManager.default.moveItem(at: result.trimmedURL, to: recording.fileURL)

            var updated = recording
            updated.duration = max(0, endTime - startTime)
            updated.originalFileName = result.backupURL.lastPathComponent
            updated.originalDuration = result.originalDuration
            onApply(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        isTrimming = false
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let t = max(0, time)
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct TrimWaveformView: View {
    let bars: [Float]
    let duration: TimeInterval
    let currentTime: TimeInterval
    @Binding var selectionStart: TimeInterval
    @Binding var selectionEnd: TimeInterval
    let accentColor: Color
    let onSeek: (TimeInterval) -> Void

    private let minSelection: TimeInterval = 0.1
    private let handleGrabWidth: CGFloat = 34
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 2

    private enum DragMode {
        case startHandle
        case endHandle
        case selection
        case seek
    }

    @State private var dragMode: DragMode?
    @State private var dragStartX: CGFloat = 0
    @State private var dragInitialSelectionStart: TimeInterval = 0
    @State private var dragInitialSelectionEnd: TimeInterval = 0

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let startX = x(for: selectionStart, width: w)
            let endX = x(for: selectionEnd, width: w)

            ZStack {
                Canvas { context, canvasSize in
                    WaveformDrawing.drawTimedBars(
                        in: context,
                        size: canvasSize,
                        bars: bars,
                        duration: duration,
                        selectionStart: selectionStart,
                        selectionEnd: selectionEnd,
                        accentColor: accentColor,
                        barWidth: barWidth
                    )
                }

                // Dim outside selection
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: max(0, startX), height: h)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: max(0, w - endX), height: h)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .allowsHitTesting(false)

                // Selection outline
                RoundedRectangle(cornerRadius: 10)
                    .stroke(accentColor, lineWidth: 2)
                    .frame(width: max(10, endX - startX), height: h)
                    .position(x: (startX + endX) / 2, y: h / 2)
                    .allowsHitTesting(false)

                // Playhead
                Rectangle()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: 2, height: h)
                    .position(x: x(for: currentTime, width: w), y: h / 2)
                    .allowsHitTesting(false)

                // Handles
                handle(x: startX, height: h)
                    .allowsHitTesting(false)

                handle(x: endX, height: h)
                    .allowsHitTesting(false)

            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragMode == nil {
                            let x = max(0, min(w, value.startLocation.x))
                            dragStartX = x
                            dragInitialSelectionStart = selectionStart
                            dragInitialSelectionEnd = selectionEnd

                            let dStart = abs(x - startX)
                            let dEnd = abs(x - endX)

                            if dStart <= handleGrabWidth || dEnd <= handleGrabWidth {
                                dragMode = (dStart <= dEnd) ? .startHandle : .endHandle
                            } else if x >= startX && x <= endX {
                                dragMode = .selection
                            } else {
                                dragMode = .seek
                            }
                        }

                        let x = max(0, min(w, value.location.x))
                        let t = time(for: x, width: w)

                        switch dragMode {
                        case .startHandle:
                            selectionStart = max(0, min(t, selectionEnd - minSelection))
                            if currentTime < selectionStart || currentTime > selectionEnd {
                                onSeek(selectionStart)
                            }
                        case .endHandle:
                            selectionEnd = min(duration, max(t, selectionStart + minSelection))
                            if currentTime < selectionStart || currentTime > selectionEnd {
                                onSeek(selectionStart)
                            }
                        case .selection:
                            let selectionLen = max(minSelection, dragInitialSelectionEnd - dragInitialSelectionStart)
                            let deltaT = time(for: x, width: w) - time(for: dragStartX, width: w)
                            let newStart = max(0, min(dragInitialSelectionStart + deltaT, max(0, duration - selectionLen)))
                            selectionStart = newStart
                            selectionEnd = newStart + selectionLen
                            if currentTime < selectionStart || currentTime > selectionEnd {
                                onSeek(selectionStart)
                            }
                        case .seek:
                            onSeek(t)
                        case nil:
                            break
                        }
                    }
                    .onEnded { _ in
                        dragMode = nil
                    }
            )
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: duration) { _, _ in
            clampSelection()
        }
        .onAppear {
            clampSelection()
        }
    }

    private func clampSelection() {
        guard duration > 0 else { return }
        selectionStart = max(0, min(selectionStart, duration))
        selectionEnd = max(0, min(selectionEnd, duration))
        if selectionEnd < selectionStart + minSelection {
            selectionEnd = min(duration, selectionStart + minSelection)
        }
    }

    private func timeForBar(at index: Int) -> TimeInterval {
        guard bars.count > 0, duration > 0 else { return 0 }
        let progress = CGFloat(index) / CGFloat(max(1, bars.count - 1))
        return TimeInterval(progress) * duration
    }

    private func ampHeight(_ amp: Float, height: CGFloat) -> CGFloat {
        let minH: CGFloat = 6
        let maxH: CGFloat = height - 10
        return minH + CGFloat(max(0, min(1, amp))) * max(0, maxH - minH)
    }

    private func x(for time: TimeInterval, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let p = CGFloat(max(0, min(1, time / duration)))
        return p * width
    }

    private func time(for x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0, duration > 0 else { return 0 }
        let p = max(0, min(1, x / width))
        return TimeInterval(p) * duration
    }

    private func handle(x: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(.systemBackground))
                .frame(width: 22, height: height)
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)

            VStack(spacing: 3) {
                Capsule().fill(Color.secondary.opacity(0.6)).frame(width: 4, height: 18)
            }
        }
        .position(x: x, y: height / 2)
        .contentShape(Rectangle().inset(by: -10))
    }
}

