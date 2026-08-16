import Foundation
import XCTest
@testable import Claveo

final class PracticeStatsTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testDayIndexGroupsEntriesByStartOfDay() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let laterSameDay = day.addingTimeInterval(3_600)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let entries = [
            PracticeEntry(date: day, duration: 10),
            PracticeEntry(date: laterSameDay, duration: 15),
            PracticeEntry(date: nextDay, duration: 20)
        ]

        let index = PracticeService.dayIndex(from: entries, calendar: calendar)

        XCTAssertEqual(index.count, 2)
        XCTAssertEqual(index[calendar.startOfDay(for: day)]?.count, 2)
        XCTAssertEqual(index[calendar.startOfDay(for: nextDay)]?.first?.duration, 20)
    }

    func testCurrentStreakUsesYesterdayWhenTodayIsEmpty() {
        let today = Date(timeIntervalSince1970: 1_720_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let entries = [
            PracticeEntry(date: yesterday, duration: 20),
            PracticeEntry(date: twoDaysAgo, duration: 30)
        ]
        let index = PracticeService.dayIndex(from: entries, calendar: calendar)

        XCTAssertEqual(
            PracticeService.currentStreak(dayIndex: index, now: today, calendar: calendar),
            2
        )
    }

    func testCurrentStreakBreaksOnAMissingDay() {
        let today = Date(timeIntervalSince1970: 1_720_000_000)
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let entries = [
            PracticeEntry(date: today, duration: 10),
            PracticeEntry(date: twoDaysAgo, duration: 10)
        ]
        let index = PracticeService.dayIndex(from: entries, calendar: calendar)

        XCTAssertEqual(
            PracticeService.currentStreak(dayIndex: index, now: today, calendar: calendar),
            1
        )
    }

    func testEntriesForDateUsesDayIndex() {
        let day = Date(timeIntervalSince1970: 1_700_086_400)
        let index = PracticeService.dayIndex(
            from: [PracticeEntry(date: day, duration: 45)],
            calendar: calendar
        )

        XCTAssertEqual(
            PracticeService.entries(on: day, dayIndex: index, calendar: calendar).first?.duration,
            45
        )
        XCTAssertTrue(
            PracticeService.entries(
                on: day.addingTimeInterval(86_400),
                dayIndex: index,
                calendar: calendar
            ).isEmpty
        )
    }
}
