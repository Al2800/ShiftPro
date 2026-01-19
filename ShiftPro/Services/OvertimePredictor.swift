import Foundation

struct OvertimeForecast {
    enum Status {
        case safe
        case approaching
        case exceeded
    }

    let projectedHours: Double
    let thresholdHours: Double
    let remainingHours: Double
    let status: Status
    let message: String
}

struct OvertimePredictor {
    func forecast(for shifts: [Shift], within period: PayPeriod, thresholdHours: Double) -> OvertimeForecast {
        let inPeriod = shifts.filter { shift in
            shift.deletedAt == nil &&
            period.contains(date: shift.scheduledStart)
        }

        let now = Date()
        let projectedMinutes = inPeriod.reduce(0) { total, shift in
            total + shift.overtimeMinutes(at: now)
        }
        let projectedHours = Double(projectedMinutes) / 60.0
        let remaining = max(0, thresholdHours - projectedHours)

        let status: OvertimeForecast.Status
        if projectedHours >= thresholdHours {
            status = .exceeded
        } else if projectedHours >= thresholdHours * 0.9 {
            status = .approaching
        } else {
            status = .safe
        }

        let message: String
        switch status {
        case .safe:
            message = "Overtime is tracking within your threshold."
        case .approaching:
            message = String(format: "Approaching overtime limit. Only %.1f hours remaining.", remaining)
        case .exceeded:
            message = "Projected to exceed your overtime limit."
        }

        return OvertimeForecast(
            projectedHours: projectedHours,
            thresholdHours: thresholdHours,
            remainingHours: remaining,
            status: status,
            message: message
        )
    }
}
