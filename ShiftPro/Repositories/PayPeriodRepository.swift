import Foundation
import SwiftData

/// Repository for managing PayPeriod entities
@MainActor
final class PayPeriodRepository: AbstractRepository {
    typealias Model = PayPeriod

    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    convenience init(context: ModelContext) {
        self.init(modelContext: context)
    }

    /// Fetches all pay periods sorted by start date (most recent first)
    func fetchAll() throws -> [PayPeriod] {
        try fetch(predicate: nil, sortBy: [PayPeriod.byStartDateDescending])
    }

    /// Fetches the current pay period (if any)
    func fetchCurrent() throws -> PayPeriod? {
        let now = Date()
        let predicate = #Predicate<PayPeriod> { period in
            period.deletedAt == nil &&
            period.startDate <= now &&
            period.endDate >= now
        }
        let periods = try fetch(predicate: predicate, sortBy: [])
        return periods.first
    }

    /// Fetches pay periods within a date range
    func fetchRange(from startDate: Date, to endDate: Date) throws -> [PayPeriod] {
        let predicate = #Predicate<PayPeriod> { period in
            period.deletedAt == nil &&
            period.startDate >= startDate &&
            period.endDate <= endDate
        }
        return try fetch(predicate: predicate, sortBy: [PayPeriod.byStartDateDescending])
    }

    /// Fetches recent pay periods (last N completed)
    func fetchRecent(limit: Int = 6) throws -> [PayPeriod] {
        let predicate = #Predicate<PayPeriod> { period in
            period.deletedAt == nil && period.isComplete
        }
        var descriptor = FetchDescriptor<PayPeriod>(
            predicate: predicate,
            sortBy: [PayPeriod.byStartDateDescending]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    /// Gets or creates the current pay period based on profile settings
    func getOrCreateCurrent(for profile: UserProfile) throws -> PayPeriod {
        if let existing = try fetchCurrent() {
            return existing
        }

        // Create a new pay period based on profile settings
        let period = PayPeriod.current(type: profile.payPeriodType)
        insert(period)
        try save()
        return period
    }

    /// Creates a new pay period
    func add(_ period: PayPeriod) throws {
        insert(period)
        try save()
    }

    /// Updates a pay period
    func update(_ period: PayPeriod) throws {
        try save()
    }

    /// Finalizes/closes a pay period
    func finalize(_ period: PayPeriod) throws {
        period.finalize()
        try save()
    }

    /// Recalculates aggregates for a pay period from its shifts
    func recalculate(_ period: PayPeriod) throws {
        period.recalculateFromShifts()
        try save()
    }

    /// Soft deletes a pay period
    func softDelete(_ period: PayPeriod) throws {
        period.softDelete()
        try save()
    }

    /// Assigns a shift to a pay period
    func assignShift(_ shift: Shift, to period: PayPeriod) throws {
        period.addShift(shift)
        try save()
    }

    /// Removes a shift from a pay period
    func removeShift(_ shift: Shift, from period: PayPeriod) throws {
        period.removeShift(shift)
        try save()
    }

    /// Finds the appropriate pay period for a shift based on its date
    func findPeriodForShift(_ shift: Shift) throws -> PayPeriod? {
        let shiftDate = shift.scheduledStart
        let predicate = #Predicate<PayPeriod> { period in
            period.deletedAt == nil &&
            period.startDate <= shiftDate &&
            period.endDate >= shiftDate
        }
        let periods = try fetch(predicate: predicate, sortBy: [])
        return periods.first
    }

    /// Auto-assigns a shift to the correct pay period, creating one if needed
    func autoAssignShift(_ shift: Shift, profile: UserProfile) throws {
        if let period = try findPeriodForShift(shift) {
            period.addShift(shift)
        } else {
            // Create a new pay period that contains this shift
            let shiftDate = shift.scheduledStart
            let (start, end) = calculatePeriodDates(
                for: shiftDate,
                type: profile.payPeriodType
            )
            let newPeriod = PayPeriod(startDate: start, endDate: end)
            newPeriod.addShift(shift)
            insert(newPeriod)
        }
        try save()
    }

    /// Calculates period start/end dates for a given date
    private func calculatePeriodDates(
        for date: Date,
        type: PayPeriodType,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let startOfDay = calendar.startOfDay(for: date)

        switch type {
        case .weekly:
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)
            components.weekday = 2 // Monday
            let weekStart = calendar.date(from: components) ?? startOfDay
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? startOfDay
            return (weekStart, weekEnd)

        case .biweekly:
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)
            components.weekday = 2 // Monday
            let weekStart = calendar.date(from: components) ?? startOfDay
            let weekOfYear = calendar.component(.weekOfYear, from: startOfDay)
            let isEvenWeek = weekOfYear % 2 == 0
            let biweeklyStart = isEvenWeek
                ? calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
                : weekStart
            let biweeklyEnd = calendar.date(byAdding: .day, value: 13, to: biweeklyStart) ?? startOfDay
            return (biweeklyStart, biweeklyEnd)

        case .monthly:
            var components = calendar.dateComponents([.year, .month], from: startOfDay)
            let monthStart = calendar.date(from: components) ?? startOfDay
            components.month! += 1
            components.day = 0
            let monthEnd = calendar.date(from: components) ?? startOfDay
            return (monthStart, monthEnd)
        }
    }
}
