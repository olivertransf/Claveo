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

    private let metadataMonitor = MetadataQueryMonitor()
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
        let deviceOnly = SettingsManager.shared.settings.storeFilesOnDeviceOnly
        metadataMonitor.restart(deviceOnly: deviceOnly) { snapshot in
            Task { @MainActor in
                SyncEngine.shared.apply(snapshot)
            }
        }
    }

    private func apply(_ snapshot: MetadataLibrarySnapshot) {
        switch snapshot.phase {
        case .failed:
            status = .error(String(localized: "iCloud could not be checked."))
            scheduleRetry()
            return
        case .offline:
            status = .offline
            pendingCount = 0
            return
        case .idle:
            status = .upToDate
            pendingCount = 0
            return
        case .running:
            break
        }

        retryAttempt = 0
        pendingCount = snapshot.pending
        status = snapshot.pending > 0 ? .syncing(pending: snapshot.pending) : .upToDate
        if snapshot.pending == 0 {
            lastSyncedAt = Date()
        }
        AudioRecorder.shared.applyDownloadProgress(snapshot.progressByFileName)
        if snapshot.metadataChanged {
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

nonisolated struct MetadataLibrarySnapshot: Sendable {
    enum Phase: Sendable {
        case idle
        case offline
        case failed
        case running
    }

    var phase: Phase
    var pending: Int = 0
    var progressByFileName: [String: Double] = [:]
    var metadataChanged: Bool = false
}

/// Owns the iCloud metadata query on a background queue so file coordination never runs on the main actor.
nonisolated final class MetadataQueryMonitor: @unchecked Sendable {
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "claveo.sync.metadata"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var downloadedJSONNames = Set<String>()
    private var didFinishInitialGather = false

    func restart(deviceOnly: Bool, onSnapshot: @escaping @Sendable (MetadataLibrarySnapshot) -> Void) {
        queue.addOperation { [weak self] in
            guard let self else { return }
            self.stopQuery()

            guard FileManager.default.ubiquityIdentityToken != nil else {
                onSnapshot(MetadataLibrarySnapshot(phase: deviceOnly ? .idle : .offline))
                return
            }
            if deviceOnly {
                onSnapshot(MetadataLibrarySnapshot(phase: .idle))
                return
            }

            let query = NSMetadataQuery()
            query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            query.predicate = NSPredicate(
                format: "%K ENDSWITH '.json' OR %K ENDSWITH '.m4a' OR %K ENDSWITH '.wav'",
                NSMetadataItemFSNameKey,
                NSMetadataItemFSNameKey,
                NSMetadataItemFSNameKey
            )
            self.observers.append(
                NotificationCenter.default.addObserver(
                    forName: .NSMetadataQueryDidFinishGathering,
                    object: query,
                    queue: self.queue
                ) { [weak self] _ in
                    self?.publish(query: query, initialGather: true, onSnapshot: onSnapshot)
                }
            )
            self.observers.append(
                NotificationCenter.default.addObserver(
                    forName: .NSMetadataQueryDidUpdate,
                    object: query,
                    queue: self.queue
                ) { [weak self] _ in
                    self?.publish(query: query, initialGather: false, onSnapshot: onSnapshot)
                }
            )
            guard query.start() else {
                self.stopQuery()
                onSnapshot(MetadataLibrarySnapshot(phase: .failed))
                return
            }
            self.query = query
        }
    }

    private func publish(
        query: NSMetadataQuery,
        initialGather: Bool,
        onSnapshot: @escaping @Sendable (MetadataLibrarySnapshot) -> Void
    ) {
        query.disableUpdates()
        defer { query.enableUpdates() }

        var pending = 0
        var progress: [String: Double] = [:]
        var downloadedJSON = Set<String>()

        for case let item as NSMetadataItem in query.results {
            let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? ""
            let downloaded = item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double ?? 100
            let uploaded = item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double ?? 100
            if downloaded < 100 || uploaded < 100 {
                pending += 1
            }
            if downloaded < 100 {
                progress[name] = downloaded / 100
            }
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
            guard url.pathExtension.lowercased() == "json" else { continue }

            if downloaded >= 100 {
                downloadedJSON.insert(name)
            } else {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
            let conflicted = item.value(forAttribute: NSMetadataUbiquitousItemHasUnresolvedConflictsKey) as? Bool ?? false
            if conflicted {
                LibraryFiles.resolveConflicts(at: url)
            }
        }

        let metadataChanged: Bool
        if initialGather {
            metadataChanged = true
            didFinishInitialGather = true
        } else if didFinishInitialGather {
            metadataChanged = downloadedJSON != downloadedJSONNames
        } else {
            metadataChanged = false
        }
        downloadedJSONNames = downloadedJSON
        onSnapshot(
            MetadataLibrarySnapshot(
                phase: .running,
                pending: pending,
                progressByFileName: progress,
                metadataChanged: metadataChanged
            )
        )
    }

    private func stopQuery() {
        if let query {
            query.stop()
        }
        query = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        didFinishInitialGather = false
        downloadedJSONNames.removeAll()
    }
}
