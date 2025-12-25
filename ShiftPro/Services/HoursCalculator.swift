import Foundation

final class HoursCalculator {
    struct PeriodSummary: Codable {
        let totalPaidMinutes: Int
        let premiumMinutes: Int
        let regularMinutes: Int
        let estimatedPayCents: Int64?

        var totalHours: Double { Double(totalPaidMinutes) / 60.0 }
        var regularHours: Double { Double(regularMinutes) / 60.0 }
        var premiumHours: Double { Double(premiumMinutes) / 60.0 }
    }

    func updateCalculatedFields(for shift: Shift) {
        let totalMinutes = shift.effectiveDurationMinutes
        shift.paidMinutes = max(0, totalMinutes - max(0, shift.breakMinutes))
        shift.premiumMinutes = shift.rateMultiplier > 1.0 ? shift.paidMinutes : 0
    }

    func updatePayPeriod(_ payPeriod: PayPeriod, baseRateCents: Int64?) {
        payPeriod.recalculateHours()
        if let baseRateCents {
            payPeriod.estimatePay(baseRateCents: baseRateCents)
        }
    }

    func calculateSummary(for shifts: [Shift], baseRateCents: Int64?) -> PeriodSummary {
        let paidMinutes = shifts.reduce(0) { $0 + $1.paidMinutes }
        let premiumMinutes = shifts.reduce(0) { $0 + $1.premiumMinutes }
        let regularMinutes = max(0, paidMinutes - premiumMinutes)

        var estimatedPay: Int64?
        if let baseRateCents {
            let hours = Double(paidMinutes) / 60.0
            estimatedPay = Int64(Double(baseRateCents) * hours)
        }

        return PeriodSummary(
            totalPaidMinutes: paidMinutes,
            premiumMinutes: premiumMinutes,
            regularMinutes: regularMinutes,
            estimatedPayCents: estimatedPay
        )
    }
}
