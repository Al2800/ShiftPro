import XCTest
@testable import ShiftPro

final class ShiftTests: XCTestCase {
    func testShiftDurationFormatting() {
        let start = Date()
        let end = start.addingTimeInterval(8 * 60 * 60)
        let shift = Shift(scheduledStart: start, scheduledEnd: end)

        XCTAssertEqual(shift.scheduledDurationMinutes, 480)
        XCTAssertEqual(shift.durationFormatted, "8h")
    }

    func testRateDisplayLabelFallback() {
        let start = Date()
        let end = start.addingTimeInterval(6 * 60 * 60)
        let shift = Shift(scheduledStart: start, scheduledEnd: end, rateMultiplier: 1.5)

        XCTAssertEqual(shift.rateDisplayLabel, "1.5x")
    }
}
