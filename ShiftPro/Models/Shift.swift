import Foundation
import SwiftData
import SwiftUI

/// An individual shift instance representing actual work time.
/// Can be generated from a pattern or created as an ad-hoc shift.
@Model
final class Shift {
    // MARK: - Primary Key
    @Attribute(.unique) var id: UUID

    // MARK: - Scheduled Times
    var scheduledStart: Date
    var scheduledEnd: Date

    // MARK: - Actual Times (for clock in/out)
    var actualStart: Date?
    var actualEnd: Date?

    // MARK: - Break & Duration
    /// Unpaid break time in minutes
    var breakMinutes: Int

    // MARK: - Shift Classification
    /// Whether this is an additional/overtime shift
    var isAdditionalShift: Bool

    /// Optional worksite/location for the shift
    var location: String?

    /// Free-form notes
    var notes: String?

    /// Raw value for ShiftStatus enum
    var statusRaw: Int16

    // MARK: - Pay Calculation
    /// Total paid minutes (after break deduction)
    var paidMinutes: Int

    /// Minutes at premium rate
    var premiumMinutes: Int

    /// Rate multiplier (1.0, 1.3, 1.5, 2.0)
    var rateMultiplier: Double

    /// Optional label for the rate (e.g., "Bank Holiday")
    var rateLabel: String?

    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date

    /// Soft delete timestamp
    var deletedAt: Date?

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var pattern: ShiftPattern?

    @Relationship(deleteRule: .nullify)
    var owner: UserProfile?

    @Relationship(deleteRule: .nullify, inverse: \PayPeriod.shifts)
    var payPeriod: PayPeriod?

    @Relationship(deleteRule: .cascade, inverse: \CalendarEvent.shift)
    var calendarEvent: CalendarEvent?

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        scheduledStart: Date,
        scheduledEnd: Date,
        actualStart: Date? = nil,
        actualEnd: Date? = nil,
        breakMinutes: Int = 30,
        isAdditionalShift: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        status: ShiftStatus = .scheduled,
        paidMinutes: Int = 0,
        premiumMinutes: Int = 0,
        rateMultiplier: Double = 1.0,
        rateLabel: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        pattern: ShiftPattern? = nil,
        owner: UserProfile? = nil
    ) {
        self.id = id
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.actualStart = actualStart
        self.actualEnd = actualEnd
        self.breakMinutes = breakMinutes
        self.isAdditionalShift = isAdditionalShift
        self.location = location
        self.notes = notes
        self.statusRaw = status.rawValue
        self.paidMinutes = paidMinutes
        self.premiumMinutes = premiumMinutes
        self.rateMultiplier = rateMultiplier
        self.rateLabel = rateLabel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.pattern = pattern
        self.owner = owner
    }
}

// MARK: - Computed Properties
extension Shift {
    /// The shift status enum value
    var status: ShiftStatus {
        get { ShiftStatus(rawValue: statusRaw) ?? .scheduled }
        set {
            statusRaw = newValue.rawValue
            markUpdated()
        }
    }

    /// Whether this shift is deleted
    var isDeleted: Bool {
        deletedAt != nil
    }

    /// Location to display for the shift (shift-specific overrides profile)
    var locationDisplay: String? {
        if let location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return location
        }
        return owner?.workplace
    }

    /// Effective start time (actual or scheduled)
    var effectiveStart: Date {
        actualStart ?? scheduledStart
    }

    /// Effective end time (actual or scheduled)
    var effectiveEnd: Date {
        actualEnd ?? scheduledEnd
    }

    /// Scheduled duration in minutes
    var scheduledDurationMinutes: Int {
        Int(scheduledEnd.timeIntervalSince(scheduledStart) / 60)
    }

    /// Actual duration in minutes (if both actual times set)
    var actualDurationMinutes: Int? {
        guard let start = actualStart, let end = actualEnd else { return nil }
        return Int(end.timeIntervalSince(start) / 60)
    }

    /// Effective duration in minutes (actual or scheduled)
    var effectiveDurationMinutes: Int {
        actualDurationMinutes ?? scheduledDurationMinutes
    }

    /// Paid hours (after break)
    var paidHours: Double {
        Double(paidMinutes) / 60.0
    }

    /// Premium hours
    var premiumHours: Double {
        Double(premiumMinutes) / 60.0
    }

    /// Time range formatted (e.g., "09:00 - 17:00")
    var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: effectiveStart)
        let end = formatter.string(from: effectiveEnd)
        return "\(start) - \(end)"
    }

    /// Date formatted (e.g., "Mon, Dec 23")
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: scheduledStart)
    }

    /// Full display string (e.g., "Mon, Dec 23 - 09:00 to 17:00")
    var fullDisplayString: String {
        "\(dateFormatted) - \(timeRangeFormatted)"
    }

    /// Duration formatted (e.g., "8h 30m")
    var durationFormatted: String {
        let minutes = effectiveDurationMinutes
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }

    /// Rate multiplier formatted (e.g., "1.5x")
    var rateMultiplierFormatted: String {
        String(format: "%.1fx", rateMultiplier)
    }

    /// Display label for rate (label or formatted multiplier)
    var rateDisplayLabel: String {
        rateLabel ?? rateMultiplierFormatted
    }

    /// Whether this shift has premium pay
    var hasPremiumPay: Bool {
        rateMultiplier > 1.0
    }

    /// Whether the shift is currently in progress
    var isInProgress: Bool {
        status == .inProgress
    }

    /// Whether the shift is completed
    var isCompleted: Bool {
        status == .completed
    }

    /// Whether the shift is in the future
    var isFuture: Bool {
        scheduledStart > Date()
    }

    /// Whether the shift is in the past
    var isPast: Bool {
        scheduledEnd < Date()
    }

    /// Derives the short code for calendar display
    /// For cycling patterns, this looks at the rotation day's shift name
    /// Falls back to pattern's shortCode or "W" for work
    var displayCode: String {
        // For cycling patterns, try to derive from rotation day's shift name
        if let pattern = pattern,
           pattern.scheduleType == .cycling,
           let rotationDay = pattern.rotationDay(for: scheduledStart) {
            if let shiftName = rotationDay.shiftName?.lowercased() {
                // Derive code from shift name
                if shiftName.contains("early") || shiftName.contains("morning") {
                    return "E"
                } else if shiftName.contains("night") {
                    return "N"
                } else if shiftName.contains("late") || shiftName.contains("afternoon") {
                    return "L"
                } else if shiftName.contains("day") {
                    return "D"
                } else if shiftName.contains("mid") {
                    return "M"
                }
                // Use first letter of shift name as fallback
                return String(shiftName.prefix(1)).uppercased()
            }
        }
        // Fall back to pattern's shortCode or "W"
        return pattern?.shortCode ?? "W"
    }

    /// Gets the color for this shift's display code
    var displayColor: Color {
        ShiftProColors.shiftCodeColor(for: displayCode)
    }

    /// Display title for UI (prefers rotation day shift name when available).
    var displayTitle: String {
        if let pattern,
           pattern.scheduleType == .cycling,
           let rotationDay = pattern.rotationDay(for: scheduledStart),
           let shiftName = rotationDay.shiftName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !shiftName.isEmpty {
            return shiftName
        }
        return pattern?.name ?? "Shift"
    }

    /// Overtime minutes based on additional shifts, premium minutes, or extra hours beyond schedule.
    func overtimeMinutes(at date: Date = Date()) -> Int {
        let paid = paidMinutes > 0 ? paidMinutes : max(0, effectiveDurationMinutes - breakMinutes)

        switch status {
        case .inProgress:
            if isAdditionalShift || rateMultiplier > 1.0 {
                if let actualStart {
                    let elapsed = Int(date.timeIntervalSince(actualStart) / 60)
                    return max(0, elapsed - breakMinutes)
                }
                return paid
            }
            if let actualStart {
                let elapsed = Int(date.timeIntervalSince(actualStart) / 60)
                if elapsed > scheduledDurationMinutes {
                    return elapsed - scheduledDurationMinutes
                }
            }
            return 0
        case .scheduled:
            if isAdditionalShift || rateMultiplier > 1.0 {
                return paid
            }
            return 0
        case .completed:
            if premiumMinutes > 0 {
                return min(premiumMinutes, paid)
            }
            if isAdditionalShift || rateMultiplier > 1.0 {
                return paid
            }
            if let actual = actualDurationMinutes, actual > scheduledDurationMinutes {
                return actual - scheduledDurationMinutes
            }
            return 0
        case .cancelled:
            return 0
        }
    }
}

// MARK: - Convenience Methods
extension Shift {
    /// Marks the shift as updated
    func markUpdated() {
        updatedAt = Date()
    }

    /// Soft deletes this shift
    func softDelete() {
        deletedAt = Date()
        markUpdated()
    }

    /// Restores a soft-deleted shift
    func restore() {
        deletedAt = nil
        markUpdated()
    }

    /// Starts the shift (clock in)
    func clockIn(at time: Date = Date()) {
        actualStart = time
        status = .inProgress
    }

    /// Ends the shift (clock out)
    func clockOut(at time: Date = Date()) {
        actualEnd = time
        status = .completed
        recalculatePaidMinutes()
    }

    /// Cancels the shift
    func cancel() {
        status = .cancelled
    }

    /// Recalculates paid minutes based on actual/scheduled times
    func recalculatePaidMinutes() {
        let totalMinutes = effectiveDurationMinutes
        paidMinutes = max(0, totalMinutes - breakMinutes)
    }

    /// Sets the rate multiplier and optional label
    func setRate(multiplier: Double, label: String? = nil) {
        rateMultiplier = multiplier
        rateLabel = label
        markUpdated()
    }

    /// Sets the rate from a RateMultiplier enum
    func setRate(_ rate: RateMultiplier) {
        rateMultiplier = rate.rawValue
        rateLabel = rate.displayName
        markUpdated()
    }
}

// MARK: - Factory Methods
extension Shift {
    /// Creates a shift from a pattern for a specific date
    static func fromPattern(
        _ pattern: ShiftPattern,
        on date: Date,
        owner: UserProfile? = nil,
        calendar: Calendar = .current
    ) -> Shift {
        let scheduledStart = pattern.startDate(on: date, in: calendar)
        let scheduledEnd = pattern.endDate(on: date, in: calendar)

        let shift = Shift(
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            pattern: pattern,
            owner: owner
        )
        shift.recalculatePaidMinutes()
        return shift
    }

    /// Creates a quick ad-hoc shift
    static func quickShift(
        start: Date,
        durationHours: Int = 8,
        breakMinutes: Int = 30,
        owner: UserProfile? = nil
    ) -> Shift {
        let end = Calendar.current.date(byAdding: .hour, value: durationHours, to: start) ?? start

        let shift = Shift(
            scheduledStart: start,
            scheduledEnd: end,
            breakMinutes: breakMinutes,
            isAdditionalShift: true,
            owner: owner
        )
        shift.recalculatePaidMinutes()
        return shift
    }
}
