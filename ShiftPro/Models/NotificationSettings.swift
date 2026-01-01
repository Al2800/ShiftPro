import Foundation
import SwiftData

@Model
final class NotificationSettings {
    @Attribute(.unique) var id: UUID

    var shiftStartReminderEnabled: Bool
    var shiftStartReminderMinutes: Int
    var shiftEndSummaryEnabled: Bool
    var overtimeWarningEnabled: Bool
    var overtimeWarningThresholdHours: Double
    var weeklySummaryEnabled: Bool
    var quietHoursStartMinutes: Int
    var quietHoursEndMinutes: Int
    var createdAt: Date
    var updatedAt: Date
    var lastScheduledAt: Date?

    @Relationship(deleteRule: .nullify)
    var owner: UserProfile?

    init(
        id: UUID = UUID(),
        shiftStartReminderEnabled: Bool = true,
        shiftStartReminderMinutes: Int = 60,
        shiftEndSummaryEnabled: Bool = true,
        overtimeWarningEnabled: Bool = true,
        overtimeWarningThresholdHours: Double = 35,
        weeklySummaryEnabled: Bool = true,
        quietHoursStartMinutes: Int = 22 * 60,
        quietHoursEndMinutes: Int = 6 * 60,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastScheduledAt: Date? = nil,
        owner: UserProfile? = nil
    ) {
        self.id = id
        self.shiftStartReminderEnabled = shiftStartReminderEnabled
        self.shiftStartReminderMinutes = shiftStartReminderMinutes
        self.shiftEndSummaryEnabled = shiftEndSummaryEnabled
        self.overtimeWarningEnabled = overtimeWarningEnabled
        self.overtimeWarningThresholdHours = overtimeWarningThresholdHours
        self.weeklySummaryEnabled = weeklySummaryEnabled
        self.quietHoursStartMinutes = quietHoursStartMinutes
        self.quietHoursEndMinutes = quietHoursEndMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastScheduledAt = lastScheduledAt
        self.owner = owner
    }
}

extension NotificationSettings {
    var quietHoursStart: DateComponents {
        DateComponents(hour: quietHoursStartMinutes / 60, minute: quietHoursStartMinutes % 60)
    }

    var quietHoursEnd: DateComponents {
        DateComponents(hour: quietHoursEndMinutes / 60, minute: quietHoursEndMinutes % 60)
    }

    
    /// Whether notifications are enabled overall
    var isEnabled: Bool {
        shiftStartReminderEnabled || shiftEndSummaryEnabled || weeklySummaryEnabled
    }

    /// Alias for shiftEndSummaryEnabled
    var endReminderEnabled: Bool { shiftEndSummaryEnabled }

    /// Alias for shiftStartReminderMinutes
    var startReminderMinutes: Int { shiftStartReminderMinutes }

    /// Weekly summary weekday (default to Sunday = 1)
    var weeklySummaryWeekday: Int { 1 }

    /// Weekly summary hour (default to 9 AM)
    var weeklySummaryHour: Int { 9 }

    /// Whether quiet hours are enabled (always true if hours are set)
    var quietHoursEnabled: Bool { true }

    /// Quiet hours start hour
    var quietHoursStartHour: Int { quietHoursStartMinutes / 60 }

    /// Quiet hours end hour
    var quietHoursEndHour: Int { quietHoursEndMinutes / 60 }

    /// Static load method for compatibility
    static func load() -> NotificationSettings {
        // Return default settings - actual loading happens via SwiftData
        NotificationSettings()
    }

    func markUpdated() {
        updatedAt = Date()
    }
}
