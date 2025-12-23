import Foundation

struct HoursCalculator {
    static func paidMinutes(totalMinutes: Int, breakMinutes: Int) -> Int {
        max(0, totalMinutes - max(0, breakMinutes))
    }

    static func paidMinutes(start: Date, end: Date, breakMinutes: Int) -> Int {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        return paidMinutes(totalMinutes: minutes, breakMinutes: breakMinutes)
    }

    static func premiumMinutes(paidMinutes: Int, rateMultiplier: Double) -> Int {
        rateMultiplier > 1.0 ? paidMinutes : 0
    }

    static func apply(to shift: Shift) {
        let totalMinutes = shift.effectiveDurationMinutes
        shift.paidMinutes = paidMinutes(totalMinutes: totalMinutes, breakMinutes: shift.breakMinutes)
        shift.premiumMinutes = premiumMinutes(paidMinutes: shift.paidMinutes, rateMultiplier: shift.rateMultiplier)
    }
}
