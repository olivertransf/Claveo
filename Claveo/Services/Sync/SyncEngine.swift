import Combine
import Foundation

enum SyncStatus: Equatable {
    case checking
    case updating
    case upToDate
    case syncing(pending: Int)
    case offline
    case error(String)

    var isActive: Bool {
        switch self {
        case .checking, .updating, .syncing:
            return true
        case .upToDate, .offline, .error:
            return false
        }
    }

    var systemImage: String {
        switch self {
        case .checking, .updating, .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .upToDate:
            return "icloud"
        case .offline:
            return "icloud.slash"
        case .error:
            return "exclamationmark.icloud"
        }
    }

    var title: String {
        switch self {
        case .checking:
            return String(localized: "Checking iCloud…")
        case .updating:
            return String(localized: "Updating from iCloud…")
        case .upToDate:
            return String(localized: "Up to Date")
        case .syncing(let pending):
            return String(localized: "Syncing \(pending) with iCloud…")
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
    private var checkingTask: Task<Void, Never>?
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
        if !SettingsManager.shared.settings.storeFilesOnDeviceOnly {
            beginChecking()
        }
        restartQuery()
    }

    func retry() {
        retryAttempt = 0
        if pendingCount > 0 {
            status = .syncing(pending: pendingCount)
        } else {
            beginChecking()
        }
        restartQuery()
        scheduleReload()
    }

    /// The metadata query should replace this. If it never reports, leave the banner.
    private func beginChecking() {
        status = .checking
        checkingTask?.cancel()
        checkingTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            if case .checking = self.status {
                self.status = .upToDate
            }
        }
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
        checkingTask?.cancel()
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
        if snapshot.pending > 0 {
            status = .syncing(pending: snapshot.pending)
        } else if snapshot.metadataChanged {
            status = .updating
        } else {
            status = .upToDate
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
            guard !Task.isCancelled else { return }
            if case .updating = self.status, self.pendingCount == 0 {
                self.status = .upToDate
                self.lastSyncedAt = Date()
            }
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

/// Owns the iCloud metadata query. `start()` has to run on the main thread or the gather notification never arrives.
nonisolated final class MetadataQueryMonitor: @unchecked Sendable {
    private struct ItemSnapshot: Sendable {
        var name: String
        var url: URL?
        var downloaded: Double
        var uploaded: Double
        var conflicted: Bool
    }

    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "claveo.sync.metadata"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    private let lock = NSLock()
    private var generation = 0
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var downloadedJSONNames = Set<String>()
    private var didFinishInitialGather = false

    func restart(deviceOnly: Bool, onSnapshot: @escaping @Sendable (MetadataLibrarySnapshot) -> Void) {
        if Thread.isMainThread {
            install(deviceOnly: deviceOnly, onSnapshot: onSnapshot)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.install(deviceOnly: deviceOnly, onSnapshot: onSnapshot)
            }
        }
    }

    private func install(deviceOnly: Bool, onSnapshot: @escaping @Sendable (MetadataLibrarySnapshot) -> Void) {
        let generation = bumpGeneration()
        stopQuery()

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
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { [weak self] _ in
                guard let self, let query = self.query else { return }
                self.deliver(query: query, generation: generation, initialGather: true, onSnapshot: onSnapshot)
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidUpdate,
                object: query,
                queue: .main
            ) { [weak self] _ in
                guard let self, let query = self.query else { return }
                self.deliver(query: query, generation: generation, initialGather: false, onSnapshot: onSnapshot)
            }
        )
        guard query.start() else {
            stopQuery()
            onSnapshot(MetadataLibrarySnapshot(phase: .failed))
            return
        }
        self.query = query
    }

    private func deliver(
        query: NSMetadataQuery,
        generation: Int,
        initialGather: Bool,
        onSnapshot: @escaping @Sendable (MetadataLibrarySnapshot) -> Void
    ) {
        guard isCurrent(generation) else { return }
        query.disableUpdates()
        let items = query.results.compactMap { result -> ItemSnapshot? in
            guard let item = result as? NSMetadataItem else { return nil }
            let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL
            return ItemSnapshot(
                name: item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? "",
                url: url,
                downloaded: (item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.doubleValue ?? 100,
                uploaded: (item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? NSNumber)?.doubleValue ?? 100,
                conflicted: (item.value(forAttribute: NSMetadataUbiquitousItemHasUnresolvedConflictsKey) as? NSNumber)?.boolValue ?? false
            )
        }
        query.enableUpdates()

        queue.addOperation { [weak self] in
            guard let self, self.isCurrent(generation) else { return }
            self.publish(items: items, initialGather: initialGather, onSnapshot: onSnapshot)
        }
    }

    private func publish(
        items: [ItemSnapshot],
        initialGather: Bool,
        onSnapshot: @escaping @Sendable (MetadataLibrarySnapshot) -> Void
    ) {
        var pending = 0
        var progress: [String: Double] = [:]
        var downloadedJSON = Set<String>()

        for item in items {
            if item.downloaded < 100 || item.uploaded < 100 {
                pending += 1
            }
            if item.downloaded < 100 {
                progress[item.name] = item.downloaded / 100
            }
            guard let url = item.url, url.pathExtension.lowercased() == "json" else { continue }

            if item.downloaded >= 100 {
                downloadedJSON.insert(item.name)
            } else {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
            if item.conflicted {
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

    private func bumpGeneration() -> Int {
        lock.lock()
        defer { lock.unlock() }
        generation += 1
        return generation
    }

    private func isCurrent(_ generation: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return self.generation == generation
    }
}
