import XCTest
import HifzCore
@testable import HifzTracker

final class ProgressActivityCalculatorTests: XCTestCase {
    func testBuildsSundayFirst53WeekRangeThroughToday() throws {
        let calendar = testCalendar
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 29)))

        let days = ProgressActivityCalculator.days(records: [], through: today, calendar: calendar)

        XCTAssertEqual(days.count, 53 * 7)
        XCTAssertEqual(calendar.component(.weekday, from: try XCTUnwrap(days.first?.date)), 1)
        XCTAssertEqual(calendar.startOfDay(for: try XCTUnwrap(days[days.count - 4].date)), today)
        XCTAssertEqual(days.suffix(3).map(\.isFuture), [true, true, true])
    }

    func testCombinesPositiveConfirmedWordsByLocalStartDate() throws {
        let calendar = testCalendar
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 29)))
        let sessionDate = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 29,
            hour: 23,
            minute: 30
        )))
        let records = [
            makeRecord(startedAt: sessionDate, completedWordCount: 10),
            makeRecord(startedAt: sessionDate, completedWordCount: 20),
            makeRecord(startedAt: sessionDate, completedWordCount: 0)
        ]

        let days = ProgressActivityCalculator.days(records: records, through: today, calendar: calendar)
        let activity = try XCTUnwrap(days.first { calendar.isDate($0.date, inSameDayAs: today) })

        XCTAssertEqual(activity.wordCount, 30)
        XCTAssertEqual(activity.level, .medium)
    }

    func testUsesFixedWordCountLevels() {
        XCTAssertEqual(ProgressActivityLevel(wordCount: 0), .none)
        XCTAssertEqual(ProgressActivityLevel(wordCount: 1), .light)
        XCTAssertEqual(ProgressActivityLevel(wordCount: 25), .light)
        XCTAssertEqual(ProgressActivityLevel(wordCount: 26), .medium)
        XCTAssertEqual(ProgressActivityLevel(wordCount: 75), .medium)
        XCTAssertEqual(ProgressActivityLevel(wordCount: 76), .dark)
        XCTAssertEqual(ProgressActivityLevel(wordCount: 150), .dark)
        XCTAssertEqual(ProgressActivityLevel(wordCount: 151), .darkest)
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeRecord(startedAt: Date, completedWordCount: Int) -> SessionRecord {
        SessionRecord(
            startedAt: startedAt,
            endedAt: startedAt,
            surah: 1,
            startAyah: 1,
            lastAyah: 1,
            lastWord: max(1, completedWordCount),
            completedWordCount: completedWordCount,
            correctionEvents: []
        )
    }
}
