import Foundation
import SwiftData

/// Predictive overtime warning system
@MainActor
final class OvertimePredictor {

    // MARK: - Configuration

    struct OvertimeThreshold {
        let warningHours: Double
        let criticalHours: Double

        static let standard = OvertimeThreshold(warningHours: 35.0, criticalHours: 40.0)
    }

    enum WarningLevel {
        case none
        case approaching
        case warning
        case critical
        case exceeded

        var displayName: String {
            switch self {
            case .none: return "On Track"
            case .approaching: return "Approaching Limit"
            case .warning: return "Warning"
            case .critical: return "Critical"
            case .exceeded: return "Exceeded"
            }
        }

        var iconName: String {
            switch self {
            case .none: return "checkmark.circle.fill"
            case .approaching: return "exclamationmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "exclamationmark.triangle.fill"
            case .exceeded: return "xmark.octagon.fill"
            }
        }
    }

    struct Prediction {
        let currentHours: Double
        let projectedHours: Double
        let targetHours: Int
        let warningLevel: WarningLevel
        let message: String
        let daysRemaining: Int
        let averageHoursPerDay: Double
        let recommendedDailyHours: Double?
    }

    // MARK: - Prediction Methods

    /// Predicts overtime based on current pace
    func predict(
        for period: PayPeriod,
        targetHours: Int = 80,
        threshold: OvertimeThreshold = .standard
    ) -> Prediction {
        let currentHours = period.paidHours

        guard period.isCurrent else {
            return Prediction(
                currentHours: currentHours,
                projectedHours: currentHours,
                targetHours: targetHours,
                warningLevel: .none,
                message: "Period complete",
                daysRemaining: 0,
                averageHoursPerDay: 0,
                recommendedDailyHours: nil
            )
        }

        let calendar = Calendar.current
        let now = Date()
        let daysElapsed = max(1, calendar.dateComponents([.day], from: period.startDate, to: now).day ?? 1)
        let daysTotal = period.durationDays
        let daysRemaining = max(0, daysTotal - daysElapsed)

        let averagePerDay = currentHours / Double(daysElapsed)
        let projectedTotal = currentHours + (averagePerDay * Double(daysRemaining))

        let warningLevel = calculateWarningLevel(
            current: currentHours,
            projected: projectedTotal,
            target: Double(targetHours),
            threshold: threshold
        )

        let message = generateMessage(
            current: currentHours,
            projected: projectedTotal,
            target: Double(targetHours),
            level: warningLevel,
            daysRemaining: daysRemaining
        )

        let recommendedDaily = daysRemaining > 0
            ? max(0, Double(targetHours) - currentHours) / Double(daysRemaining)
            : nil

        return Prediction(
            currentHours: currentHours,
            projectedHours: projectedTotal,
            targetHours: targetHours,
            warningLevel: warningLevel,
            message: message,
            daysRemaining: daysRemaining,
            averageHoursPerDay: averagePerDay,
            recommendedDailyHours: recommendedDaily
        )
    }

    /// Suggests shifts to optimize hours
    func suggestShifts(
        for period: PayPeriod,
        targetHours: Int,
        typicalShiftHours: Double = 8.0
    ) -> (shiftsNeeded: Int, totalHours: Double, message: String) {
        let currentHours = period.paidHours
        let hoursNeeded = max(0, Double(targetHours) - currentHours)
        let shiftsNeeded = Int(ceil(hoursNeeded / typicalShiftHours))

        let message: String
        if hoursNeeded <= 0 {
            let excess = currentHours - Double(targetHours)
            message = "You've already met your target. Current excess: \(String(format: "%.1f", excess)) hours."
        } else if shiftsNeeded == 1 {
            message = "Schedule 1 more \(Int(typicalShiftHours))-hour shift to reach your target."
        } else {
            message = "Schedule \(shiftsNeeded) more shifts (approx. \(String(format: "%.1f", hoursNeeded)) hours) to reach your target."
        }

        return (shiftsNeeded, hoursNeeded, message)
    }

    /// Checks if scheduled shifts will exceed target
    func checkScheduledOvertime(
        for period: PayPeriod,
        targetHours: Int
    ) -> (willExceed: Bool, excessHours: Double, upcomingHours: Double) {
        let completedHours = period.completedShifts.reduce(0.0) { $0 + $1.paidHours }
        let upcomingHours = period.upcomingShifts.reduce(0.0) { $0 + $1.paidHours }
        let projectedTotal = completedHours + upcomingHours

        let willExceed = projectedTotal > Double(targetHours)
        let excessHours = max(0, projectedTotal - Double(targetHours))

        return (willExceed, excessHours, upcomingHours)
    }

    // MARK: - Private Helpers

    private func calculateWarningLevel(
        current: Double,
        projected: Double,
        target: Double,
        threshold: OvertimeThreshold
    ) -> WarningLevel {
        // Check if already exceeded
        if current >= target {
            return .exceeded
        }

        // Check critical threshold
        if current >= threshold.criticalHours || projected >= target {
            return .critical
        }

        // Check warning threshold
        if current >= threshold.warningHours || projected >= threshold.criticalHours {
            return .warning
        }

        // Check if approaching
        let percentToWarning = (current / threshold.warningHours) * 100.0
        if percentToWarning >= 80.0 {
            return .approaching
        }

        return .none
    }

    private func generateMessage(
        current: Double,
        projected: Double,
        target: Double,
        level: WarningLevel,
        daysRemaining: Int
    ) -> String {
        let excess = projected - target

        switch level {
        case .none:
            return "You're on track. Projected: \(String(format: "%.1f", projected)) hours."
        case .approaching:
            let hoursToTarget = target - current
            return "Approaching target. \(String(format: "%.1f", hoursToTarget)) hours remaining."
        case .warning:
            return "Warning: Projected to work \(String(format: "%.1f", excess)) hours over target."
        case .critical:
            return "Critical: On pace to exceed target by \(String(format: "%.1f", excess)) hours."
        case .exceeded:
            let currentExcess = current - target
            return "Target exceeded by \(String(format: "%.1f", currentExcess)) hours."
        }
    }
}
