import XCTest
@testable import ShiftPro

final class ShiftTests: XCTestCase {

    // MARK: - Initialization Tests

    func testShiftInitialization_DefaultValues() {
        let start = Date()
        let end = start.addingTimeInterval(8 * 60 * 60)
        let shift = Shift(scheduledStart: start, scheduledEnd: end)

        XCTAssertEqual(shift.breakMinutes, 30)
        XCTAssertEqual(shift.status, .scheduled)
        XCTAssertEqual(shift.rateMultiplier, 1.0)
        XCTAssertFalse(shift.isAdditionalShift)
        XCTAssertNil(shift.actualStart)
        XCTAssertNil(shift.actualEnd)
        XCTAssertNil(shift.pattern)
    }

    func testShiftInitialization_CustomValues() {
        let start = Date()
        let end = start.addingTimeInterval(6 * 60 * 60)
        let shift = Shift(
            scheduledStart: start,
            scheduledEnd: end,
            breakMinutes: 45,
            isAdditionalShift: true,
            notes: "Test note",
            status: .completed,
            rateMultiplier: 1.5,
            rateLabel: "Overtime"
        )

        XCTAssertEqual(shift.breakMinutes, 45)
        XCTAssertTrue(shift.isAdditionalShift)
        XCTAssertEqual(shift.notes, "Test note")
        XCTAssertEqual(shift.status, .completed)
        XCTAssertEqual(shift.rateMultiplier, 1.5)
        XCTAssertEqual(shift.rateLabel, "Overtime")
    }

    // MARK: - Duration Calculations

    func testScheduledDurationMinutes_8HourShift() {
        let start = Date()
        let end = start.addingTimeInterval(8 * 60 * 60)
        let shift = Shift(scheduledStart: start, scheduledEnd: end)

        XCTAssertEqual(shift.scheduledDurationMinutes, 480)
    }

    func testScheduledDurationMinutes_12HourShift() {
        let start = Date()
        let end = start.addingTimeInterval(12 * 60 * 60)
        let shift = Shift(scheduledStart: start, scheduledEnd: end)

        XCTAssertEqual(shift.scheduledDurationMinutes, 720)
    }

    func testActualDurationMinutes_WhenClockInOut() {
        let start = Date()
        let end = start.addingTimeInterval(8 * 60 * 60)
        let shift = Shift(scheduledStart: start, scheduledEnd: end)

        // Clock in 10 minutes late
        let actualStart = start.addingTimeInterval(10 * 60)
        // Clock out 20 minutes early
        let actualEnd = end.addingTimeInterval(-20 * 60)

        shift.actualStart = actualStart
        shift.actualEnd = actualEnd

        // 8 hours - 10 min - 20 min = 450 min
        XCTAssertEqual(shift.actualDurationMinutes, 450)
    }

    func testEffectiveDurationMinutes_UsesActualWhenAvailable() {
        let start = Date()
        let end = start.addingTimeInterval(8 * 60 * 60)
        let shift = Shift(scheduledStart: start, scheduledEnd: end)

        XCTAssertEqual(shift.effectiveDurationMinutes, 480) // Scheduled

        shift.actualStart = start
        shift.actualEnd = start.addingTimeInterval(7 * 60 * 60)

        XCTAssertEqual(shift.effectiveDurationMinutes, 420) // Actual
    }

    // MARK: - Duration Formatting

    func testDurationFormatted_WholeHours() {
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17)
        )

        XCTAssertEqual(shift.durationFormatted, "8h")
    }

    func testDurationFormatted_HoursAndMinutes() {
        let start = Date()
        let end = start.addingTimeInterval(8.5 * 60 * 60) // 8h 30m
        let shift = Shift(scheduledStart: start, scheduledEnd: end)

        XCTAssertEqual(shift.durationFormatted, "8h 30m")
    }

    // MARK: - Rate Properties

    func testRateDisplayLabel_WithCustomLabel() {
        let shift = TestDataBuilder.shift(rateMultiplier: 1.5, rateLabel: "Bank Holiday")

        XCTAssertEqual(shift.rateDisplayLabel, "Bank Holiday")
    }

    func testRateDisplayLabel_WithoutLabel_ShowsMultiplier() {
        let shift = TestDataBuilder.shift(rateMultiplier: 1.5, rateLabel: nil)

        XCTAssertEqual(shift.rateDisplayLabel, "1.5x")
    }

    func testHasPremiumPay_RegularRate() {
        let shift = TestDataBuilder.shift(rateMultiplier: 1.0)

        XCTAssertFalse(shift.hasPremiumPay)
    }

    func testHasPremiumPay_OvertimeRate() {
        let shift = TestDataBuilder.shift(rateMultiplier: 1.5)

        XCTAssertTrue(shift.hasPremiumPay)
    }

    func testHasPremiumPay_DoubleTimeRate() {
        let shift = TestDataBuilder.shift(rateMultiplier: 2.0)

        XCTAssertTrue(shift.hasPremiumPay)
    }

    func testRateMultiplierFormatted() {
        let shift = TestDataBuilder.shift(rateMultiplier: 1.5)

        XCTAssertEqual(shift.rateMultiplierFormatted, "1.5x")
    }

    // MARK: - Status Tests

    func testStatusTransitions() {
        let shift = TestDataBuilder.shift(status: .scheduled)

        XCTAssertEqual(shift.status, .scheduled)
        XCTAssertFalse(shift.isInProgress)
        XCTAssertFalse(shift.isCompleted)

        shift.status = .inProgress
        XCTAssertTrue(shift.isInProgress)

        shift.status = .completed
        XCTAssertTrue(shift.isCompleted)
    }

    // MARK: - Clock In/Out

    func testClockIn_SetsActualStartAndStatus() {
        let shift = TestDataBuilder.shift(status: .scheduled)
        let clockInTime = Date()

        shift.clockIn(at: clockInTime)

        XCTAssertEqual(shift.actualStart, clockInTime)
        XCTAssertEqual(shift.status, .inProgress)
    }

    func testClockOut_SetsActualEndAndStatus() {
        let start = Date()
        let shift = TestDataBuilder.shift(
            scheduledStart: start,
            scheduledEnd: start.addingTimeInterval(8 * 60 * 60),
            status: .inProgress
        )
        shift.actualStart = start
        let clockOutTime = start.addingTimeInterval(8 * 60 * 60)

        shift.clockOut(at: clockOutTime)

        XCTAssertEqual(shift.actualEnd, clockOutTime)
        XCTAssertEqual(shift.status, .completed)
        XCTAssertGreaterThan(shift.paidMinutes, 0)
    }

    // MARK: - Paid Minutes Calculation

    func testRecalculatePaidMinutes_DeductsBreak() {
        let start = Date()
        let shift = Shift(
            scheduledStart: start,
            scheduledEnd: start.addingTimeInterval(8 * 60 * 60),
            breakMinutes: 30
        )

        shift.recalculatePaidMinutes()

        XCTAssertEqual(shift.paidMinutes, 450) // 480 - 30
    }

    func testRecalculatePaidMinutes_NoBreak() {
        let start = Date()
        let shift = Shift(
            scheduledStart: start,
            scheduledEnd: start.addingTimeInterval(8 * 60 * 60),
            breakMinutes: 0
        )

        shift.recalculatePaidMinutes()

        XCTAssertEqual(shift.paidMinutes, 480)
    }

    func testPaidHours_ConvertedCorrectly() {
        let shift = TestDataBuilder.completedShift(
            durationHours: 8,
            breakMinutes: 30
        )

        XCTAssertEqual(shift.paidHours, 7.5, accuracy: 0.01)
    }

    // MARK: - Soft Delete

    func testSoftDelete_SetsDeletedAt() {
        let shift = TestDataBuilder.shift()

        XCTAssertFalse(shift.isDeleted)

        shift.softDelete()

        XCTAssertTrue(shift.isDeleted)
        XCTAssertNotNil(shift.deletedAt)
    }

    func testRestore_ClearsDeletedAt() {
        let shift = TestDataBuilder.shift()
        shift.softDelete()

        XCTAssertTrue(shift.isDeleted)

        shift.restore()

        XCTAssertFalse(shift.isDeleted)
        XCTAssertNil(shift.deletedAt)
    }

    // MARK: - Temporal Properties

    func testIsFuture_FutureShift() {
        let futureStart = Date().addingTimeInterval(24 * 60 * 60) // Tomorrow
        let shift = TestDataBuilder.shift(
            scheduledStart: futureStart,
            scheduledEnd: futureStart.addingTimeInterval(8 * 60 * 60)
        )

        XCTAssertTrue(shift.isFuture)
    }

    func testIsPast_PastShift() {
        let pastStart = Date().addingTimeInterval(-24 * 60 * 60) // Yesterday
        let shift = TestDataBuilder.shift(
            scheduledStart: pastStart,
            scheduledEnd: pastStart.addingTimeInterval(8 * 60 * 60)
        )

        XCTAssertTrue(shift.isPast)
    }

    // MARK: - Display Code Tests

    func testDisplayCode_NoPattern_ReturnsW() {
        let shift = TestDataBuilder.shift(pattern: nil)

        XCTAssertEqual(shift.displayCode, "W")
    }

    func testDisplayCode_WithPatternShortCode() {
        let pattern = TestDataBuilder.shiftPattern(name: "Day Shift")
        let shift = TestDataBuilder.shift(pattern: pattern)

        // Pattern's shortCode should be used
        XCTAssertNotNil(shift.displayCode)
    }

    // MARK: - Set Rate Tests

    func testSetRate_WithMultiplierAndLabel() {
        let shift = TestDataBuilder.shift(rateMultiplier: 1.0)

        shift.setRate(multiplier: 2.0, label: "Bank Holiday")

        XCTAssertEqual(shift.rateMultiplier, 2.0)
        XCTAssertEqual(shift.rateLabel, "Bank Holiday")
    }

    func testSetRate_WithRateMultiplierEnum() {
        let shift = TestDataBuilder.shift(rateMultiplier: 1.0)

        shift.setRate(.extra)

        XCTAssertEqual(shift.rateMultiplier, 1.5)
        XCTAssertNotNil(shift.rateLabel)
    }

    // MARK: - Factory Methods

    func testQuickShift_CreatesAdditionalShift() {
        let start = Date()
        let shift = Shift.quickShift(start: start, durationHours: 4, breakMinutes: 15)

        XCTAssertTrue(shift.isAdditionalShift)
        XCTAssertEqual(shift.breakMinutes, 15)
        XCTAssertEqual(shift.scheduledDurationMinutes, 240) // 4 hours
        XCTAssertGreaterThan(shift.paidMinutes, 0)
    }

    // MARK: - Time Formatting

    func testTimeRangeFormatted() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        let start = calendar.date(from: components)!

        components.hour = 17
        let end = calendar.date(from: components)!

        let shift = Shift(scheduledStart: start, scheduledEnd: end)

        XCTAssertEqual(shift.timeRangeFormatted, "09:00 - 17:00")
    }

    // MARK: - Cancel

    func testCancel_SetsCancelledStatus() {
        let shift = TestDataBuilder.shift(status: .scheduled)

        shift.cancel()

        XCTAssertEqual(shift.status, .cancelled)
    }

    // MARK: - Effective Start/End

    func testEffectiveStart_UsesScheduledWhenNoActual() {
        let start = Date()
        let shift = Shift(
            scheduledStart: start,
            scheduledEnd: start.addingTimeInterval(8 * 60 * 60)
        )

        XCTAssertEqual(shift.effectiveStart, start)
    }

    func testEffectiveStart_UsesActualWhenSet() {
        let start = Date()
        let actualStart = start.addingTimeInterval(15 * 60) // 15 min late
        let shift = Shift(
            scheduledStart: start,
            scheduledEnd: start.addingTimeInterval(8 * 60 * 60),
            actualStart: actualStart
        )

        XCTAssertEqual(shift.effectiveStart, actualStart)
    }

    func testEffectiveEnd_UsesScheduledWhenNoActual() {
        let start = Date()
        let end = start.addingTimeInterval(8 * 60 * 60)
        let shift = Shift(scheduledStart: start, scheduledEnd: end)

        XCTAssertEqual(shift.effectiveEnd, end)
    }

    func testEffectiveEnd_UsesActualWhenSet() {
        let start = Date()
        let end = start.addingTimeInterval(8 * 60 * 60)
        let actualEnd = end.addingTimeInterval(-30 * 60) // 30 min early
        let shift = Shift(
            scheduledStart: start,
            scheduledEnd: end,
            actualEnd: actualEnd
        )

        XCTAssertEqual(shift.effectiveEnd, actualEnd)
    }
}
