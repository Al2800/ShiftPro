import Foundation
import SwiftData

/// Represents a single day in a cycling rotation pattern.
/// Used for patterns like 4-on/4-off, Pitman schedule, etc.
@Model
final class RotationDay {
    // MARK: - Primary Key
    @Attribute(.unique) var id: UUID

    // MARK: - Configuration
    /// Day index within the cycle (0-based)
    var index: Int

    /// Whether this is a work day or off day
    var isWorkDay: Bool

    /// Optional shift name for this day (e.g., "Day Shift", "Night Shift")
    var shiftName: String?

    /// Start time override as minutes since midnight (nil = use pattern default)
    var startMinuteOfDay: Int?

    /// Duration override in minutes (nil = use pattern default)
    var durationMinutes: Int?

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var pattern: ShiftPattern?

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        index: Int,
        isWorkDay: Bool,
        shiftName: String? = nil,
        startMinuteOfDay: Int? = nil,
        durationMinutes: Int? = nil,
        pattern: ShiftPattern? = nil
    ) {
        self.id = id
        self.index = index
        self.isWorkDay = isWorkDay
        self.shiftName = shiftName
        self.startMinuteOfDay = startMinuteOfDay
        self.durationMinutes = durationMinutes
        self.pattern = pattern
    }
}

// MARK: - Computed Properties
extension RotationDay {
    /// Start time formatted as HH:mm, or nil if using pattern default
    var startTimeFormatted: String? {
        guard let minutes = startMinuteOfDay else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }

    /// Duration formatted, or nil if using pattern default
    var durationFormatted: String? {
        guard let minutes = durationMinutes else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }

    /// Day label for display (e.g., "Day 1", "Day 2")
    var dayLabel: String {
        "Day \(index + 1)"
    }

    /// Summary for display (e.g., "Day 1: Work (Day Shift)")
    var summary: String {
        var result = dayLabel
        result += isWorkDay ? ": Work" : ": Off"
        if let name = shiftName, !name.isEmpty {
            result += " (\(name))"
        }
        return result
    }

    /// Effective start time (own or pattern default)
    func effectiveStartMinute(fallback: Int) -> Int {
        startMinuteOfDay ?? fallback
    }

    /// Effective duration (own or pattern default)
    func effectiveDuration(fallback: Int) -> Int {
        durationMinutes ?? fallback
    }
}

// MARK: - Factory Methods
extension RotationDay {
    /// Creates a work day
    static func workDay(
        index: Int,
        shiftName: String? = nil,
        startMinuteOfDay: Int? = nil,
        durationMinutes: Int? = nil
    ) -> RotationDay {
        RotationDay(
            index: index,
            isWorkDay: true,
            shiftName: shiftName,
            startMinuteOfDay: startMinuteOfDay,
            durationMinutes: durationMinutes
        )
    }

    /// Creates an off day
    static func offDay(index: Int) -> RotationDay {
        RotationDay(
            index: index,
            isWorkDay: false
        )
    }

    /// Creates a 4-on-4-off rotation (8 days total)
    static func fourOnFourOff() -> [RotationDay] {
        var days: [RotationDay] = []
        for index in 0..<4 {
            days.append(.workDay(index: index))
        }
        for index in 4..<8 {
            days.append(.offDay(index: index))
        }
        return days
    }

    /// Creates a Pitman schedule (2 weeks rotation)
    static func pitmanSchedule() -> [RotationDay] {
        // Week 1: 2 on, 2 off, 3 on
        // Week 2: 2 off, 2 on, 3 off
        let pattern = [true, true, false, false, true, true, true,
                      false, false, true, true, false, false, false]
        return pattern.enumerated().map { index, isWork in
            RotationDay(index: index, isWorkDay: isWork)
        }
    }
}
