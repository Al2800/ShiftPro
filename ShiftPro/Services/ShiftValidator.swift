import Foundation

enum ShiftValidationError: LocalizedError {
    case overlappingShift
    case invalidDuration
    case invalidBreak
    case invalidRateMultiplier

    var errorDescription: String? {
        switch self {
        case .overlappingShift:
            return "This shift overlaps with an existing shift."
        case .invalidDuration:
            return "Shift duration is invalid."
        case .invalidBreak:
            return "Break duration is invalid."
        case .invalidRateMultiplier:
            return "Rate multiplier is invalid."
        }
    }
}

struct ShiftValidator {
    static func validate(
        shift: Shift,
        against shifts: [Shift],
        maximumDurationHours: Int = 24
    ) throws {
        try validateDuration(shift, maximumHours: maximumDurationHours)
        try validateBreak(shift)
        try validateRate(shift)
        try validateNoOverlap(shift, against: shifts)
    }

    static func validateNoOverlap(_ shift: Shift, against shifts: [Shift]) throws {
        let window = DateInterval(start: shift.scheduledStart, end: shift.scheduledEnd)
        let overlaps = shifts.contains { other in
            guard other.id != shift.id, other.deletedAt == nil else { return false }
            let otherWindow = DateInterval(start: other.scheduledStart, end: other.scheduledEnd)
            return window.intersects(otherWindow)
        }
        if overlaps {
            throw ShiftValidationError.overlappingShift
        }
    }

    static func validateDuration(_ shift: Shift, maximumHours: Int) throws {
        let durationMinutes = shift.scheduledDurationMinutes
        if durationMinutes <= 0 || durationMinutes > maximumHours * 60 {
            throw ShiftValidationError.invalidDuration
        }
    }

    static func validateBreak(_ shift: Shift) throws {
        let totalMinutes = shift.scheduledDurationMinutes
        if shift.breakMinutes < 0 || shift.breakMinutes >= totalMinutes {
            throw ShiftValidationError.invalidBreak
        }
    }

    static func validateRate(_ shift: Shift) throws {
        if shift.rateMultiplier < 1.0 || shift.rateMultiplier > 2.0 {
            throw ShiftValidationError.invalidRateMultiplier
        }
    }
}
