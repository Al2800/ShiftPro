import Foundation
@testable import ShiftPro

/// Factory for creating test data with sensible defaults
enum TestDataBuilder {

    // MARK: - User Profile

    static func userProfile(
        id: UUID = UUID(),
        employeeId: String? = "E1234",
        workplace: String? = "City Hospital",
        jobTitle: String? = "Nurse",
        startDate: Date = Date(),
        baseRateCents: Int64? = 3500,
        regularHoursPerPay: Int = 80,
        payPeriodType: PayPeriodType = .biweekly,
        timeZoneIdentifier: String = "Europe/London"
    ) -> UserProfile {
        UserProfile(
            id: id,
            employeeId: employeeId,
            workplace: workplace,
            jobTitle: jobTitle,
            startDate: startDate,
            baseRateCents: baseRateCents,
            regularHoursPerPay: regularHoursPerPay,
            payPeriodType: payPeriodType,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    // MARK: - Shift Pattern

    static func shiftPattern(
        id: UUID = UUID(),
        name: String = "Day Shift",
        scheduleType: ScheduleType = .weekly,
        startMinuteOfDay: Int = 540, // 9:00 AM
        durationMinutes: Int = 480,  // 8 hours
        daysOfWeekMask: Int16 = 0b0111110, // Mon-Fri
        isActive: Bool = true,
        colorHex: String = "#007AFF",
        owner: UserProfile? = nil
    ) -> ShiftPattern {
        ShiftPattern(
            id: id,
            name: name,
            scheduleType: scheduleType,
            startMinuteOfDay: startMinuteOfDay,
            durationMinutes: durationMinutes,
            daysOfWeekMask: daysOfWeekMask,
            isActive: isActive,
            colorHex: colorHex
        )
    }

    // MARK: - Shift

    static func shift(
        id: UUID = UUID(),
        scheduledStart: Date = Date(),
        scheduledEnd: Date? = nil,
        actualStart: Date? = nil,
        actualEnd: Date? = nil,
        breakMinutes: Int = 30,
        isAdditionalShift: Bool = false,
        notes: String? = nil,
        status: ShiftStatus = .scheduled,
        rateMultiplier: Double = 1.0,
        rateLabel: String? = nil,
        pattern: ShiftPattern? = nil,
        owner: UserProfile? = nil
    ) -> Shift {
        let end = scheduledEnd
            ?? Calendar.current.date(byAdding: .hour, value: 8, to: scheduledStart)
            ?? scheduledStart.addingTimeInterval(8 * 60 * 60)

        return Shift(
            id: id,
            scheduledStart: scheduledStart,
            scheduledEnd: end,
            actualStart: actualStart,
            actualEnd: actualEnd,
            breakMinutes: breakMinutes,
            isAdditionalShift: isAdditionalShift,
            notes: notes,
            status: status,
            rateMultiplier: rateMultiplier,
            rateLabel: rateLabel,
            pattern: pattern,
            owner: owner
        )
    }

    static func completedShift(
        scheduledStart: Date = Date(),
        durationHours: Int = 8,
        breakMinutes: Int = 30,
        rateMultiplier: Double = 1.0,
        owner: UserProfile? = nil
    ) -> Shift {
        let end = Calendar.current.date(byAdding: .hour, value: durationHours, to: scheduledStart)
            ?? scheduledStart.addingTimeInterval(TimeInterval(durationHours) * 60 * 60)

        return Shift(
            scheduledStart: scheduledStart,
            scheduledEnd: end,
            actualStart: scheduledStart,
            actualEnd: end,
            breakMinutes: breakMinutes,
            status: .completed,
            paidMinutes: (durationHours * 60) - breakMinutes,
            rateMultiplier: rateMultiplier,
            owner: owner
        )
    }

    // MARK: - Pay Period

    static func payPeriod(
        id: UUID = UUID(),
        startDate: Date = Date(),
        endDate: Date? = nil,
        paidMinutes: Int = 0,
        premiumMinutes: Int = 0,
        isComplete: Bool = false
    ) -> PayPeriod {
        let end = endDate
            ?? Calendar.current.date(byAdding: .day, value: 13, to: startDate)
            ?? startDate.addingTimeInterval(13 * 24 * 60 * 60)

        return PayPeriod(
            id: id,
            startDate: startDate,
            endDate: end,
            paidMinutes: paidMinutes,
            premiumMinutes: premiumMinutes,
            isComplete: isComplete
        )
    }

    // MARK: - Rotation Days

    static func fourOnFourOffRotation() -> [RotationDay] {
        var days: [RotationDay] = []
        for index in 0..<4 {
            days.append(RotationDay(index: index, isWorkDay: true))
        }
        for index in 4..<8 {
            days.append(RotationDay(index: index, isWorkDay: false))
        }
        return days
    }

    // MARK: - Date Helpers

    /// Creates a date at a specific time today
    static func today(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
            ?? calendar.startOfDay(for: Date()).addingTimeInterval(TimeInterval(hour * 60 * 60 + minute * 60))
    }

    /// Creates a date at a specific time on a future day
    static func future(days: Int, hour: Int = 9) -> Date {
        let calendar = Calendar.current
        guard let baseDate = calendar.date(byAdding: .day, value: days, to: Date()) else {
            return Date()
        }
        var date = baseDate
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components) ?? date
    }

    /// Creates a date at a specific time on a past day
    static func past(days: Int, hour: Int = 9) -> Date {
        future(days: -days, hour: hour)
    }
}
