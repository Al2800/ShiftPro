import XCTest
@testable import ShiftPro

final class HoursCalculatorTests: XCTestCase {
    private var calculator: HoursCalculator!

    override func setUp() {
        super.setUp()
        calculator = HoursCalculator()
    }

    override func tearDown() {
        calculator = nil
        super.tearDown()
    }

    // MARK: - updateCalculatedFields Tests

    func testUpdateCalculatedFields_StandardShift_DeductsBreak() {
        // 8-hour shift with 30-minute break = 450 paid minutes
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17),
            breakMinutes: 30,
            rateMultiplier: 1.0
        )

        calculator.updateCalculatedFields(for: shift)

        XCTAssertEqual(shift.paidMinutes, 450) // 480 - 30
        XCTAssertEqual(shift.premiumMinutes, 0) // Regular rate
    }

    func testUpdateCalculatedFields_NoBreak_FullDuration() {
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17),
            breakMinutes: 0,
            rateMultiplier: 1.0
        )

        calculator.updateCalculatedFields(for: shift)

        XCTAssertEqual(shift.paidMinutes, 480) // 8 hours, no break
    }

    func testUpdateCalculatedFields_OvertimeRate_SetsPremiumMinutes() {
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17),
            breakMinutes: 30,
            rateMultiplier: 1.5
        )

        calculator.updateCalculatedFields(for: shift)

        XCTAssertEqual(shift.paidMinutes, 450)
        XCTAssertEqual(shift.premiumMinutes, 450) // All paid time is premium
    }

    func testUpdateCalculatedFields_DoubleTime_SetsPremiumMinutes() {
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17),
            breakMinutes: 30,
            rateMultiplier: 2.0
        )

        calculator.updateCalculatedFields(for: shift)

        XCTAssertEqual(shift.paidMinutes, 450)
        XCTAssertEqual(shift.premiumMinutes, 450) // Double time is premium
    }

    func testUpdateCalculatedFields_NegativeBreak_TreatedAsZero() {
        let shift = TestDataBuilder.shift(
            scheduledStart: TestDataBuilder.today(hour: 9),
            scheduledEnd: TestDataBuilder.today(hour: 17),
            breakMinutes: -30, // Invalid negative break
            rateMultiplier: 1.0
        )

        calculator.updateCalculatedFields(for: shift)

        XCTAssertEqual(shift.paidMinutes, 480) // Negative break treated as 0
    }

    // MARK: - calculateSummary Tests

    func testCalculateSummary_SingleRegularShift() {
        let shift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.0
        )

        let summary = calculator.calculateSummary(for: [shift], baseRateCents: nil)

        XCTAssertEqual(summary.totalPaidMinutes, 450)
        XCTAssertEqual(summary.regularMinutes, 450)
        XCTAssertEqual(summary.premiumMinutes, 0)
        XCTAssertNil(summary.estimatedPayCents)
    }

    func testCalculateSummary_SinglePremiumShift() {
        let shift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.5
        )

        let summary = calculator.calculateSummary(for: [shift], baseRateCents: nil)

        XCTAssertEqual(summary.totalPaidMinutes, 450)
        XCTAssertEqual(summary.regularMinutes, 0)
        XCTAssertEqual(summary.premiumMinutes, 450)
    }

    func testCalculateSummary_MixedShifts() {
        let regularShift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 2, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.0
        )
        let premiumShift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.5
        )

        let summary = calculator.calculateSummary(for: [regularShift, premiumShift], baseRateCents: nil)

        XCTAssertEqual(summary.totalPaidMinutes, 900) // 450 + 450
        XCTAssertEqual(summary.regularMinutes, 450)
        XCTAssertEqual(summary.premiumMinutes, 450)
    }

    func testCalculateSummary_EmptyShifts_ReturnsZero() {
        let summary = calculator.calculateSummary(for: [], baseRateCents: nil)

        XCTAssertEqual(summary.totalPaidMinutes, 0)
        XCTAssertEqual(summary.regularMinutes, 0)
        XCTAssertEqual(summary.premiumMinutes, 0)
        XCTAssertNil(summary.estimatedPayCents)
    }

    // MARK: - Pay Estimation Tests

    func testCalculateSummary_WithBaseRate_CalculatesRegularPay() {
        let shift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.0
        )
        let baseRateCents: Int64 = 2000 // $20/hour

        let summary = calculator.calculateSummary(for: [shift], baseRateCents: baseRateCents)

        // 7.5 hours * $20 = $150 = 15000 cents
        XCTAssertNotNil(summary.estimatedPayCents)
        XCTAssertEqual(summary.estimatedPayCents, 15000)
    }

    func testCalculateSummary_WithBaseRate_CalculatesOvertimePay() {
        let shift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.5
        )
        let baseRateCents: Int64 = 2000 // $20/hour

        let summary = calculator.calculateSummary(for: [shift], baseRateCents: baseRateCents)

        // 7.5 hours * $20 * 1.5 = $225 = 22500 cents
        XCTAssertNotNil(summary.estimatedPayCents)
        XCTAssertEqual(summary.estimatedPayCents, 22500)
    }

    func testCalculateSummary_WithBaseRate_CalculatesDoubleTimePay() {
        let shift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 2.0
        )
        let baseRateCents: Int64 = 2000 // $20/hour

        let summary = calculator.calculateSummary(for: [shift], baseRateCents: baseRateCents)

        // 7.5 hours * $20 * 2.0 = $300 = 30000 cents
        XCTAssertNotNil(summary.estimatedPayCents)
        XCTAssertEqual(summary.estimatedPayCents, 30000)
    }

    func testCalculateSummary_MultipleShifts_SumsPay() {
        let shift1 = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 2, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.0
        )
        let shift2 = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.5
        )
        let baseRateCents: Int64 = 2000

        let summary = calculator.calculateSummary(for: [shift1, shift2], baseRateCents: baseRateCents)

        // Shift 1: 7.5h * $20 * 1.0 = $150
        // Shift 2: 7.5h * $20 * 1.5 = $225
        // Total: $375 = 37500 cents
        XCTAssertEqual(summary.estimatedPayCents, 37500)
    }

    // MARK: - PeriodSummary Computed Properties

    func testPeriodSummary_TotalHours_ConvertsCorrectly() {
        let shift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.0
        )

        let summary = calculator.calculateSummary(for: [shift], baseRateCents: nil)

        XCTAssertEqual(summary.totalHours, 7.5, accuracy: 0.01)
        XCTAssertEqual(summary.regularHours, 7.5, accuracy: 0.01)
        XCTAssertEqual(summary.premiumHours, 0.0, accuracy: 0.01)
    }

    func testPeriodSummary_PremiumHours_ConvertsCorrectly() {
        let shift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 1.5
        )

        let summary = calculator.calculateSummary(for: [shift], baseRateCents: nil)

        XCTAssertEqual(summary.totalHours, 7.5, accuracy: 0.01)
        XCTAssertEqual(summary.regularHours, 0.0, accuracy: 0.01)
        XCTAssertEqual(summary.premiumHours, 7.5, accuracy: 0.01)
    }

    // MARK: - Edge Cases

    func testCalculateSummary_VeryShortShift() {
        let shift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 1,
            breakMinutes: 0,
            rateMultiplier: 1.0
        )

        let summary = calculator.calculateSummary(for: [shift], baseRateCents: 2000)

        XCTAssertEqual(summary.totalPaidMinutes, 60)
        XCTAssertEqual(summary.estimatedPayCents, 2000) // 1 hour * $20
    }

    func testCalculateSummary_HighRateMultiplier() {
        let shift = TestDataBuilder.completedShift(
            scheduledStart: TestDataBuilder.past(days: 1, hour: 9),
            durationHours: 8,
            breakMinutes: 30,
            rateMultiplier: 3.0 // Triple time
        )
        let baseRateCents: Int64 = 2000

        let summary = calculator.calculateSummary(for: [shift], baseRateCents: baseRateCents)

        // 7.5 hours * $20 * 3.0 = $450 = 45000 cents
        XCTAssertEqual(summary.estimatedPayCents, 45000)
    }

    func testCalculateSummary_ManyShifts() {
        var shifts: [Shift] = []
        for i in 1...10 {
            shifts.append(TestDataBuilder.completedShift(
                scheduledStart: TestDataBuilder.past(days: i, hour: 9),
                durationHours: 8,
                breakMinutes: 30,
                rateMultiplier: 1.0
            ))
        }

        let summary = calculator.calculateSummary(for: shifts, baseRateCents: 2000)

        XCTAssertEqual(summary.totalPaidMinutes, 4500) // 10 * 450
        XCTAssertEqual(summary.totalHours, 75.0, accuracy: 0.01)
        XCTAssertEqual(summary.estimatedPayCents, 150000) // $1500
    }
}
