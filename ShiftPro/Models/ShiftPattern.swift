import Foundation
import SwiftData

/// A reusable shift pattern template defining when shifts occur.
/// Supports both weekly (same days each week) and cycling (rotating) patterns.
@Model
final class ShiftPattern {
    // MARK: - Primary Key
    @Attribute(.unique) var id: UUID

    // MARK: - Pattern Information
    var name: String
    var notes: String?

    /// Raw value for ScheduleType enum (weekly or cycling)
    var scheduleTypeRaw: Int16

    // MARK: - Timing Configuration
    /// Start time as minutes since midnight (0-1439)
    var startMinuteOfDay: Int
    /// Duration in minutes
    var durationMinutes: Int

    // MARK: - Weekly Pattern Configuration
    /// Bitmask for days of the week (used for weekly patterns)
    /// Bit 0 = Sunday, Bit 1 = Monday, etc.
    var daysOfWeekMask: Int16

    // MARK: - Cycling Pattern Configuration
    /// Start date for cycling patterns
    var cycleStartDate: Date?

    // MARK: - Status
    var isActive: Bool
    /// Hex color code for UI display (e.g., "#FF5733")
    var colorHex: String
    /// System patterns are pre-defined and cannot be deleted
    var isSystem: Bool

    // MARK: - Timestamps
    var createdAt: Date
    /// Soft delete timestamp (nil = not deleted)
    var deletedAt: Date?

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var owner: UserProfile?

    @Relationship(deleteRule: .nullify, inverse: \Shift.pattern)
    var shifts: [Shift] = []

    @Relationship(deleteRule: .cascade, inverse: \RotationDay.pattern)
    var rotationDays: [RotationDay] = []

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        scheduleType: ScheduleType = .weekly,
        startMinuteOfDay: Int = 540, // 9:00 AM default
        durationMinutes: Int = 480,  // 8 hours default
        daysOfWeekMask: Int16 = 0b0111110, // Mon-Fri default
        cycleStartDate: Date? = nil,
        isActive: Bool = true,
        colorHex: String = "#007AFF",
        isSystem: Bool = false,
        createdAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.scheduleTypeRaw = scheduleType.rawValue
        self.startMinuteOfDay = startMinuteOfDay
        self.durationMinutes = durationMinutes
        self.daysOfWeekMask = daysOfWeekMask
        self.cycleStartDate = cycleStartDate
        self.isActive = isActive
        self.colorHex = colorHex
        self.isSystem = isSystem
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

// MARK: - Computed Properties
extension ShiftPattern {
    /// The schedule type enum value
    var scheduleType: ScheduleType {
        get { ScheduleType(rawValue: scheduleTypeRaw) ?? .weekly }
        set { scheduleTypeRaw = newValue.rawValue }
    }

    /// Start time as a formatted string (e.g., "09:00")
    var startTimeFormatted: String {
        let hours = startMinuteOfDay / 60
        let minutes = startMinuteOfDay % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    /// End time as minutes since midnight
    var endMinuteOfDay: Int {
        (startMinuteOfDay + durationMinutes) % 1440
    }

    /// End time as a formatted string
    var endTimeFormatted: String {
        let hours = endMinuteOfDay / 60
        let minutes = endMinuteOfDay % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    /// Duration in hours (with decimal)
    var durationHours: Double {
        Double(durationMinutes) / 60.0
    }

    /// Time range display string (e.g., "09:00 - 17:00")
    var timeRangeFormatted: String {
        "\(startTimeFormatted) - \(endTimeFormatted)"
    }

    /// Whether this pattern spans overnight
    var isOvernightShift: Bool {
        endMinuteOfDay < startMinuteOfDay
    }

    /// Days of the week for this pattern (weekly type)
    var weekdays: [Weekday] {
        daysOfWeekMask.weekdays
    }

    /// Sets the weekdays for this pattern
    func setWeekdays(_ days: [Weekday]) {
        daysOfWeekMask = .mask(from: days)
    }

    /// Whether this pattern is deleted
    var isDeleted: Bool {
        deletedAt != nil
    }

    /// Cycle length in days (for cycling patterns)
    var cycleLengthDays: Int {
        rotationDays.count
    }

    /// Sorted rotation days (for cycling patterns)
    var sortedRotationDays: [RotationDay] {
        rotationDays.sorted { $0.index < $1.index }
    }

    /// Active shifts for this pattern (not deleted)
    var activeShifts: [Shift] {
        shifts.filter { $0.deletedAt == nil }
    }
}

// MARK: - Convenience Methods
extension ShiftPattern {
    /// Soft deletes this pattern
    func softDelete() {
        deletedAt = Date()
        isActive = false
    }

    /// Restores a soft-deleted pattern
    func restore() {
        deletedAt = nil
    }

    /// Creates a Date from the start time on a given day
    func startDate(on date: Date, in calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: startMinuteOfDay, to: startOfDay) ?? date
    }

    /// Creates a Date from the end time on a given day
    func endDate(on date: Date, in calendar: Calendar = .current) -> Date {
        let start = startDate(on: date, in: calendar)
        return calendar.date(byAdding: .minute, value: durationMinutes, to: start) ?? date
    }

    /// Checks if this pattern includes a specific weekday
    func includesWeekday(_ weekday: Weekday) -> Bool {
        daysOfWeekMask.contains(weekday: weekday)
    }

    /// Gets the rotation day for a specific date (cycling patterns only)
    func rotationDay(for date: Date, in calendar: Calendar = .current) -> RotationDay? {
        guard scheduleType == .cycling,
              let cycleStart = cycleStartDate,
              !rotationDays.isEmpty else {
            return nil
        }

        let daysSinceStart = calendar.dateComponents([.day], from: cycleStart, to: date).day ?? 0
        let cycleLength = rotationDays.count
        let dayIndex = ((daysSinceStart % cycleLength) + cycleLength) % cycleLength

        return sortedRotationDays.first { $0.index == dayIndex }
    }

    /// Checks if this pattern has a shift scheduled for a specific date
    func isScheduled(on date: Date, in calendar: Calendar = .current) -> Bool {
        switch scheduleType {
        case .weekly:
            let weekdayComponent = calendar.component(.weekday, from: date)
            guard let weekday = Weekday(rawValue: weekdayComponent) else { return false }
            return includesWeekday(weekday)

        case .cycling:
            guard let rotation = rotationDay(for: date, in: calendar) else { return false }
            return rotation.isWorkDay
        }
    }
}

// MARK: - Factory Methods
extension ShiftPattern {
    /// Creates a standard 9-5 weekday pattern
    static func standard9to5(owner: UserProfile? = nil) -> ShiftPattern {
        ShiftPattern(
            name: "Standard 9-5",
            scheduleType: .weekly,
            startMinuteOfDay: 540, // 9:00 AM
            durationMinutes: 480,  // 8 hours
            daysOfWeekMask: .mask(from: [.monday, .tuesday, .wednesday, .thursday, .friday]),
            colorHex: "#007AFF",
            owner: owner
        )
    }

    /// Creates a 4-on-4-off rotating pattern template
    static func fourOnFourOff(owner: UserProfile? = nil, startHour: Int = 7) -> ShiftPattern {
        let pattern = ShiftPattern(
            name: "4 On / 4 Off",
            scheduleType: .cycling,
            startMinuteOfDay: startHour * 60,
            durationMinutes: 720, // 12 hours
            cycleStartDate: Date(),
            colorHex: "#FF9500",
            owner: owner
        )
        // Rotation days would be added separately
        return pattern
    }
}
