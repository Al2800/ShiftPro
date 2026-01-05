import Foundation

enum PatternTemplates {
    static let weeklyNineToFive = PatternDefinition(
        name: "Weekdays 9-5",
        kind: .weekly,
        startMinuteOfDay: 9 * 60,
        durationMinutes: 8 * 60,
        weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
        notes: "Standard weekday schedule."
    )

    static let fourOnFourOff = PatternDefinition(
        name: "4-on / 4-off",
        kind: .rotating,
        startMinuteOfDay: 7 * 60,
        durationMinutes: 12 * 60,
        rotationDays: rotationPattern([true, true, true, true, false, false, false, false]),
        notes: "Common 8-day rotation with 12-hour shifts."
    )

    static let pitman = PatternDefinition(
        name: "Pitman",
        kind: .rotating,
        startMinuteOfDay: 6 * 60,
        durationMinutes: 12 * 60,
        rotationDays: rotationPattern([
            true, true, false, false, true, true, true,
            false, false, true, true, false, false, false
        ]),
        notes: "14-day Pitman rotation."
    )

    static let continental = PatternDefinition(
        name: "2-2-3 Continental",
        kind: .rotating,
        startMinuteOfDay: 7 * 60,
        durationMinutes: 12 * 60,
        rotationDays: rotationPattern([
            true, true, false, false, true, true, true,
            false, false, true, true, false, false, false
        ]),
        notes: "Popular 2-2-3 schedule with a 14-day cycle."
    )

    static let duPont = PatternDefinition(
        name: "DuPont",
        kind: .rotating,
        startMinuteOfDay: 6 * 60,
        durationMinutes: 12 * 60,
        rotationDays: rotationPattern([
            true, true, true, true, false, false, false, false,
            true, true, true, false, false, false, false, true,
            true, false, false, false, false, true, true, true,
            false, false, false, false
        ]),
        notes: "4-week DuPont rotation (simplified)."
    )

    static var all: [PatternDefinition] {
        [weeklyNineToFive, fourOnFourOff, continental]
    }

    private static func rotationPattern(_ workDays: [Bool]) -> [PatternDefinition.RotationDayDefinition] {
        workDays.enumerated().map { index, isWork in
            PatternDefinition.RotationDayDefinition(
                index: index,
                isWorkDay: isWork,
                shiftName: isWork ? "Work" : "Off"
            )
        }
    }
}
