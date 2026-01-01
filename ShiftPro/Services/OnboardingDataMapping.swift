import Foundation

extension OnboardingData {
    var payPeriodType: PayPeriodType {
        switch payPeriod {
        case .weekly:
            return .weekly
        case .biweekly:
            return .biweekly
        case .monthly:
            return .monthly
        }
    }

    var regularHoursPerPay: Int {
        let hours = max(0, Int(regularHours))
        switch payPeriod {
        case .weekly:
            return hours
        case .biweekly:
            return hours * 2
        case .monthly:
            return hours * 4
        }
    }

    var baseRateCents: Int64? {
        guard baseRate > 0 else { return nil }
        return Int64((baseRate * 100).rounded())
    }

    func apply(to profile: UserProfile) {
        profile.employeeId = employeeId.isEmpty ? nil : employeeId
        profile.workplace = workplace.isEmpty ? nil : workplace
        profile.jobTitle = jobTitle.isEmpty ? nil : jobTitle
        profile.startDate = startDate
        profile.regularHoursPerPay = regularHoursPerPay
        profile.payPeriodType = payPeriodType
        profile.baseRateCents = baseRateCents
        profile.markUpdated()
    }

    func makeProfile() -> UserProfile {
        let profile = UserProfile()
        apply(to: profile)
        return profile
    }

    func makeNotificationSettings(owner: UserProfile?) -> NotificationSettings {
        let settings = NotificationSettings(owner: owner)
        if !wantsNotifications {
            settings.shiftStartReminderEnabled = false
            settings.shiftEndSummaryEnabled = false
            settings.overtimeWarningEnabled = false
            settings.weeklySummaryEnabled = false
        }
        settings.markUpdated()
        return settings
    }

    func calendarSyncSettings() -> CalendarSyncSettings {
        var settings = CalendarSyncSettings.load()
        settings.isEnabled = wantsCalendarSync
        return settings
    }

    func selectedPatternDefinition() -> PatternDefinition {
        switch selectedPattern {
        case .eightHour:
            return PatternTemplates.weeklyNineToFive
        case .twelveHour:
            return PatternTemplates.continental
        case .fourOnFourOff:
            return PatternTemplates.fourOnFourOff
        case .pitman:
            return PatternTemplates.pitman
        }
    }
}
