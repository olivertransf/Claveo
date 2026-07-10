//
//  PracticeReminderNotificationService.swift
//  Claveo
//
//  Copyright (c) 2025 Oliver Tran

import Foundation
import UserNotifications

@MainActor
enum PracticeReminderNotificationService {
    static let notificationID = "practice-daily-reminder"

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func sync(with settings: AppSettings) async {
        if settings.practiceReminderEnabled {
            await schedule(settings: settings)
        } else {
            await cancel()
        }
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    private static func schedule(settings: AppSettings) async {
        guard await requestAuthorization() else { return }

        var components = DateComponents()
        components.hour = settings.practiceReminderHour
        components.minute = settings.practiceReminderMinute

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time to practice")
        content.body = String(localized: "Log a session in Claveo and keep your momentum going.")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        try? await center.add(request)
    }

    private static func cancel() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}
