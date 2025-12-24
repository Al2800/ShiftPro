import Foundation

struct PatternValidationResult {
    let errors: [String]
    var isValid: Bool { errors.isEmpty }
}

final class PatternEngine {
    func validate(_ definition: PatternDefinition) -> PatternValidationResult {
        var errors: [String] = []

        if definition.durationMinutes <= 0 || definition.durationMinutes > 24 * 60 {
            errors.append("Shift duration must be between 1 and 24 hours.")
        }

        if definition.kind == .weekly && definition.weekdays.isEmpty {
            errors.append("Weekly patterns must include at least one weekday.")
        }

        if definition.kind == .rotating && definition.rotationDays.isEmpty {
            errors.append("Rotating patterns must define cycle days.")
        }

        return PatternValidationResult(errors: errors)
    }

    func buildPattern(from definition: PatternDefinition, owner: UserProfile? = nil) -> ShiftPattern {
        let pattern = ShiftPattern(
            name: definition.name,
            notes: definition.notes,
            scheduleType: definition.kind == .weekly ? .weekly : .cycling,
            startMinuteOfDay: definition.startMinuteOfDay,
            durationMinutes: definition.durationMinutes,
            daysOfWeekMask: Int16.mask(from: definition.weekdays),
            cycleStartDate: Date(),
            isActive: true,
            colorHex: "#007AFF",
            isSystem: false
        )
        pattern.owner = owner

        if definition.kind == .rotating {
            let rotationDays = definition.rotationDays.map { day in
                RotationDay(
                    index: day.index,
                    isWorkDay: day.isWorkDay,
                    shiftName: day.shiftName,
                    startMinuteOfDay: day.startMinuteOfDay,
                    durationMinutes: day.durationMinutes,
                    pattern: pattern
                )
            }
            pattern.rotationDays = rotationDays
        }

        return pattern
    }

    func preview(
        definition: PatternDefinition,
        startDate: Date,
        months: Int = 1
    ) -> [ShiftPreview] {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: months, to: startDate) ?? startDate
        return preview(definition: definition, from: startDate, to: endDate)
    }

    func preview(
        definition: PatternDefinition,
        from startDate: Date,
        to endDate: Date
    ) -> [ShiftPreview] {
        let dates = DateMath.dates(from: startDate, to: endDate)
        var previews: [ShiftPreview] = []

        switch definition.kind {
        case .weekly:
            for date in dates {
                let weekday = Weekday(rawValue: Calendar.current.component(.weekday, from: date))
                guard let weekday, definition.weekdays.contains(weekday) else { continue }
                let start = DateMath.date(for: date, atMinute: definition.startMinuteOfDay)
                let end = DateMath.addMinutes(definition.durationMinutes, to: start)
                previews.append(ShiftPreview(
                    date: date,
                    title: definition.name,
                    start: start,
                    end: end,
                    isWorkDay: true
                ))
            }
        case .rotating:
            guard !definition.rotationDays.isEmpty else { return [] }
            for date in dates {
                let index = DateMath.daysBetween(startDate, date) % definition.rotationDays.count
                let day = definition.rotationDays[index]
                guard day.isWorkDay else { continue }
                let startMinute = day.startMinuteOfDay ?? definition.startMinuteOfDay
                let duration = day.durationMinutes ?? definition.durationMinutes
                let start = DateMath.date(for: date, atMinute: startMinute)
                let end = DateMath.addMinutes(duration, to: start)
                previews.append(ShiftPreview(
                    date: date,
                    title: day.shiftName ?? definition.name,
                    start: start,
                    end: end,
                    isWorkDay: true
                ))
            }
        }

        return previews
    }

    func generateShifts(
        for pattern: ShiftPattern,
        from startDate: Date,
        to endDate: Date,
        owner: UserProfile? = nil
    ) -> [Shift] {
        let dates = DateMath.dates(from: startDate, to: endDate)
        var shifts: [Shift] = []

        switch pattern.scheduleType {
        case .weekly:
            for date in dates {
                let weekday = Weekday(rawValue: Calendar.current.component(.weekday, from: date))
                guard let weekday, pattern.includesWeekday(weekday) else { continue }
                let shift = Shift.fromPattern(pattern, on: date, owner: owner)
                shifts.append(shift)
            }
        case .cycling:
            let rotation = pattern.sortedRotationDays
            guard !rotation.isEmpty else { return [] }
            let cycleStart = pattern.cycleStartDate ?? startDate
            for date in dates {
                let dayIndex = DateMath.daysBetween(cycleStart, date)
                let rotationIndex = (dayIndex % rotation.count + rotation.count) % rotation.count
                let rotationDay = rotation[rotationIndex]
                guard rotationDay.isWorkDay else { continue }

                let startMinute = rotationDay.effectiveStartMinute(fallback: pattern.startMinuteOfDay)
                let duration = rotationDay.effectiveDuration(fallback: pattern.durationMinutes)
                let start = DateMath.date(for: date, atMinute: startMinute)
                let end = DateMath.addMinutes(duration, to: start)

                let shift = Shift(
                    scheduledStart: start,
                    scheduledEnd: end,
                    breakMinutes: 30,
                    notes: rotationDay.shiftName,
                    rateMultiplier: 1.0,
                    pattern: pattern,
                    owner: owner
                )
                shift.recalculatePaidMinutes()
                shifts.append(shift)
            }
        }

        return shifts
    }
}
