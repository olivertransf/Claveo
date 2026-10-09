import Combine
import Foundation

enum SyncStatus: Equatable {
    case upToDate
    case syncing(pending: Int)
    case offline
    case error(String)

    var systemImage: String {
        switch self {
        case .upToDate:
            return "icloud"
        case .syncing:
            return "icloud.and.arrow.up"
        case .offline:
            return "icloud.slash"
        case .error:
            return "exclamationmark.icloud"
        }
    }

    var title: String {
        switch self {
        case .upToDate:
            return String(localized: "Up to Date")
        case .syncing(let pending):
            return String(localized: "Syncing \(pending)")
        case .offline:
            return String(localized: "Offline")
        case .error:
            return String(localized: "Sync Needs Attention")
        }
    }
}

@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published private(set) var status: SyncStatus = .upToDate
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var pendingCount = 0

    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var retryAttempt = 0
    private var retryTask: Task<Void, Never>?
    private var reloadTask: Task<Void, Never>?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSUbiquityIdentityDidChange,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    await SyncEngine.shared.handleIdentityChange()
                }
            }
        )
        restartQuery()
    }

    func retry() {
        retryAttempt = 0
        status = .syncing(pending: pendingCount)
        restartQuery()
        scheduleReload()
    }

    private func handleIdentityChange() async {
        iCloudManager.shared.warmUp()
        await iCloudManager.shared.warmUpIfNeeded()
        restartQuery()
        await AudioRecorder.shared.reloadRecordingsFromDisk(force: true)
        await PracticeService.shared.refreshFromiCloud()
    }

    private func restartQuery() {
        if let query {
            query.stop()
        }
        self.query = nil

        guard FileManager.default.ubiquityIdentityToken != nil,
              !SettingsManager.shared.settings.storeFilesOnDeviceOnly else {
            status = SettingsManager.shared.settings.storeFilesOnDeviceOnly ? .upToDate : .offline
            pendingCount = 0
            return
        }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K ENDSWITH '.json' OR %K ENDSWITH '.m4a' OR %K ENDSWITH '.wav'",
                                      NSMetadataItemFSNameKey,
                                      NSMetadataItemFSNameKey,
                                      NSMetadataItemFSNameKey)
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidUpdate,
                object: query,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    SyncEngine.shared.consumeQueryResults()
                }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    SyncEngine.shared.consumeQueryResults()
                }
            }
        )
        guard query.start() else {
            status = .error(String(localized: "iCloud could not be checked."))
            scheduleRetry()
            return
        }
        self.query = query
        retryAttempt = 0
    }

    private func consumeQueryResults() {
        guard let query else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }

        var pending = 0
        var byFileName: [String: Double] = [:]
        for case let item as NSMetadataItem in query.results {
            let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? ""
            let downloaded = item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double ?? 100
            let uploaded = item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double ?? 100
            if downloaded < 100 || uploaded < 100 {
                pending += 1
            }
            if downloaded < 100 {
                byFileName[name] = downloaded / 100
            }
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
            if downloaded < 100 {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
            if url.pathExtension.lowercased() == "json" {
                LibraryFiles.resolveConflicts(at: url)
            }
        }

        pendingCount = pending
        status = pending > 0 ? .syncing(pending: pending) : .upToDate
        if pending == 0 {
            lastSyncedAt = Date()
        }
        AudioRecorder.shared.applyDownloadProgress(byFileName)
        if pending > 0 {
            scheduleReload()
        }
    }

    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await AudioRecorder.shared.reloadRecordingsFromDisk(force: true)
        }
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        let attempt = retryAttempt
        retryAttempt += 1
        let delay = UInt64(min(30, pow(2, Double(attempt)))) * 1_000_000_000
        retryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self.restartQuery()
        }
    }
}
