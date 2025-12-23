import Foundation
import UserNotifications

enum NotificationCategory: String {
    case shiftStart = "SHIFT_START"
    case shiftEnd = "SHIFT_END"
    case weeklySummary = "WEEKLY_SUMMARY"
    case overtimeWarning = "OVERTIME_WARNING"
}

enum NotificationActionIdentifier {
    static let startShift = "SHIFT_START_ACTION"
    static let completeShift = "SHIFT_COMPLETE_ACTION"
    static let snooze15 = "SHIFT_SNOOZE_15"
    static let viewSummary = "VIEW_WEEKLY_SUMMARY"
}

struct NotificationScheduler {
    static let identifierPrefix = "shiftpro."
    static let weeklySummaryIdentifier = "shiftpro.weekly.summary"
    static let overtimeWarningIdentifier = "shiftpro.overtime.warning"

    static func shiftStartIdentifier(_ id: UUID) -> String {
        "\(identifierPrefix)shift.start.\(id.uuidString)"
    }

    static func shiftEndIdentifier(_ id: UUID) -> String {
        "\(identifierPrefix)shift.end.\(id.uuidString)"
    }

    static func registerCategories(center: UNUserNotificationCenter = .current()) {
        let startShift = UNNotificationAction(
            identifier: NotificationActionIdentifier.startShift,
            title: "Start Shift",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: NotificationActionIdentifier.snooze15,
            title: "Snooze 15 min",
            options: []
        )
        let completeShift = UNNotificationAction(
            identifier: NotificationActionIdentifier.completeShift,
            title: "Mark Complete",
            options: [.foreground]
        )
        let viewSummary = UNNotificationAction(
            identifier: NotificationActionIdentifier.viewSummary,
            title: "View Summary",
            options: [.foreground]
        )

        let startCategory = UNNotificationCategory(
            identifier: NotificationCategory.shiftStart.rawValue,
            actions: [startShift, snooze],
            intentIdentifiers: [],
            options: []
        )
        let endCategory = UNNotificationCategory(
            identifier: NotificationCategory.shiftEnd.rawValue,
            actions: [completeShift],
            intentIdentifiers: [],
            options: []
        )
        let summaryCategory = UNNotificationCategory(
            identifier: NotificationCategory.weeklySummary.rawValue,
            actions: [viewSummary],
            intentIdentifiers: [],
            options: []
        )
        let overtimeCategory = UNNotificationCategory(
            identifier: NotificationCategory.overtimeWarning.rawValue,
            actions: [viewSummary],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([startCategory, endCategory, summaryCategory, overtimeCategory])
    }

    func requests(
        for shifts: [Shift],
        settings: NotificationSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []

        for shift in shifts where shift.deletedAt == nil {
            if shift.status == .scheduled {
                if let startRequest = startReminderRequest(
                    for: shift,
                    settings: settings,
                    now: now,
                    calendar: calendar
                ) {
                    requests.append(startRequest)
                }
            }

            if settings.endReminderEnabled,
               shift.status == .scheduled || shift.status == .inProgress {
                if let endRequest = endReminderRequest(
                    for: shift,
                    settings: settings,
                    now: now,
                    calendar: calendar
                ) {
                    requests.append(endRequest)
                }
            }
        }

        return requests
    }

    func startReminderRequest(
        for shift: Shift,
        settings: NotificationSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> UNNotificationRequest? {
        guard settings.isEnabled else { return nil }

        let reminderDate = calendar.date(
            byAdding: .minute,
            value: -settings.startReminderMinutes,
            to: shift.scheduledStart
        )

        guard let reminderDate else { return nil }
        let fireDate = adjustedDate(reminderDate, settings: settings, calendar: calendar)
        guard fireDate > now else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Shift starts soon"
        content.body = "\(shift.dateFormatted) • \(shift.timeRangeFormatted)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.shiftStart.rawValue
        content.userInfo = [
            "shiftID": shift.id.uuidString,
            "type": "shiftStart"
        ]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: NotificationScheduler.shiftStartIdentifier(shift.id),
            content: content,
            trigger: trigger
        )
    }

    func endReminderRequest(
        for shift: Shift,
        settings: NotificationSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> UNNotificationRequest? {
        guard settings.isEnabled else { return nil }

        let reminderDate = shift.scheduledEnd
        let fireDate = adjustedDate(reminderDate, settings: settings, calendar: calendar)
        guard fireDate > now else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Shift ending"
        content.body = "Log hours for \(shift.dateFormatted)."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.shiftEnd.rawValue
        content.userInfo = [
            "shiftID": shift.id.uuidString,
            "type": "shiftEnd"
        ]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: NotificationScheduler.shiftEndIdentifier(shift.id),
            content: content,
            trigger: trigger
        )
    }

    func weeklySummaryRequest(
        settings: NotificationSettings,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> UNNotificationRequest? {
        guard settings.isEnabled, settings.weeklySummaryEnabled else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Weekly hours summary"
        content.body = "Review your hours and upcoming shifts."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.weeklySummary.rawValue
        content.userInfo = ["type": "weeklySummary"]

        var components = DateComponents()
        components.weekday = settings.weeklySummaryWeekday
        components.hour = settings.weeklySummaryHour
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(
            identifier: NotificationScheduler.weeklySummaryIdentifier,
            content: content,
            trigger: trigger
        )
    }

    func adjustedDate(
        _ date: Date,
        settings: NotificationSettings,
        calendar: Calendar = .current
    ) -> Date {
        guard settings.quietHoursEnabled else { return date }

        let hour = calendar.component(.hour, from: date)
        let start = settings.quietHoursStartHour
        let end = settings.quietHoursEndHour
        let isQuiet: Bool

        if start < end {
            isQuiet = hour >= start && hour < end
        } else {
            isQuiet = hour >= start || hour < end
        }

        guard isQuiet else { return date }

        if start < end {
            return calendar.date(bySettingHour: end, minute: 0, second: 0, of: date) ?? date
        }

        if hour >= start {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            return calendar.date(bySettingHour: end, minute: 0, second: 0, of: nextDay) ?? date
        }

        return calendar.date(bySettingHour: end, minute: 0, second: 0, of: date) ?? date
    }
}
