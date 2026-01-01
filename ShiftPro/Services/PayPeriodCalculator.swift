import Foundation

struct PayPeriodCalculator {
    struct RateBucket: Identifiable, Codable {
        let id: UUID
        let label: String
        let multiplier: Double
        let minutes: Int

        var hours: Double {
            Double(minutes) / 60.0
        }

        init(id: UUID = UUID(), label: String, multiplier: Double, minutes: Int) {
            self.id = id
            self.label = label
            self.multiplier = multiplier
            self.minutes = minutes
        }
    }

    struct DailyTotal: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Int

        var hours: Double {
            Double(minutes) / 60.0
        }
    }

    func period(for date: Date, type: PayPeriodType, referenceDate: Date?) -> PayPeriod {
        let calendar = Calendar.current
        switch type {
        case .weekly:
            let start = calendar.startOfWeek(for: date)
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? date
            return PayPeriod(startDate: start, endDate: calendar.endOfDay(for: end))
        case .biweekly:
            let reference = referenceDate ?? date
            let daysSinceReference = calendar.dateComponents([.day], from: reference, to: date).day ?? 0
            let periodIndex = daysSinceReference / 14
            let startDate = calendar.date(byAdding: .day, value: periodIndex * 14, to: reference) ?? date
            let endDate = calendar.date(byAdding: .day, value: 13, to: startDate) ?? date
            return PayPeriod(startDate: startDate, endDate: calendar.endOfDay(for: endDate))
        case .monthly:
            let start = calendar.startOfMonth(for: date)
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? date
            return PayPeriod(startDate: start, endDate: calendar.endOfDay(for: end))
        }
    }

    func shifts(in period: PayPeriod, from shifts: [Shift]) -> [Shift] {
        shifts.filter { shift in
            shift.deletedAt == nil && period.contains(date: shift.scheduledStart)
        }
    }

    func summary(for shifts: [Shift], baseRateCents: Int64?) -> HoursCalculator.PeriodSummary {
        let paidMinutes = shifts.reduce(0) { total, shift in
            total + max(0, shift.effectiveDurationMinutes - shift.breakMinutes)
        }

        let premiumMinutes = shifts.reduce(0) { total, shift in
            guard shift.rateMultiplier > 1.0 else { return total }
            return total + max(0, shift.effectiveDurationMinutes - shift.breakMinutes)
        }

        let regularMinutes = max(0, paidMinutes - premiumMinutes)
        let estimatedPayCents: Int64? = baseRateCents.map { baseRate in
            let total = shifts.reduce(0.0) { total, shift in
                let minutes = shift.paidMinutes > 0
                    ? shift.paidMinutes
                    : max(0, shift.effectiveDurationMinutes - shift.breakMinutes)
                let hours = Double(minutes) / 60.0
                return total + (Double(baseRate) * hours * shift.rateMultiplier)
            }
            return Int64(total.rounded())
        }

        return HoursCalculator.PeriodSummary(
            totalPaidMinutes: paidMinutes,
            premiumMinutes: premiumMinutes,
            regularMinutes: regularMinutes,
            estimatedPayCents: estimatedPayCents
        )
    }

    func dailyTotals(for shifts: [Shift], within period: PayPeriod) -> [DailyTotal] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: period.startDate)
        let end = calendar.startOfDay(for: period.endDate)
        var results: [DailyTotal] = []

        var date = start
        while date <= end {
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let minutes = shifts.reduce(0) { total, shift in
                guard shift.scheduledStart >= dayStart,
                      shift.scheduledStart < dayEnd else { return total }
                let effective = shift.effectiveDurationMinutes - shift.breakMinutes
                let paid = shift.paidMinutes > 0 ? shift.paidMinutes : max(0, effective)
                return total + paid
            }
            results.append(DailyTotal(date: date, minutes: minutes))
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        return results
    }

    func rateBreakdown(for shifts: [Shift]) -> [RateBucket] {
        let grouped = Dictionary(grouping: shifts) { shift in
            shift.rateMultiplier
        }

        let buckets = grouped.map { multiplier, groupedShifts in
            let minutes = groupedShifts.reduce(0) { total, shift in
                let effective = shift.effectiveDurationMinutes - shift.breakMinutes
                let paid = shift.paidMinutes > 0 ? shift.paidMinutes : max(0, effective)
                return total + paid
            }
            let defaultLabel = String(format: "%.1fx", multiplier)
            let label = RateMultiplier(rawValue: multiplier)?.displayName ?? defaultLabel
            return RateBucket(label: label, multiplier: multiplier, minutes: minutes)
        }

        return buckets.sorted { $0.multiplier < $1.multiplier }
    }
}
