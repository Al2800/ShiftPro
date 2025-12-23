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
            shift.scheduledStart >= period.startDate &&
            shift.scheduledStart <= period.endDate
        }

        let completedMinutes = inPeriod.reduce(0) { total, shift in
            guard shift.isCompleted else { return total }
            return total + minutes(for: shift)
        }

        let inProgressMinutes = inPeriod.reduce(0) { total, shift in
            guard shift.isInProgress else { return total }
            if let actualStart = shift.actualStart {
                let elapsed = Int(Date().timeIntervalSince(actualStart) / 60)
                return total + max(0, elapsed - shift.breakMinutes)
            }
            return total + minutes(for: shift)
        }

        let futureMinutes = inPeriod.reduce(0) { total, shift in
            guard shift.status == .scheduled else { return total }
            return total + minutes(for: shift)
        }

        let projectedMinutes = completedMinutes + inProgressMinutes + futureMinutes
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
            message = "On pace to stay within your threshold."
        case .approaching:
            message = String(format: "Approaching overtime. Only %.1f hours remaining.", remaining)
        case .exceeded:
            message = "Projected to exceed your overtime threshold."
        }

        return OvertimeForecast(
            projectedHours: projectedHours,
            thresholdHours: thresholdHours,
            remainingHours: remaining,
            status: status,
            message: message
        )
    }

    private func minutes(for shift: Shift) -> Int {
        if shift.paidMinutes > 0 {
            return shift.paidMinutes
        }
        return max(0, shift.effectiveDurationMinutes - shift.breakMinutes)
    }
}
