import AppIntents
import SwiftData

// MARK: - Clock In Intent

struct ClockInShiftIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Shift"
    static var description = IntentDescription("Clock in to start your scheduled shift")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ShiftIntentDataProvider.shared
        
        guard let shift = try await context.findScheduledShift() else {
            return .result(dialog: "You don't have a shift scheduled right now. Would you like to add one?")
        }
        
        if let currentShift = try await context.getCurrentShift() {
            return .result(dialog: "You're already clocked in to \(currentShift.title). End that shift first before starting another.")
        }
        
        try await context.clockIn(shift: shift)
        
        let timeRange = formatTimeRange(start: shift.scheduledStart, end: shift.scheduledEnd)
        return .result(dialog: "Started your shift. You're now clocked in for \(shift.title), \(timeRange). Have a good shift!")
    }
    
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) to \(formatter.string(from: end))"
    }
}

// MARK: - Clock Out Intent

struct ClockOutShiftIntent: AppIntent {
    static var title: LocalizedStringResource = "End Shift"
    static var description = IntentDescription("Clock out to end your current shift")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Confirm End Shift", default: true)
    var confirmEnd: Bool
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ShiftIntentDataProvider.shared
        
        guard let shift = try await context.getCurrentShift() else {
            return .result(dialog: "You're not currently clocked in to any shift.")
        }
        
        let hours = try await context.clockOut(shift: shift)
        let hoursFormatted = String(format: "%.1f", hours)
        
        return .result(dialog: "Shift ended. You worked \(hoursFormatted) hours on \(shift.title). Great work today!")
    }
}

// MARK: - Log Break Intent

struct LogBreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Break"
    static var description = IntentDescription("Log a break during your current shift")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Duration (minutes)", default: 30)
    var durationMinutes: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\.$durationMinutes) minute break")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ShiftIntentDataProvider.shared
        
        guard let shift = try await context.getCurrentShift() else {
            return .result(dialog: "You're not currently clocked in. Start a shift first to log breaks.")
        }
        
        try await context.logBreak(shift: shift, minutes: durationMinutes)
        
        return .result(dialog: "Logged a \(durationMinutes) minute break. Enjoy your break!")
    }
}

// MARK: - Add Overtime Intent

struct AddOvertimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Overtime"
    static var description = IntentDescription("Add overtime hours to your current shift")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Hours", default: 1.0)
    var hours: Double
    
    @Parameter(title: "Rate Multiplier", default: 1.5)
    var rateMultiplier: Double
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$hours) hours of overtime at \(\.$rateMultiplier)x rate")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ShiftIntentDataProvider.shared
        
        guard let shift = try await context.getCurrentShift() else {
            return .result(dialog: "You're not currently clocked in. Start a shift to add overtime.")
        }
        
        try await context.addOvertime(shift: shift, hours: hours, multiplier: rateMultiplier)
        
        let hoursFormatted = String(format: "%.1f", hours)
        let rateFormatted = String(format: "%.1fx", rateMultiplier)
        
        return .result(dialog: "Added \(hoursFormatted) hours of overtime at \(rateFormatted) rate.")
    }
}

// MARK: - Shift Control Shortcuts Provider

struct ShiftControlShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ClockInShiftIntent(),
            phrases: [
                "Start my shift in \(.applicationName)",
                "Clock in to \(.applicationName)",
                "Begin my shift",
                "Start work in \(.applicationName)"
            ],
            shortTitle: "Start Shift",
            systemImageName: "play.circle.fill"
        )
        
        AppShortcut(
            intent: ClockOutShiftIntent(),
            phrases: [
                "End my shift in \(.applicationName)",
                "Clock out of \(.applicationName)",
                "Finish my shift",
                "Stop work in \(.applicationName)"
            ],
            shortTitle: "End Shift",
            systemImageName: "stop.circle.fill"
        )
        
        AppShortcut(
            intent: LogBreakIntent(),
            phrases: [
                "Log a break in \(.applicationName)",
                "Take a break in \(.applicationName)",
                "Add break time"
            ],
            shortTitle: "Log Break",
            systemImageName: "cup.and.saucer.fill"
        )
        
        AppShortcut(
            intent: AddOvertimeIntent(),
            phrases: [
                "Add overtime in \(.applicationName)",
                "Log overtime hours",
                "Add extra hours"
            ],
            shortTitle: "Add Overtime",
            systemImageName: "clock.badge.checkmark.fill"
        )
    }
}
