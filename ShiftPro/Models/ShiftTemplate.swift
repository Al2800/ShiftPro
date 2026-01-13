import Foundation
import SwiftUI

/// A reusable shift type template for the pattern builder.
/// Represents a type of shift (Early, Late, Night, etc.) with timing and visual properties.
struct ShiftTemplate: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var shortCode: String  // Single letter for calendar display
    var startMinuteOfDay: Int  // Minutes since midnight
    var durationMinutes: Int
    var colorHex: String
    var icon: String  // SF Symbol name

    init(
        id: UUID = UUID(),
        name: String,
        shortCode: String,
        startMinuteOfDay: Int,
        durationMinutes: Int,
        colorHex: String,
        icon: String = "briefcase.fill"
    ) {
        self.id = id
        self.name = name
        self.shortCode = String(shortCode.prefix(1)).uppercased()
        self.startMinuteOfDay = startMinuteOfDay
        self.durationMinutes = durationMinutes
        self.colorHex = colorHex
        self.icon = icon
    }

    // MARK: - Computed Properties

    var startTimeFormatted: String {
        let hours = startMinuteOfDay / 60
        let minutes = startMinuteOfDay % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    var endMinuteOfDay: Int {
        (startMinuteOfDay + durationMinutes) % 1440
    }

    var endTimeFormatted: String {
        let hours = endMinuteOfDay / 60
        let minutes = endMinuteOfDay % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    var timeRangeFormatted: String {
        "\(startTimeFormatted) - \(endTimeFormatted)"
    }

    var durationHours: Double {
        Double(durationMinutes) / 60.0
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    // MARK: - Preset Templates

    /// Off day - special template
    static let off = ShiftTemplate(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: "Off",
        shortCode: "·",
        startMinuteOfDay: 0,
        durationMinutes: 0,
        colorHex: "#4A4A4A",
        icon: "moon.zzz.fill"
    )

    /// Early shift (6:00 - 14:00)
    static let early = ShiftTemplate(
        name: "Early",
        shortCode: "E",
        startMinuteOfDay: 6 * 60,  // 06:00
        durationMinutes: 8 * 60,   // 8 hours
        colorHex: "#34C759",       // Green
        icon: "sunrise.fill"
    )

    /// Late shift (14:00 - 22:00)
    static let late = ShiftTemplate(
        name: "Late",
        shortCode: "L",
        startMinuteOfDay: 14 * 60, // 14:00
        durationMinutes: 8 * 60,   // 8 hours
        colorHex: "#FF9500",       // Orange
        icon: "sunset.fill"
    )

    /// Night shift (22:00 - 06:00)
    static let night = ShiftTemplate(
        name: "Night",
        shortCode: "N",
        startMinuteOfDay: 22 * 60, // 22:00
        durationMinutes: 8 * 60,   // 8 hours
        colorHex: "#5856D6",       // Purple
        icon: "moon.stars.fill"
    )

    /// Day shift (9:00 - 17:00)
    static let day = ShiftTemplate(
        name: "Day",
        shortCode: "D",
        startMinuteOfDay: 9 * 60,  // 09:00
        durationMinutes: 8 * 60,   // 8 hours
        colorHex: "#007AFF",       // Blue
        icon: "sun.max.fill"
    )

    /// Long shift (7:00 - 19:00, 12 hours)
    static let long = ShiftTemplate(
        name: "Long",
        shortCode: "W",
        startMinuteOfDay: 7 * 60,  // 07:00
        durationMinutes: 12 * 60,  // 12 hours
        colorHex: "#FF2D55",       // Pink/Red
        icon: "clock.fill"
    )

    /// Default set of shift templates
    static let defaults: [ShiftTemplate] = [
        .early,
        .late,
        .night,
        .day,
        .long
    ]

    /// All available colors for shift templates
    static let availableColors: [String] = [
        "#34C759", // Green
        "#007AFF", // Blue
        "#FF9500", // Orange
        "#5856D6", // Purple
        "#FF2D55", // Pink
        "#00C7BE", // Teal
        "#FF3B30", // Red
        "#FFCC00", // Yellow
        "#AF52DE", // Violet
        "#32ADE6"  // Cyan
    ]

    /// All available icons for shift templates
    static let availableIcons: [String] = [
        "sunrise.fill",
        "sun.max.fill",
        "sunset.fill",
        "moon.stars.fill",
        "moon.zzz.fill",
        "clock.fill",
        "briefcase.fill",
        "building.2.fill",
        "cross.fill",
        "stethoscope"
    ]
}

// MARK: - Day Assignment

/// Represents what shift type is assigned to a specific day in the pattern
struct DayAssignment: Identifiable, Equatable {
    let id: UUID
    let dayIndex: Int
    var template: ShiftTemplate?  // nil = Off

    var isOff: Bool {
        template == nil || template?.id == ShiftTemplate.off.id
    }

    var isWorkDay: Bool {
        !isOff
    }

    static func off(dayIndex: Int) -> DayAssignment {
        DayAssignment(id: UUID(), dayIndex: dayIndex, template: nil)
    }

    static func work(dayIndex: Int, template: ShiftTemplate) -> DayAssignment {
        DayAssignment(id: UUID(), dayIndex: dayIndex, template: template)
    }
}
