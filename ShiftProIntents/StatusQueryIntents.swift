import AppIntents
import SwiftData

// MARK: - Hours This Week Intent

struct HoursThisWeekIntent: AppIntent {
    static var title: LocalizedStringResource = "Hours This Week"
    static var description = IntentDescription("Check how many hours you've worked this week")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ShiftIntentDataProvider.shared
        let hours = try await context.getWeeklyHours()
        
        let hoursFormatted = String(format: "%.1f", hours.total)
        let regularFormatted = String(format: "%.1f", hours.regular)
        let premiumFormatted = String(format: "%.1f", hours.premium)
        
        if hours.premium > 0 {
            return .result(dialog: "This week you've worked \(hoursFormatted) hours total: \(regularFormatted) regular hours and \(premiumFormatted) premium hours.")
        } else {
            return .result(dialog: "This week you've worked \(hoursFormatted) hours.")
        }
    }
}

// MARK: - Next Shift Intent

struct NextShiftIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Shift"
    static var description = IntentDescription("Check when your next shift is scheduled")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ShiftIntentDataProvider.shared
        
        if let current = try await context.getCurrentShift() {
            let remaining = current.remainingFormatted
            return .result(dialog: "You're currently on shift. \(remaining) remaining until \(formatTime(current.scheduledEnd)).")
        }
        
        guard let nextShift = try await context.getNextShift() else {
            return .result(dialog: "You don't have any upcoming shifts scheduled.")
        }
        
        let countdown = nextShift.countdownFormatted
        let date = formatDate(nextShift.scheduledStart)
        let time = formatTimeRange(start: nextShift.scheduledStart, end: nextShift.scheduledEnd)
        
        return .result(dialog: "Your next shift is \(nextShift.title) on \(date), \(time). That's \(countdown).")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) to \(formatter.string(from: end))"
    }
}

// MARK: - Pay Period Summary Intent

struct PayPeriodSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Pay Period Summary"
    static var description = IntentDescription("Get a summary of your current pay period")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ShiftIntentDataProvider.shared
        let summary = try await context.getPayPeriodSummary()
        
        let totalFormatted = String(format: "%.1f", summary.totalHours)
        let targetFormatted = String(format: "%.0f", summary.targetHours)
        let progressPercent = Int(summary.progress * 100)
        
        var response = "This pay period you've worked \(totalFormatted) of \(targetFormatted) target hours, that's \(progressPercent)% complete."
        
        if summary.estimatedPay > 0 {
            let payFormatted = String(format: "$%.2f", summary.estimatedPay)
            response += " Estimated earnings: \(payFormatted)."
        }
        
        if summary.overtimeHours > 0 {
            let overtimeFormatted = String(format: "%.1f", summary.overtimeHours)
            response += " Including \(overtimeFormatted) overtime hours."
        }
        
        return .result(dialog: response)
    }
}

// MARK: - Shift Status Intent

struct ShiftStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Shift Status"
    static var description = IntentDescription("Check if you're currently on shift")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ShiftIntentDataProvider.shared
        
        if let shift = try await context.getCurrentShift() {
            let elapsed = shift.elapsedFormatted
            let remaining = shift.remainingFormatted
            
            return .result(dialog: "You're currently on \(shift.title). You've been on shift for \(elapsed) with \(remaining) remaining.")
        } else {
            return .result(dialog: "You're not currently on shift.")
        }
    }
}

// MARK: - Overtime Summary Intent

struct OvertimeSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Overtime Summary"
    static var description = IntentDescription("Check your overtime hours this period")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ShiftIntentDataProvider.shared
        let overtime = try await context.getOvertimeSummary()
        
        if overtime.totalHours == 0 {
            return .result(dialog: "You haven't logged any overtime this pay period.")
        }
        
        let hoursFormatted = String(format: "%.1f", overtime.totalHours)
        let earningsFormatted = String(format: "$%.2f", overtime.estimatedEarnings)
        
        return .result(dialog: "This pay period you have \(hoursFormatted) overtime hours, worth approximately \(earningsFormatted).")
    }
}

// MARK: - Status Query Shortcuts Provider

struct StatusQueryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: HoursThisWeekIntent(),
            phrases: [
                "How many hours this week in \(.applicationName)",
                "Check my hours in \(.applicationName)",
                "What are my hours this week",
                "Hours worked this week"
            ],
            shortTitle: "Weekly Hours",
            systemImageName: "clock.fill"
        )
        
        AppShortcut(
            intent: NextShiftIntent(),
            phrases: [
                "When is my next shift in \(.applicationName)",
                "What's my next shift",
                "Check my schedule in \(.applicationName)",
                "When do I work next"
            ],
            shortTitle: "Next Shift",
            systemImageName: "calendar"
        )
        
        AppShortcut(
            intent: PayPeriodSummaryIntent(),
            phrases: [
                "Pay period summary in \(.applicationName)",
                "How much have I earned",
                "Check my pay in \(.applicationName)",
                "Earnings this period"
            ],
            shortTitle: "Pay Summary",
            systemImageName: "dollarsign.circle.fill"
        )
        
        AppShortcut(
            intent: ShiftStatusIntent(),
            phrases: [
                "Am I on shift in \(.applicationName)",
                "Check shift status",
                "What's my shift status"
            ],
            shortTitle: "Shift Status",
            systemImageName: "person.badge.clock.fill"
        )
        
        AppShortcut(
            intent: OvertimeSummaryIntent(),
            phrases: [
                "Show my overtime in \(.applicationName)",
                "How much overtime do I have",
                "Check overtime hours"
            ],
            shortTitle: "Overtime",
            systemImageName: "clock.badge.checkmark.fill"
        )
    }
}
