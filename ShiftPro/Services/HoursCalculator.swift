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
        let paidMinutes = max(0, totalMinutes - max(0, shift.breakMinutes))
        shift.paidMinutes = paidMinutes

        if shift.rateMultiplier > 1.0 {
            if shift.premiumMinutes <= 0 || shift.premiumMinutes > paidMinutes {
                shift.premiumMinutes = paidMinutes
            } else {
                shift.premiumMinutes = min(shift.premiumMinutes, paidMinutes)
            }
        } else {
            shift.premiumMinutes = 0
        }
    }

    func updatePayPeriod(_ payPeriod: PayPeriod, baseRateCents: Int64?) {
        payPeriod.recalculateHours()
        if let baseRateCents {
            payPeriod.estimatePay(baseRateCents: baseRateCents)
        }
    }

    func calculateSummary(for shifts: [Shift], baseRateCents: Int64?) -> PeriodSummary {
        let paidMinutes = shifts.reduce(0) { total, shift in
            let minutes = shift.paidMinutes > 0
                ? shift.paidMinutes
                : max(0, shift.effectiveDurationMinutes - shift.breakMinutes)
            return total + minutes
        }
        let premiumMinutes = shifts.reduce(0) { total, shift in
            guard shift.rateMultiplier > 1.0 else { return total }
            let minutes = shift.paidMinutes > 0
                ? shift.paidMinutes
                : max(0, shift.effectiveDurationMinutes - shift.breakMinutes)
            if shift.premiumMinutes > 0 {
                return total + min(shift.premiumMinutes, minutes)
            }
            return total + minutes
        }
        let regularMinutes = max(0, paidMinutes - premiumMinutes)

        var estimatedPay: Int64?
        if let baseRateCents {
            let basePay = Double(baseRateCents) * (Double(paidMinutes) / 60.0)
            let premiumPay = shifts.reduce(0.0) { total, shift in
                guard shift.rateMultiplier > 1.0 else { return total }
                let minutes = shift.paidMinutes > 0
                    ? shift.paidMinutes
                    : max(0, shift.effectiveDurationMinutes - shift.breakMinutes)
                let premiumMinutes = shift.premiumMinutes > 0 ? min(shift.premiumMinutes, minutes) : minutes
                let premiumHours = Double(premiumMinutes) / 60.0
                return total + (Double(baseRateCents) * premiumHours * (shift.rateMultiplier - 1.0))
            }
            estimatedPay = Int64((basePay + premiumPay).rounded())
        }

        return PeriodSummary(
            totalPaidMinutes: paidMinutes,
            premiumMinutes: premiumMinutes,
            regularMinutes: regularMinutes,
            estimatedPayCents: estimatedPay
        )
    }
}
