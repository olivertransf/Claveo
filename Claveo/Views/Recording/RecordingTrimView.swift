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
            Task { @MainActor [weak self] in
                guard let self else { return }
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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        trimHeader

                        waveformSection

                        timeSummary
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                playbackControls
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "Trim"))
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
                            Text("Save")
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
                Text(errorMessage ?? String(localized: "Something went wrong."))
            }
        }
    }

    private var trimHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recording.displayName)
                .font(.title3.weight(.semibold))
                .lineLimit(2)

            Text(String(localized: "Drag the handles to choose what to keep."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var waveformSection: some View {
        VStack(spacing: 0) {
            if !recording.isLocallyAvailable {
                Label(
                    recording.isStoredIniCloud
                        ? String(localized: "Not downloaded from iCloud")
                        : String(localized: "File not found"),
                    systemImage: recording.isStoredIniCloud ? "icloud.and.arrow.down" : "exclamationmark.triangle"
                )
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            } else if isLoadingWaveform {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(String(localized: "Loading waveform…"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
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
                .frame(height: 180)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var timeSummary: some View {
        HStack(spacing: 0) {
            trimTimeColumn(title: String(localized: "Start"), time: startTime, emphasized: false)
            Spacer(minLength: 12)
            trimTimeColumn(title: String(localized: "Selected"), time: max(0, endTime - startTime), emphasized: true)
            Spacer(minLength: 12)
            trimTimeColumn(title: String(localized: "End"), time: endTime, emphasized: false)
        }
        .padding(.horizontal, 4)
    }

    private func trimTimeColumn(title: String, time: TimeInterval, emphasized: Bool) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatTime(time))
                .font(.system(emphasized ? .body : .subheadline, design: .monospaced))
                .fontWeight(emphasized ? .semibold : .regular)
                .foregroundStyle(emphasized ? themeManager.accentColor : .primary)
        }
        .frame(maxWidth: .infinity)
    }

    private var playbackControls: some View {
        HStack(spacing: 16) {
            Button {
                HapticFeedback.lightImpact()
                previewPlayer.pause()
                startTime = 0
                endTime = effectiveDuration
                previewPlayer.seek(to: 0)
            } label: {
                Label(String(localized: "Reset"), systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isTrimming)

            Button {
                HapticFeedback.lightImpact()
                if previewPlayer.isPlaying {
                    previewPlayer.pause()
                } else {
                    previewPlayer.play(from: startTime, to: endTime)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(themeManager.accentColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: themeManager.accentColor.opacity(0.28), radius: 10, y: 4)

                    Image(systemName: previewPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .offset(x: previewPlayer.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            .disabled(isTrimming || !recording.isLocallyAvailable || !canApply)
            .accessibilityLabel(previewPlayer.isPlaying ? String(localized: "Pause preview") : String(localized: "Play selection"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .background {
            Color(.secondarySystemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Divider()
                }
        }
    }

    private var canApply: Bool {
        recording.isLocallyAvailable && (endTime - startTime) >= 0.1
    }

    private var effectiveDuration: TimeInterval {
        let d = previewPlayer.duration > 0 ? previewPlayer.duration : recording.duration
        return max(0, d)
    }

    private func loadWaveform() async {
        guard recording.isLocallyAvailable else {
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

            do {
                _ = try FileManager.default.replaceItemAt(
                    recording.fileURL,
                    withItemAt: result.trimmedURL,
                    backupItemName: nil,
                    options: []
                )
            } catch {
                try? FileManager.default.removeItem(at: result.trimmedURL)
                try? RecordingTrimmer.deleteBackup(at: result.backupURL)
                throw RecordingTrimmerError.replaceFailed
            }

            var updated = recording
            updated.duration = Self.durationFromTrimmedFile(at: recording.fileURL)
                ?? max(0, endTime - startTime)
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

    private static func durationFromTrimmedFile(at url: URL) -> TimeInterval? {
        guard FileManager.default.fileExists(atPath: url.path),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return nil
        }
        let duration = player.duration
        guard duration.isFinite, duration > 0 else { return nil }
        return duration
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
    @Environment(\.colorScheme) private var colorScheme

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
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18))
                    .frame(width: max(0, startX), height: h)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18))
                    .frame(width: max(0, w - endX), height: h)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .allowsHitTesting(false)

                // Selection fill
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accentColor.opacity(colorScheme == .dark ? 0.14 : 0.08))
                    .frame(width: max(10, endX - startX), height: h - 8)
                    .position(x: (startX + endX) / 2, y: h / 2)
                    .allowsHitTesting(false)

                // Selection outline
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accentColor, lineWidth: 2)
                    .frame(width: max(10, endX - startX), height: h - 8)
                    .position(x: (startX + endX) / 2, y: h / 2)
                    .allowsHitTesting(false)

                // Playhead
                Capsule()
                    .fill(Color.primary)
                    .frame(width: 3, height: h - 12)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
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
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .frame(width: 24, height: height - 10)
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 2)

            Capsule()
                .fill(accentColor.opacity(0.85))
                .frame(width: 4, height: 22)
        }
        .position(x: x, y: height / 2)
        .contentShape(Rectangle().inset(by: -12))
    }
}

