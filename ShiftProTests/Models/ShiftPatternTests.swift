import XCTest
@testable import ShiftPro

final class ShiftPatternTests: XCTestCase {

    // MARK: - Time Formatting Tests

    func testStartTimeFormatted() {
        let pattern = TestDataBuilder.shiftPattern(startMinuteOfDay: 540) // 9:00

        XCTAssertEqual(pattern.startTimeFormatted, "09:00")
    }

    func testEndTimeFormatted() {
        let pattern = TestDataBuilder.shiftPattern(
            startMinuteOfDay: 540,  // 9:00
            durationMinutes: 480    // 8 hours
        )

        XCTAssertEqual(pattern.endTimeFormatted, "17:00")
    }

    func testTimeRangeFormatted() {
        let pattern = TestDataBuilder.shiftPattern(
            startMinuteOfDay: 540,
            durationMinutes: 480
        )

        XCTAssertEqual(pattern.timeRangeFormatted, "09:00 - 17:00")
    }

    // MARK: - Overnight Shift Tests

    func testIsOvernightShift_DayShift_ReturnsFalse() {
        let pattern = TestDataBuilder.shiftPattern(
            startMinuteOfDay: 540,  // 9 AM
            durationMinutes: 480    // 8 hours
        )

        XCTAssertFalse(pattern.isOvernightShift)
    }

    func testIsOvernightShift_NightShift_ReturnsTrue() {
        let pattern = TestDataBuilder.shiftPattern(
            startMinuteOfDay: 1320,  // 10 PM
            durationMinutes: 480     // 8 hours
        )

        XCTAssertTrue(pattern.isOvernightShift)
    }

    // MARK: - Duration Tests

    func testDurationHours() {
        let pattern = TestDataBuilder.shiftPattern(durationMinutes: 480)

        XCTAssertEqual(pattern.durationHours, 8.0)
    }

    func testDurationHours_HalfHour() {
        let pattern = TestDataBuilder.shiftPattern(durationMinutes: 510)

        XCTAssertEqual(pattern.durationHours, 8.5)
    }

    // MARK: - Weekly Pattern Tests

    func testWeekdays_MondayToFriday() {
        let pattern = TestDataBuilder.shiftPattern(
            scheduleType: .weekly,
            daysOfWeekMask: 0b0111110 // Mon-Fri (bits 1-5)
        )

        let weekdays = pattern.weekdays

        XCTAssertEqual(weekdays.count, 5)
        XCTAssertTrue(weekdays.contains(.monday))
        XCTAssertTrue(weekdays.contains(.friday))
        XCTAssertFalse(weekdays.contains(.saturday))
        XCTAssertFalse(weekdays.contains(.sunday))
    }

    func testIncludesWeekday() {
        let pattern = TestDataBuilder.shiftPattern(
            daysOfWeekMask: 0b0111110 // Mon-Fri
        )

        XCTAssertTrue(pattern.includesWeekday(.monday))
        XCTAssertTrue(pattern.includesWeekday(.wednesday))
        XCTAssertFalse(pattern.includesWeekday(.saturday))
    }

    func testIsScheduled_WeeklyPattern_OnWorkday() {
        let pattern = TestDataBuilder.shiftPattern(
            scheduleType: .weekly,
            daysOfWeekMask: 0b0111110 // Mon-Fri
        )

        // Find next Monday
        let calendar = Calendar.current
        var date = Date()
        while calendar.component(.weekday, from: date) != 2 { // 2 = Monday
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                XCTFail("Failed to compute next weekday for Monday lookup.")
                break
            }
            date = nextDate
        }

        XCTAssertTrue(pattern.isScheduled(on: date))
    }

    func testIsScheduled_WeeklyPattern_OnOffDay() {
        let pattern = TestDataBuilder.shiftPattern(
            scheduleType: .weekly,
            daysOfWeekMask: 0b0111110 // Mon-Fri
        )

        // Find next Saturday
        let calendar = Calendar.current
        var date = Date()
        while calendar.component(.weekday, from: date) != 7 { // 7 = Saturday
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                XCTFail("Failed to compute next weekday for Saturday lookup.")
                break
            }
            date = nextDate
        }

        XCTAssertFalse(pattern.isScheduled(on: date))
    }

    // MARK: - Soft Delete Tests

    func testSoftDelete() {
        var pattern = TestDataBuilder.shiftPattern(isActive: true)

        pattern.softDelete()

        XCTAssertTrue(pattern.isDeleted)
        XCTAssertFalse(pattern.isActive)
    }

    func testRestore() {
        var pattern = TestDataBuilder.shiftPattern()
        pattern.softDelete()

        pattern.restore()

        XCTAssertFalse(pattern.isDeleted)
    }

    // MARK: - Factory Methods Tests

    func testStandard9to5() {
        let pattern = ShiftPattern.standard9to5()

        XCTAssertEqual(pattern.name, "Standard 9-5")
        XCTAssertEqual(pattern.startMinuteOfDay, 540) // 9 AM
        XCTAssertEqual(pattern.durationMinutes, 480)  // 8 hours
        XCTAssertEqual(pattern.weekdays.count, 5)     // Mon-Fri
    }

    func testFourOnFourOff() {
        let pattern = ShiftPattern.fourOnFourOff()

        XCTAssertEqual(pattern.name, "4 On / 4 Off")
        XCTAssertEqual(pattern.scheduleType, .cycling)
        XCTAssertEqual(pattern.durationMinutes, 720) // 12 hours
    }

    // MARK: - Date Generation Tests

    func testStartDate_GeneratesCorrectTime() {
        let pattern = TestDataBuilder.shiftPattern(startMinuteOfDay: 540) // 9 AM
        let today = Calendar.current.startOfDay(for: Date())

        let startDate = pattern.startDate(on: today)

        let components = Calendar.current.dateComponents([.hour, .minute], from: startDate)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
    }

    func testEndDate_GeneratesCorrectTime() {
        let pattern = TestDataBuilder.shiftPattern(
            startMinuteOfDay: 540,
            durationMinutes: 480
        )
        let today = Calendar.current.startOfDay(for: Date())

        let endDate = pattern.endDate(on: today)

        let components = Calendar.current.dateComponents([.hour, .minute], from: endDate)
        XCTAssertEqual(components.hour, 17)
        XCTAssertEqual(components.minute, 0)
    }
}
