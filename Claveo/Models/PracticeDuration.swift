//
//  PracticeDuration.swift
//  Claveo
//
//  Copyright (c) 2026 Oliver Tran

import Foundation

enum PracticeDuration {
    static let minimum = 5
    static let step = 5
    static let absoluteMaximum = 24 * 60
    static let defaultMaximum = 8 * 60
    static let maximumQuickOptions = 6

    static func clampMaximum(_ minutes: Int) -> Int {
        let stepped = (minutes / step) * step
        return min(max(stepped, minimum), absoluteMaximum)
    }

    static func clamp(_ minutes: Int, maximum: Int) -> Int {
        let cap = clampMaximum(maximum)
        let stepped = (minutes / step) * step
        return min(max(stepped, minimum), cap)
    }

    static func sanitizedOptions(_ values: [Int], maximum: Int) -> [Int] {
        var seen = Set<Int>()
        let cleaned = values.compactMap { value -> Int? in
            let clamped = clamp(value, maximum: maximum)
            guard seen.insert(clamped).inserted else { return nil }
            return clamped
        }.sorted()
        if cleaned.isEmpty {
            return [15, 30, 45, 60].map { clamp($0, maximum: maximum) }
        }
        return Array(cleaned.prefix(maximumQuickOptions))
    }

    static func label(minutes: Int) -> String {
        if minutes < 60 {
            return String(localized: "\(minutes) min")
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return String(localized: "\(hours) hr")
        }
        return String(localized: "\(hours) hr \(remainder) min")
    }
}
