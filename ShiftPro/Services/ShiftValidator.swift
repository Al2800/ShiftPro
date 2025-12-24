import Foundation
import SwiftData

struct ValidationResult {
    let errors: [Error]
    var isValid: Bool { errors.isEmpty }
}

enum ShiftValidationError: LocalizedError {
    case overlappingShift
    case invalidDuration
    case invalidBreak
    case invalidRateMultiplier
    case invalidClockTimes
    case inactivePattern

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
        case .invalidClockTimes:
            return "Clock times are invalid."
        case .inactivePattern:
            return "Shift pattern is inactive."
        }
    }
}

@MainActor
final class ShiftValidator {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func validate(_ shift: Shift) async -> ValidationResult {
        var errors: [Error] = []

        if !isValidDuration(shift) {
            errors.append(ShiftValidationError.invalidDuration)
        }

        if !isValidBreak(shift) {
            errors.append(ShiftValidationError.invalidBreak)
        }

        if !isValidRate(shift) {
            errors.append(ShiftValidationError.invalidRateMultiplier)
        }

        let conflicts = await hasConflicts(
            start: shift.scheduledStart,
            end: shift.scheduledEnd,
            owner: shift.owner,
            excludingShiftId: shift.id
        )
        if conflicts {
            errors.append(ShiftValidationError.overlappingShift)
        }

        return ValidationResult(errors: errors)
    }

    func validatePatternShift(pattern: ShiftPattern, on date: Date) -> ValidationResult {
        guard pattern.deletedAt == nil, pattern.isActive else {
            return ValidationResult(errors: [ShiftValidationError.inactivePattern])
        }

        if pattern.scheduleType == .weekly {
            let weekday = Calendar.current.component(.weekday, from: date)
            let day = Weekday(rawValue: weekday)
            if let day, !pattern.includesWeekday(day) {
                return ValidationResult(errors: [ShiftValidationError.invalidDuration])
            }
        }

        return ValidationResult(errors: [])
    }

    func validateClockTimes(shift: Shift, clockIn: Date?, clockOut: Date? = nil) -> ValidationResult {
        guard let clockIn else {
            return ValidationResult(errors: [ShiftValidationError.invalidClockTimes])
        }
        if let clockOut, clockOut < clockIn {
            return ValidationResult(errors: [ShiftValidationError.invalidClockTimes])
        }
        return ValidationResult(errors: [])
    }

    func hasConflicts(start: Date, end: Date, owner: UserProfile?, excludingShiftId: UUID? = nil) async -> Bool {
        guard let owner else { return false }
        let predicate = #Predicate<Shift> { shift in
            shift.owner?.id == owner.id &&
            shift.deletedAt == nil &&
            shift.scheduledStart < end &&
            shift.scheduledEnd > start
        }
        let descriptor = FetchDescriptor<Shift>(predicate: predicate)
        guard let conflict = try? context.fetch(descriptor).first else { return false }
        if let excludingShiftId, conflict.id == excludingShiftId {
            return false
        }
        return true
    }

    private func isValidDuration(_ shift: Shift, maximumHours: Int = 24) -> Bool {
        let minutes = shift.scheduledDurationMinutes
        return minutes > 0 && minutes <= maximumHours * 60
    }

    private func isValidBreak(_ shift: Shift) -> Bool {
        shift.breakMinutes >= 0 && shift.breakMinutes < shift.scheduledDurationMinutes
    }

    private func isValidRate(_ shift: Shift) -> Bool {
        shift.rateMultiplier >= 1.0 && shift.rateMultiplier <= 2.0
    }
}
