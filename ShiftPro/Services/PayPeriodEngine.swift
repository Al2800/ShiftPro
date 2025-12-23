import Foundation
import SwiftData

struct PayPeriodEngine {
    static func payPeriod(for date: Date, profile: UserProfile, context: ModelContext) throws -> PayPeriod {
        if let existing = try fetchPayPeriod(containing: date, context: context) {
            return existing
        }

        let type = profile.activePayRuleset?.payPeriodType ?? profile.payPeriodType
        let range = periodBounds(for: date, type: type, referenceDate: profile.startDate)
        let period = PayPeriod(startDate: range.start, endDate: range.end)
        context.insert(period)
        try context.save()
        return period
    }

    static func update(_ payPeriod: PayPeriod, baseRateCents: Int64?, context: ModelContext) throws {
        payPeriod.recalculateHours()
        if let baseRateCents {
            payPeriod.estimatePay(baseRateCents: baseRateCents)
        }
        try context.save()
    }

    static func periodBounds(for date: Date, type: PayPeriodType, referenceDate: Date) -> DateInterval {
        let calendar = Calendar.current

        switch type {
        case .weekly:
            let startOfWeek = calendar.startOfWeek(for: date)
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? date
            return DateInterval(start: startOfWeek, end: endOfWeek)
        case .biweekly:
            let daysSinceReference = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
            let periodIndex = daysSinceReference / 14
            let startDate = calendar.date(byAdding: .day, value: periodIndex * 14, to: referenceDate) ?? date
            let endDate = calendar.date(byAdding: .day, value: 13, to: startDate) ?? date
            return DateInterval(start: startDate, end: endDate)
        case .monthly:
            let startOfMonth = calendar.startOfMonth(for: date)
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? date
            return DateInterval(start: startOfMonth, end: endOfMonth)
        }
    }

    private static func fetchPayPeriod(containing date: Date, context: ModelContext) throws -> PayPeriod? {
        let predicate = #Predicate<PayPeriod> { period in
            period.startDate <= date && period.endDate >= date && period.deletedAt == nil
        }
        let descriptor = FetchDescriptor<PayPeriod>(predicate: predicate, sortBy: [PayPeriod.byStartDateDescending])
        return try context.fetch(descriptor).first
    }
}
