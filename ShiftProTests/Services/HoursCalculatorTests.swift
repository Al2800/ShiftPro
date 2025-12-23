import XCTest
@testable import ShiftPro

final class HoursCalculatorTests: XCTestCase {
    var calculator: HoursCalculator!

    override func setUp() {
        super.setUp()
        calculator = HoursCalculator()
    }

    override func tearDown() {
        calculator = nil
        super.tearDown()
    }

    // MARK: - Paid Minutes Tests

    func testPaidMinutes_StandardShift_DeductsBreak() {
        // 8-hour shift with 30-minute break = 450 paid minutes
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17),
            breakMinutes: 30
        )

        let result = calculator.paidMinutes(for: shift)

        XCTAssertEqual(result, 450) // 480 - 30
    }

    func testPaidMinutes_NoBreak_FullDuration() {
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17),
            breakMinutes: 0
        )

        let result = calculator.paidMinutes(for: shift)

        XCTAssertEqual(result, 480) // 8 hours
    }

    func testPaidMinutes_BreakExceedsDuration_ReturnsZero() {
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 10), // 1 hour
            breakMinutes: 90 // 1.5 hours
        )

        let result = calculator.paidMinutes(for: shift)

        XCTAssertEqual(result, 0) // Cannot be negative
    }

    // MARK: - Premium Minutes Tests

    func testPremiumMinutes_RegularRate_ReturnsZero() {
        let shift = TestDataBuilder.shift(rateMultiplier: 1.0)

        let result = calculator.premiumMinutes(for: shift)

        XCTAssertEqual(result, 0)
    }

    func testPremiumMinutes_OvertimeRate_ReturnsAllPaidMinutes() {
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17),
            breakMinutes: 30,
            rateMultiplier: 1.5
        )

        let result = calculator.premiumMinutes(for: shift)

        XCTAssertEqual(result, 450) // All paid minutes are premium
    }

    // MARK: - Estimated Pay Tests

    func testEstimatedPayCents_RegularRate() {
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17),
            breakMinutes: 30,
            rateMultiplier: 1.0
        )
        let baseRateCents: Int64 = 2000 // $20/hour

        let result = calculator.estimatedPayCents(for: shift, baseRateCents: baseRateCents)

        // 7.5 hours * $20 = $150 = 15000 cents
        XCTAssertEqual(result, 15000)
    }

    func testEstimatedPayCents_DoubleTimeRate() {
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17),
            breakMinutes: 30,
            rateMultiplier: 2.0
        )
        let baseRateCents: Int64 = 2000 // $20/hour

        let result = calculator.estimatedPayCents(for: shift, baseRateCents: baseRateCents)

        // 7.5 hours * $20 * 2.0 = $300 = 30000 cents
        XCTAssertEqual(result, 30000)
    }

    // MARK: - Period Summary Tests

    func testCalculateSummary_MultipleShifts() {
        let shifts = [
            TestDataBuilder.completedShift(
                scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
                durationHours: 8,
                breakMinutes: 30,
                rateMultiplier: 1.0
            ),
            TestDataBuilder.completedShift(
                scheduledStart: TestDataBuilder.past(days: 2, hour: 9),
                durationHours: 8,
                breakMinutes: 30,
                rateMultiplier: 1.5
            )
        ]

        let summary = calculator.calculateSummary(for: shifts)

        XCTAssertEqual(summary.totalPaidMinutes, 900) // 450 + 450
        XCTAssertEqual(summary.regularMinutes, 450)
        XCTAssertEqual(summary.premiumMinutes, 450)
    }

    func testCalculateSummary_WithBaseRate_CalculatesPay() {
        let shift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.0
        )

        let summary = calculator.calculateSummary(for: [shift], baseRateCents: 2000)

        XCTAssertNotNil(summary.estimatedPayCents)
        XCTAssertEqual(summary.estimatedPayCents, 15000)
    }

    func testCalculateSummary_EmptyShifts_ReturnsZero() {
        let summary = calculator.calculateSummary(for: [])

        XCTAssertEqual(summary.totalPaidMinutes, 0)
        XCTAssertEqual(summary.regularMinutes, 0)
        XCTAssertEqual(summary.premiumMinutes, 0)
        XCTAssertNil(summary.estimatedPayCents)
    }

    // MARK: - Time Utilities Tests

    func testMinutesBetween() {
        let start = TestDataBuilder.today(hour: 9)
        let end = TestDataBuilder.today(hour: 17)

        let result = calculator.minutesBetween(start: start, end: end)

        XCTAssertEqual(result, 480) // 8 hours
    }

    func testSpansMidnight_SameDay_ReturnsFalse() {
        let start = TestDataBuilder.today(hour: 9)
        let end = TestDataBuilder.today(hour: 17)

        let result = calculator.spansMidnight(start: start, end: end)

        XCTAssertFalse(result)
    }

    func testSpansMidnight_OvernightShift_ReturnsTrue() {
        let start = TestDataBuilder.today(hour: 22) // 10 PM today
        let end = TestDataBuilder.future(days: 1, hour: 6) // 6 AM tomorrow

        let result = calculator.spansMidnight(start: start, end: end)

        XCTAssertTrue(result)
    }

    func testSplitAcrossDays_SingleDay_ReturnsSingleEntry() {
        let start = TestDataBuilder.today(hour: 9)
        let end = TestDataBuilder.today(hour: 17)

        let result = calculator.splitAcrossDays(start: start, end: end)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].minutes, 480)
    }

    func testSplitAcrossDays_OvernightShift_ReturnsTwoEntries() {
        let start = TestDataBuilder.today(hour: 22) // 10 PM
        let end = TestDataBuilder.future(days: 1, hour: 6) // 6 AM

        let result = calculator.splitAcrossDays(start: start, end: end)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].minutes, 120) // 2 hours before midnight
        XCTAssertEqual(result[1].minutes, 360) // 6 hours after midnight
    }

    // MARK: - Rate Validation Tests

    func testIsValidRate_ValidRates() {
        XCTAssertTrue(calculator.isValidRate(1.0))
        XCTAssertTrue(calculator.isValidRate(1.5))
        XCTAssertTrue(calculator.isValidRate(2.0))
        XCTAssertTrue(calculator.isValidRate(0.5))
    }

    func testIsValidRate_InvalidRates() {
        XCTAssertFalse(calculator.isValidRate(0))
        XCTAssertFalse(calculator.isValidRate(-1.0))
        XCTAssertFalse(calculator.isValidRate(15.0))
    }

    func testRateLabel_StandardRates() {
        XCTAssertEqual(calculator.rateLabel(for: 1.0), "Regular")
        XCTAssertEqual(calculator.rateLabel(for: 1.3), "Overtime (Bracket)")
        XCTAssertEqual(calculator.rateLabel(for: 1.5), "Extra")
        XCTAssertEqual(calculator.rateLabel(for: 2.0), "Bank Holiday")
    }

    func testRateLabel_CustomRate() {
        XCTAssertEqual(calculator.rateLabel(for: 1.75), "1.8x") // Rounded to 1 decimal
    }
}
