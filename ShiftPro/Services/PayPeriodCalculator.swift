import Foundation
import SwiftData

/// Advanced pay period calculations with rate breakdown and projections
@MainActor
final class PayPeriodCalculator {

    // MARK: - Rate Breakdown Structure

    struct RateBreakdown: Identifiable {
        let id = UUID()
        let multiplier: Double
        let label: String
        let minutes: Int
        let estimatedPayCents: Int64?

        var hours: Double {
            Double(minutes) / 60.0
        }

        var percentage: Double {
            guard minutes > 0 else { return 0 }
            return 0 // Will be calculated relative to total
        }
    }

    struct PeriodAnalysis {
        let period: PayPeriod
        let rateBreakdown: [RateBreakdown]
        let totalHours: Double
        let regularHours: Double
        let premiumHours: Double
        let estimatedPayCents: Int64?
        let projectedTotalHours: Double?
        let targetHours: Int
        let progressPercentage: Double
        let averageHoursPerDay: Double
        let daysRemaining: Int
    }

    // MARK: - Analysis Methods

    /// Performs comprehensive analysis of a pay period
    func analyze(
        period: PayPeriod,
        targetHours: Int = 80,
        baseRateCents: Int64?
    ) -> PeriodAnalysis {
        let breakdown = calculateRateBreakdown(for: period, baseRateCents: baseRateCents)
        let totalHours = period.paidHours
        let daysElapsed = max(1, Calendar.current.dateComponents([.day], from: period.startDate, to: Date()).day ?? 1)
        let daysTotal = period.durationDays
        let daysRemaining = max(0, daysTotal - daysElapsed)

        let averagePerDay = totalHours / Double(daysElapsed)
        let projectedTotal = period.isCurrent ? totalHours + (averagePerDay * Double(daysRemaining)) : nil

        let progressPercentage = min(100.0, (totalHours / Double(targetHours)) * 100.0)

        return PeriodAnalysis(
            period: period,
            rateBreakdown: breakdown,
            totalHours: totalHours,
            regularHours: period.regularHours,
            premiumHours: period.premiumHours,
            estimatedPayCents: period.estimatedPayCents,
            projectedTotalHours: projectedTotal,
            targetHours: targetHours,
            progressPercentage: progressPercentage,
            averageHoursPerDay: averagePerDay,
            daysRemaining: daysRemaining
        )
    }

    /// Calculates detailed breakdown by rate multiplier
    func calculateRateBreakdown(
        for period: PayPeriod,
        baseRateCents: Int64?
    ) -> [RateBreakdown] {
        var rateMap: [Double: (label: String, minutes: Int)] = [:]

        for shift in period.completedShifts {
            let multiplier = shift.rateMultiplier
            let label = shift.rateLabel ?? rateDisplayLabel(for: multiplier)

            if var existing = rateMap[multiplier] {
                existing.minutes += shift.paidMinutes
                rateMap[multiplier] = existing
            } else {
                rateMap[multiplier] = (label, shift.paidMinutes)
            }
        }

        return rateMap.map { multiplier, data in
            var estimatedPay: Int64?
            if let baseRateCents = baseRateCents {
                let hours = Double(data.minutes) / 60.0
                estimatedPay = Int64(Double(baseRateCents) * hours * multiplier)
            }

            return RateBreakdown(
                multiplier: multiplier,
                label: data.label,
                minutes: data.minutes,
                estimatedPayCents: estimatedPay
            )
        }.sorted { $0.multiplier < $1.multiplier }
    }

    /// Compares current period to previous period
    func compareToPrevious(
        current: PayPeriod,
        previous: PayPeriod
    ) -> (hoursDelta: Double, percentageChange: Double) {
        let currentHours = current.paidHours
        let previousHours = previous.paidHours

        let delta = currentHours - previousHours
        let percentageChange = previousHours > 0
            ? (delta / previousHours) * 100.0
            : 0.0

        return (delta, percentageChange)
    }

    /// Calculates trend data for multiple periods
    func calculateTrend(periods: [PayPeriod]) -> [(date: Date, hours: Double)] {
        return periods
            .sorted { $0.startDate < $1.startDate }
            .map { ($0.startDate, $0.paidHours) }
    }

    /// Projects remaining hours needed to reach target
    func projectRemainingHours(
        for period: PayPeriod,
        targetHours: Int
    ) -> (hoursNeeded: Double, averagePerDayNeeded: Double) {
        let currentHours = period.paidHours
        let hoursNeeded = max(0, Double(targetHours) - currentHours)

        guard period.isCurrent else {
            return (hoursNeeded, 0)
        }

        let daysElapsed = max(1, Calendar.current.dateComponents([.day], from: period.startDate, to: Date()).day ?? 1)
        let daysTotal = period.durationDays
        let daysRemaining = max(1, daysTotal - daysElapsed)

        let averagePerDayNeeded = hoursNeeded / Double(daysRemaining)

        return (hoursNeeded, averagePerDayNeeded)
    }

    // MARK: - Helper Methods

    private func rateDisplayLabel(for multiplier: Double) -> String {
        switch multiplier {
        case 2.0:
            return "Bank Holiday"
        case 1.5:
            return "Extra"
        case 1.3:
            return "Overtime"
        case 1.0:
            return "Regular"
        default:
            return String(format: "%.1fx", multiplier)
        }
    }
}
