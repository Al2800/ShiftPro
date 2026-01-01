import Foundation
import SwiftData

/// Aggregates shifts within a pay period for hours tracking and pay estimation.
@Model
final class PayPeriod {
    // MARK: - Primary Key
    @Attribute(.unique) var id: UUID

    // MARK: - Period Boundaries
    var startDate: Date
    var endDate: Date

    // MARK: - Aggregated Hours (in minutes)
    /// Total paid minutes for this period
    var paidMinutes: Int

    /// Minutes at premium rates (overtime, bank holiday, etc.)
    var premiumMinutes: Int

    /// Minutes from additional/overtime shifts
    var additionalShiftMinutes: Int

    // MARK: - Pay Estimation
    /// Estimated pay in cents (nil if base rate not configured)
    var estimatedPayCents: Int64?

    // MARK: - Status
    /// Whether this pay period is complete (end date has passed)
    var isComplete: Bool

    /// Soft delete timestamp
    var deletedAt: Date?

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var shifts: [Shift] = []

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        paidMinutes: Int = 0,
        premiumMinutes: Int = 0,
        additionalShiftMinutes: Int = 0,
        estimatedPayCents: Int64? = nil,
        isComplete: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.paidMinutes = paidMinutes
        self.premiumMinutes = premiumMinutes
        self.additionalShiftMinutes = additionalShiftMinutes
        self.estimatedPayCents = estimatedPayCents
        self.isComplete = isComplete
        self.deletedAt = deletedAt
    }
}

// MARK: - Computed Properties
extension PayPeriod {
    private var effectiveEndDate: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: endDate)
        let isMidnight = (components.hour ?? 0) == 0
            && (components.minute ?? 0) == 0
            && (components.second ?? 0) == 0
        return isMidnight ? calendar.endOfDay(for: endDate) : endDate
    }

    @discardableResult
    func normalizeEndDateIfNeeded(calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second], from: endDate)
        let isMidnight = (components.hour ?? 0) == 0
            && (components.minute ?? 0) == 0
            && (components.second ?? 0) == 0
        guard isMidnight else { return false }
        let normalized = calendar.endOfDay(for: endDate)
        guard normalized != endDate else { return false }
        endDate = normalized
        return true
    }

    /// Whether this pay period is deleted
    var isDeleted: Bool {
        deletedAt != nil
    }

    /// Total paid hours
    var paidHours: Double {
        Double(paidMinutes) / 60.0
    }

    /// Premium hours
    var premiumHours: Double {
        Double(premiumMinutes) / 60.0
    }

    /// Regular (non-premium) hours
    var regularHours: Double {
        paidHours - premiumHours
    }

    /// Additional shift hours
    var additionalShiftHours: Double {
        Double(additionalShiftMinutes) / 60.0
    }

    /// Estimated pay in dollars
    var estimatedPayDollars: Double? {
        guard let cents = estimatedPayCents else { return nil }
        return Double(cents) / 100.0
    }

    /// Formatted estimated pay (e.g., "$1,234.56")
    var estimatedPayFormatted: String? {
        guard let dollars = estimatedPayDollars else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        if let currencyCode = Locale.current.currency?.identifier {
            formatter.currencyCode = currencyCode
        }
        return formatter.string(from: NSNumber(value: dollars))
    }

    /// Period date range formatted (e.g., "Dec 1 - Dec 14")
    var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: effectiveEndDate)
        return "\(start) - \(end)"
    }

    /// Period duration in days
    var durationDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: effectiveEndDate).day ?? 0
        return days + 1 // Include both start and end dates
    }

    /// Number of shifts in this period
    var shiftCount: Int {
        activeShifts.count
    }

    /// Active (non-deleted) shifts
    var activeShifts: [Shift] {
        shifts.filter { $0.deletedAt == nil }
    }

    /// Completed shifts
    var completedShifts: [Shift] {
        activeShifts.filter { $0.isCompleted }
    }

    /// Upcoming shifts
    var upcomingShifts: [Shift] {
        activeShifts.filter { $0.isFuture }
    }

    /// Whether this is the current pay period
    var isCurrent: Bool {
        let now = Date()
        return now >= startDate && now <= effectiveEndDate
    }

    /// Whether this is a past pay period
    var isPast: Bool {
        effectiveEndDate < Date()
    }

    /// Whether this is a future pay period
    var isFuture: Bool {
        startDate > Date()
    }

    /// Progress through the period (0.0 to 1.0)
    var progress: Double {
        guard !isPast else { return 1.0 }
        guard !isFuture else { return 0.0 }

        let now = Date()
        let totalDuration = effectiveEndDate.timeIntervalSince(startDate)
        let elapsed = now.timeIntervalSince(startDate)
        return min(1.0, max(0.0, elapsed / totalDuration))
    }
}

// MARK: - Convenience Methods
extension PayPeriod {
    /// Soft deletes this pay period
    func softDelete() {
        deletedAt = Date()
    }

    /// Restores a soft-deleted pay period
    func restore() {
        deletedAt = nil
    }

    /// Recalculates aggregated hours from shifts
    func recalculateHours() {
        var totalPaid = 0
        var totalPremium = 0
        var totalAdditional = 0

        for shift in activeShifts where shift.isCompleted {
            totalPaid += shift.paidMinutes
            totalPremium += shift.premiumMinutes
            if shift.isAdditionalShift {
                totalAdditional += shift.paidMinutes
            }
        }

        paidMinutes = totalPaid
        premiumMinutes = totalPremium
        additionalShiftMinutes = totalAdditional
    }

    /// Estimates pay based on base rate and hours
    func estimatePay(baseRateCents: Int64) {
        // Simple estimation: base rate * hours
        // More complex calculations would factor in rate multipliers
        let totalMinutes = paidMinutes
        let hours = Double(totalMinutes) / 60.0
        let basePayCents = Double(baseRateCents) * hours

        // Add premium pay estimation
        var premiumPayCents = 0.0
        for shift in activeShifts where shift.isCompleted && shift.hasPremiumPay {
            let premiumHours = Double(shift.premiumMinutes) / 60.0
            let extraPay = Double(baseRateCents) * premiumHours * (shift.rateMultiplier - 1.0)
            premiumPayCents += extraPay
        }

        estimatedPayCents = Int64(basePayCents + premiumPayCents)
    }

    /// Marks the period as complete
    func markComplete() {
        isComplete = true
        recalculateHours()
    }

    /// Checks if a date falls within this pay period
    func contains(date: Date) -> Bool {
        date >= startDate && date <= effectiveEndDate
    }

    /// Adds a shift to this pay period
    func addShift(_ shift: Shift) {
        if !shifts.contains(where: { $0.id == shift.id }) {
            shifts.append(shift)
            shift.payPeriod = self
        }
    }

    /// Removes a shift from this pay period
    func removeShift(_ shift: Shift) {
        shifts.removeAll { $0.id == shift.id }
        shift.payPeriod = nil
    }

    /// Recalculates aggregated values from shifts
    func recalculateFromShifts() {
        recalculateHours()
    }

    /// Finalizes/closes this pay period
    func finalize() {
        markComplete()
    }
}

// MARK: - Factory Methods
extension PayPeriod {
    /// Creates a pay period for current week
    static func currentWeek() -> PayPeriod {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!

        return PayPeriod(startDate: startOfWeek, endDate: calendar.endOfDay(for: endOfWeek))
    }

    /// Creates a pay period for current bi-weekly period
    static func currentBiweekly(startingFrom referenceDate: Date = Date()) -> PayPeriod {
        let calendar = Calendar.current
        let now = Date()

        // Find start of the bi-weekly period based on reference
        let daysSinceReference = calendar.dateComponents([.day], from: referenceDate, to: now).day ?? 0
        let periodIndex = daysSinceReference / 14
        let startDate = calendar.date(byAdding: .day, value: periodIndex * 14, to: referenceDate)!
        let endDate = calendar.date(byAdding: .day, value: 13, to: startDate)!

        return PayPeriod(startDate: startDate, endDate: calendar.endOfDay(for: endDate))
    }

    /// Creates a pay period for current month
    static func currentMonth() -> PayPeriod {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        return PayPeriod(startDate: startOfMonth, endDate: calendar.endOfDay(for: endOfMonth))
    }

    /// Creates a pay period for the current period based on type
    static func current(type: PayPeriodType) -> PayPeriod {
        switch type {
        case .weekly:
            return currentWeek()
        case .biweekly:
            return currentBiweekly()
        case .monthly:
            return currentMonth()
        }
    }
}
