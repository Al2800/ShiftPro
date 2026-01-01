import Foundation
import SwiftData

@MainActor
final class PayPeriodEngine {
    private let context: ModelContext
    private let calculator: HoursCalculator

    init(context: ModelContext, calculator: HoursCalculator) {
        self.context = context
        self.calculator = calculator
    }

    func assignToPeriod(_ shift: Shift, type: PayPeriodType) throws {
        let targetDate = shift.scheduledStart
        let period = try ensurePeriod(for: targetDate, type: type, referenceDate: shift.owner?.startDate)
        shift.payPeriod = period
        calculator.updatePayPeriod(period, baseRateCents: shift.owner?.baseRateCents)
        try context.save()
    }

    func currentPeriod(type: PayPeriodType) throws -> PayPeriod {
        try ensurePeriod(for: Date(), type: type, referenceDate: nil)
    }

    func recentPeriods(count: Int, type: PayPeriodType) throws -> [PayPeriod] {
        var descriptor = FetchDescriptor<PayPeriod>()
        descriptor.sortBy = [PayPeriod.byStartDateDescending]
        descriptor.fetchLimit = count
        let periods = try context.fetch(descriptor)
        return periods.filter { $0.deletedAt == nil }
    }

    func recalculateAll(for profile: UserProfile, baseRateCents: Int64?) throws {
        let predicate = #Predicate<PayPeriod> { period in
            period.deletedAt == nil
        }
        let descriptor = FetchDescriptor<PayPeriod>(predicate: predicate)
        let periods = try context.fetch(descriptor)
        for period in periods {
            calculator.updatePayPeriod(period, baseRateCents: baseRateCents)
        }
        try context.save()
    }

    private func ensurePeriod(for date: Date, type: PayPeriodType, referenceDate: Date?) throws -> PayPeriod {
        if let existing = try fetchPeriod(containing: date) {
            if existing.normalizeEndDateIfNeeded() {
                try context.save()
            }
            return existing
        }

        let period = makePeriod(for: date, type: type, referenceDate: referenceDate)
        context.insert(period)
        try context.save()
        return period
    }

    private func fetchPeriod(containing date: Date) throws -> PayPeriod? {
        let dayStart = Calendar.current.startOfDay(for: date)
        let predicate = #Predicate<PayPeriod> { period in
            period.startDate <= date && period.endDate >= dayStart && period.deletedAt == nil
        }
        let descriptor = FetchDescriptor<PayPeriod>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    private func makePeriod(for date: Date, type: PayPeriodType, referenceDate: Date?) -> PayPeriod {
        let calendar = Calendar.current

        switch type {
        case .weekly:
            let startOfWeek = calendar.startOfWeek(for: date)
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? date
            return PayPeriod(startDate: startOfWeek, endDate: calendar.endOfDay(for: endOfWeek))
        case .biweekly:
            let reference = referenceDate ?? date
            let daysSinceReference = calendar.dateComponents([.day], from: reference, to: date).day ?? 0
            let periodIndex = daysSinceReference / 14
            let startDate = calendar.date(byAdding: .day, value: periodIndex * 14, to: reference) ?? date
            let endDate = calendar.date(byAdding: .day, value: 13, to: startDate) ?? date
            return PayPeriod(startDate: startDate, endDate: calendar.endOfDay(for: endDate))
        case .monthly:
            let startOfMonth = calendar.startOfMonth(for: date)
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? date
            return PayPeriod(startDate: startOfMonth, endDate: calendar.endOfDay(for: endOfMonth))
        }
    }
}
