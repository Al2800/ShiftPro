import Foundation
import SwiftData

/// Optimized queries for common data access patterns
struct OptimizedQueries {

    // MARK: - Shift Queries

    /// Fetch shifts for a specific pay period (optimized with predicate)
    static func shifts(
        in period: PayPeriod,
        context: ModelContext
    ) throws -> [Shift] {
        let startDate = period.startDate
        let endDate = period.endDate
        let calendar = Calendar.current
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endDate)
        let isMidnight = (endComponents.hour ?? 0) == 0
            && (endComponents.minute ?? 0) == 0
            && (endComponents.second ?? 0) == 0
        let normalizedEnd = isMidnight ? calendar.endOfDay(for: endDate) : endDate

        let predicate = #Predicate<Shift> { shift in
            shift.deletedAt == nil &&
            shift.scheduledStart < normalizedEnd &&
            shift.scheduledEnd > startDate
        }

        var descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.scheduledStart, order: .forward)]
        )

        return try context.fetch(descriptor)
    }

    /// Fetch paginated shifts with efficient loading
    static func paginatedShifts(
        offset: Int = 0,
        limit: Int = 50,
        context: ModelContext
    ) throws -> [Shift] {
        let predicate = #Predicate<Shift> { shift in
            shift.deletedAt == nil
        }

        var descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.scheduledStart, order: .reverse)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit

        return try context.fetch(descriptor)
    }

    /// Count total shifts (fast count query)
    static func shiftsCount(context: ModelContext) throws -> Int {
        let predicate = #Predicate<Shift> { shift in
            shift.deletedAt == nil
        }

        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    /// Fetch upcoming shifts (next 7 days)
    static func upcomingShifts(
        context: ModelContext,
        days: Int = 7
    ) throws -> [Shift] {
        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now

        let cancelledRaw = ShiftStatus.cancelled.rawValue
        let predicate = #Predicate<Shift> { shift in
            shift.deletedAt == nil &&
            shift.scheduledStart >= now &&
            shift.scheduledStart < futureDate &&
            shift.statusRaw != cancelledRaw
        }

        var descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.scheduledStart, order: .forward)]
        )
        descriptor.fetchLimit = 20  // Reasonable limit

        return try context.fetch(descriptor)
    }

    // MARK: - Pay Period Queries

    /// Fetch current pay period
    static func currentPayPeriod(context: ModelContext) throws -> PayPeriod? {
        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)

        let predicate = #Predicate<PayPeriod> { period in
            period.deletedAt == nil &&
            period.startDate <= now &&
            period.endDate >= dayStart
        }

        var descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    /// Fetch recent pay periods (last N periods)
    static func recentPayPeriods(
        limit: Int = 6,
        context: ModelContext
    ) throws -> [PayPeriod] {
        let predicate = #Predicate<PayPeriod> { period in
            period.deletedAt == nil
        }

        var descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return try context.fetch(descriptor)
    }

    // MARK: - Pattern Queries

    /// Fetch active patterns
    static func activePatterns(context: ModelContext) throws -> [ShiftPattern] {
        let predicate = #Predicate<ShiftPattern> { pattern in
            pattern.deletedAt == nil &&
            pattern.isActive
        }

        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return try context.fetch(descriptor)
    }

    // MARK: - Batch Operations

    /// Batch insert shifts (optimized for large imports)
    static func batchInsertShifts(
        _ shifts: [Shift],
        context: ModelContext,
        batchSize: Int = 100
    ) throws {
        for batch in shifts.chunked(into: batchSize) {
            for shift in batch {
                context.insert(shift)
            }
            try context.save()
        }
    }

    /// Batch update shifts (optimized)
    static func batchUpdateShifts(
        matching predicate: Predicate<Shift>,
        context: ModelContext,
        update: (Shift) -> Void
    ) throws {
        let descriptor = FetchDescriptor(predicate: predicate)
        let shifts = try context.fetch(descriptor)

        for shift in shifts {
            update(shift)
        }

        try context.save()
    }

    // MARK: - Background Context

    /// Create background context for heavy operations
    static func performBackgroundTask(
        container: ModelContainer,
        task: @escaping (ModelContext) throws -> Void
    ) async throws {
        let backgroundContext = ModelContext(container)
        backgroundContext.autosaveEnabled = false

        try task(backgroundContext)
        try backgroundContext.save()
    }
}
