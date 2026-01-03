import Foundation
import SwiftData
import Observation

/// Central service for shift management operations
@MainActor
@Observable
final class ShiftManager {
    // MARK: - Dependencies

    private let context: ModelContext
    private let validator: ShiftValidator
    private let calculator: HoursCalculator
    private let periodEngine: PayPeriodEngine
    private let shiftRepository: ShiftRepository
    private let profileRepository: UserProfileRepository
    private let notificationManager: NotificationManager

    // MARK: - Observable State

    private(set) var currentShift: Shift?
    private(set) var upcomingShifts: [Shift] = []
    private(set) var todayShifts: [Shift] = []
    private(set) var isLoading = false
    private(set) var lastError: Error?

    // MARK: - Initialization

    init(context: ModelContext, notificationManager: NotificationManager? = nil) {
        self.context = context
        self.validator = ShiftValidator(context: context)
        self.calculator = HoursCalculator()
        self.periodEngine = PayPeriodEngine(context: context, calculator: calculator)
        self.shiftRepository = ShiftRepository(context: context)
        self.profileRepository = UserProfileRepository(context: context)
        self.notificationManager = notificationManager ?? NotificationManager(context: context)
    }

    // MARK: - Refresh

    /// Refreshes all observable state
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            todayShifts = try shiftRepository.fetchToday()
            upcomingShifts = try shiftRepository.fetchUpcoming()
            currentShift = findCurrentShift()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    /// Finds the currently in-progress shift
    private func findCurrentShift() -> Shift? {
        todayShifts.first { $0.status == .inProgress }
    }

    // MARK: - Shift CRUD

    /// Creates a new shift
    func createShift(
        scheduledStart: Date,
        scheduledEnd: Date,
        pattern: ShiftPattern? = nil,
        breakMinutes: Int = 30,
        rateMultiplier: Double = 1.0,
        rateLabel: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        isAdditionalShift: Bool = false
    ) async throws -> Shift {
        let owner = try profileRepository.ensurePrimary()
        let sanitizedLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedLocation = sanitizedLocation?.isEmpty == false ? sanitizedLocation : nil

        let shift = Shift(
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            breakMinutes: breakMinutes,
            isAdditionalShift: isAdditionalShift,
            location: storedLocation,
            notes: notes,
            rateMultiplier: rateMultiplier,
            rateLabel: rateLabel,
            pattern: pattern,
            owner: owner
        )

        // Validate
        let result = await validator.validate(shift)
        if !result.isValid {
            throw result.errors.first ?? DataError.saveFailed
        }

        // Calculate hours
        calculator.updateCalculatedFields(for: shift)

        // Assign to pay period
        try periodEngine.assignToPeriod(shift, type: owner.payPeriodType)

        // Save
        try shiftRepository.add(shift)

        // Refresh state
        await refresh()
        try? await notificationManager.scheduleNotifications(for: shift)

        return shift
    }

    /// Creates a shift from a pattern for a specific date
    func createShiftFromPattern(
        _ pattern: ShiftPattern,
        on date: Date
    ) async throws -> Shift {
        // Validate pattern
        let patternResult = validator.validatePatternShift(pattern: pattern, on: date)
        if !patternResult.isValid {
            throw patternResult.errors.first ?? DataError.saveFailed
        }

        let owner = try profileRepository.ensurePrimary()
        let shift = Shift.fromPattern(pattern, on: date, owner: owner)

        // Validate shift
        let result = await validator.validate(shift)
        if !result.isValid {
            throw result.errors.first ?? DataError.saveFailed
        }

        // Calculate hours
        calculator.updateCalculatedFields(for: shift)

        // Assign to pay period
        try periodEngine.assignToPeriod(shift, type: owner.payPeriodType)

        // Save
        try shiftRepository.add(shift)

        // Refresh state
        await refresh()
        try? await notificationManager.scheduleNotifications(for: shift)

        return shift
    }

    /// Updates an existing shift
    func updateShift(
        _ shift: Shift,
        scheduledStart: Date? = nil,
        scheduledEnd: Date? = nil,
        breakMinutes: Int? = nil,
        rateMultiplier: Double? = nil,
        rateLabel: String?? = nil,
        notes: String?? = nil,
        location: String?? = nil,
        pattern: ShiftPattern?? = nil
    ) async throws {
        let originalStart = shift.scheduledStart
        let originalPeriod = shift.payPeriod

        // Apply changes
        if let start = scheduledStart { shift.scheduledStart = start }
        if let end = scheduledEnd { shift.scheduledEnd = end }
        if let breakMin = breakMinutes { shift.breakMinutes = breakMin }
        if let rate = rateMultiplier { shift.rateMultiplier = rate }
        if let label = rateLabel { shift.rateLabel = label }
        if let noteText = notes { shift.notes = noteText }
        if let location = location {
            let trimmed = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            shift.location = trimmed.isEmpty ? nil : trimmed
        }
        if let pattern = pattern {
            shift.pattern = pattern
        }

        // Validate
        let result = await validator.validate(shift)
        if !result.isValid {
            throw result.errors.first ?? DataError.saveFailed
        }

        // Recalculate
        calculator.updateCalculatedFields(for: shift)

        let owner = shift.owner
        if let owner, shift.payPeriod == nil || originalStart != shift.scheduledStart {
            try periodEngine.assignToPeriod(shift, type: owner.payPeriodType)
            if let originalPeriod, originalPeriod.id != shift.payPeriod?.id {
                calculator.updatePayPeriod(originalPeriod, baseRateCents: owner.baseRateCents)
            }
        } else if let period = shift.payPeriod {
            calculator.updatePayPeriod(period, baseRateCents: owner?.baseRateCents)
        }

        // Save
        try shiftRepository.update(shift)

        // Refresh state
        await refresh()
        try? await notificationManager.scheduleNotifications(for: shift)
    }

    /// Deletes a shift (soft delete)
    func deleteShift(_ shift: Shift) async throws {
        let period = shift.payPeriod
        let baseRate = shift.owner?.baseRateCents
        try shiftRepository.softDelete(shift)
        notificationManager.cancelNotifications(for: shift)
        if let period {
            calculator.updatePayPeriod(period, baseRateCents: baseRate)
        }
        await refresh()
    }

    // MARK: - Clock In/Out

    /// Starts a shift (clock in)
    func clockIn(shift: Shift, at time: Date = Date()) async throws {
        // Validate clock time
        let clockResult = validator.validateClockTimes(shift: shift, clockIn: time)
        if !clockResult.isValid {
            throw clockResult.errors.first ?? DataError.saveFailed
        }

        shift.clockIn(at: time)
        try shiftRepository.update(shift)
        notificationManager.cancelNotifications(for: shift)

        // Update state
        currentShift = shift
        await refresh()
    }

    /// Ends a shift (clock out)
    func clockOut(shift: Shift, at time: Date = Date()) async throws {
        guard shift.actualStart != nil else {
            throw DataError.saveFailed
        }

        // Validate clock time
        let clockResult = validator.validateClockTimes(
            shift: shift,
            clockIn: shift.actualStart,
            clockOut: time
        )
        if !clockResult.isValid {
            throw clockResult.errors.first ?? DataError.saveFailed
        }

        shift.clockOut(at: time)
        calculator.updateCalculatedFields(for: shift)
        try shiftRepository.update(shift)
        notificationManager.cancelNotifications(for: shift)

        // Update pay period
        if let period = shift.payPeriod, let owner = shift.owner {
            calculator.updatePayPeriod(period, baseRateCents: owner.baseRateCents)
        }

        // Update state
        currentShift = nil
        await refresh()
    }

    /// Quick action: start/end current shift
    func toggleCurrentShift() async throws {
        if let current = currentShift {
            try await clockOut(shift: current)
        } else if let upcoming = todayShifts.first(where: { $0.status == .scheduled }) {
            try await clockIn(shift: upcoming)
        } else {
            // Create ad-hoc shift
            let now = Date()
            let end = Calendar.current.date(byAdding: .hour, value: 8, to: now) ?? now
            let shift = try await createShift(
                scheduledStart: now,
                scheduledEnd: end,
                isAdditionalShift: true
            )
            try await clockIn(shift: shift, at: now)
        }
    }

    // MARK: - Queries

    /// Fetches shifts for a date range
    func shifts(from startDate: Date, to endDate: Date) throws -> [Shift] {
        try shiftRepository.fetchRange(from: startDate, to: endDate)
    }

    /// Fetches shifts for a specific month
    func shiftsForMonth(containing date: Date) throws -> [Shift] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return try shifts(from: start, to: end)
    }

    /// Gets the hours summary for a date range
    func hoursSummary(from startDate: Date, to endDate: Date) throws -> HoursCalculator.PeriodSummary {
        let shifts = try self.shifts(from: startDate, to: endDate)
            .filter { $0.status == .completed }
        let profile = try profileRepository.fetchPrimary()
        return calculator.calculateSummary(for: shifts, baseRateCents: profile?.baseRateCents)
    }

    // MARK: - Pay Period Operations

    /// Gets the current pay period
    func currentPayPeriod() throws -> PayPeriod {
        let profile = try profileRepository.ensurePrimary()
        return try periodEngine.currentPeriod(type: profile.payPeriodType)
    }

    /// Gets recent pay periods
    func recentPayPeriods(count: Int = 6) throws -> [PayPeriod] {
        let profile = try profileRepository.ensurePrimary()
        return try periodEngine.recentPeriods(count: count, type: profile.payPeriodType)
    }

    /// Recalculates all pay periods
    func recalculatePayPeriods() throws {
        guard let profile = try profileRepository.fetchPrimary() else { return }
        try periodEngine.recalculateAll(for: profile, baseRateCents: profile.baseRateCents)
    }

    // MARK: - Conflict Detection

    /// Checks if a time range has conflicts
    func hasConflicts(start: Date, end: Date, excluding shiftId: UUID? = nil) async -> Bool {
        guard let owner = try? profileRepository.fetchPrimary() else { return false }
        return await validator.hasConflicts(start: start, end: end, owner: owner, excludingShiftId: shiftId)
    }

    // MARK: - Convenience Properties

    /// Whether there is a shift currently in progress
    var isOnShift: Bool {
        currentShift != nil
    }

    /// Next upcoming shift
    var nextShift: Shift? {
        upcomingShifts.first
    }

    /// Hours worked today
    var hoursWorkedToday: Double {
        todayShifts
            .filter { $0.status == .completed }
            .reduce(0) { $0 + $1.paidHours }
    }
}
