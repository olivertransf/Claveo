//
//  AppStartupCoordinator.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

/// Warms iCloud and refreshes cached data without blocking the first frame.
enum AppStartupCoordinator {
    private static var hasRun = false

    @MainActor
    static func run() async {
        guard !hasRun else { return }
        hasRun = true

        iCloudManager.shared.warmUp()

        async let recordings = AudioRecorder.shared.reloadRecordingsFromDisk()
        async let practice = PracticeService.shared.performInitialCloudSync()
        _ = await (recordings, practice)

        Task.detached(priority: .utility) {
            await MainActor.run {
                _ = FontHelper.shared
            }
        }
    }
}
