import SwiftUI
import WidgetKit
import AppIntents

/// Interactive widget with quick actions for clock in/out (iOS 17+).
struct QuickActionsWidget: Widget {
    static let kind = "QuickActionsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: SimpleShiftTimelineProvider()
        ) { entry in
            QuickActionsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Actions")
        .description("Quick shift controls without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - App Intents for Widget Interactivity

struct ClockInIntent: AppIntent {
    static var title: LocalizedStringResource = "Clock In"
    static var description = IntentDescription("Start your current shift")
    
    func perform() async throws -> some IntentResult {
        // This would trigger the main app to clock in
        // Using App Groups or a shared data store
        await MainActor.run {
            NotificationCenter.default.post(name: .widgetClockIn, object: nil)
        }
        return .result()
    }
}

struct ClockOutIntent: AppIntent {
    static var title: LocalizedStringResource = "Clock Out"
    static var description = IntentDescription("End your current shift")
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .widgetClockOut, object: nil)
        }
        return .result()
    }
}

struct LogBreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Break"
    static var description = IntentDescription("Log a break during your shift")
    
    @Parameter(title: "Duration (minutes)", default: 30)
    var duration: Int
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .widgetLogBreak,
                object: nil,
                userInfo: ["duration": duration]
            )
        }
        return .result()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let widgetClockIn = Notification.Name("com.shiftpro.widget.clockIn")
    static let widgetClockOut = Notification.Name("com.shiftpro.widget.clockOut")
    static let widgetLogBreak = Notification.Name("com.shiftpro.widget.logBreak")
}

// MARK: - Widget View

struct QuickActionsWidgetView: View {
    let entry: ShiftWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }
    
    // MARK: - Small Widget
    
    private var smallView: some View {
        VStack(spacing: 12) {
            if let shift = entry.data.currentShift {
                if shift.status == .inProgress {
                    // Show clock out action
                    clockedInSmallView(shift: shift)
                } else {
                    // Show clock in action
                    clockedOutSmallView(shift: shift)
                }
            } else if let nextShift = entry.data.upcomingShifts.first {
                upcomingShiftSmallView(shift: nextShift)
            } else {
                noShiftSmallView
            }
        }
        .padding()
    }
    
    private func clockedInSmallView(shift: WidgetShiftData) -> some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(WidgetColors.success)
                    .frame(width: 8, height: 8)
                Text("On Shift")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(WidgetColors.success)
                Spacer()
            }
            
            Spacer()
            
            if let elapsed = shift.elapsedMinutes {
                Text(formatDuration(minutes: elapsed))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(WidgetColors.ink)
            }
            
            Button(intent: ClockOutIntent()) {
                Label("Clock Out", systemImage: "stop.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(WidgetColors.danger.opacity(0.2))
                    .foregroundStyle(WidgetColors.danger)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
    
    private func clockedOutSmallView(shift: WidgetShiftData) -> some View {
        VStack(spacing: 8) {
            Text(shift.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(WidgetColors.ink)
                .lineLimit(1)
            
            Text(shift.timeRangeFormatted)
                .font(.caption)
                .foregroundStyle(WidgetColors.inkSubtle)
            
            Spacer()
            
            Button(intent: ClockInIntent()) {
                Label("Clock In", systemImage: "play.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(WidgetColors.success.opacity(0.2))
                    .foregroundStyle(WidgetColors.success)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
    
    private func upcomingShiftSmallView(shift: WidgetShiftData) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(WidgetColors.accent)
            
            Text("Next shift")
                .font(.caption)
                .foregroundStyle(WidgetColors.inkSubtle)
            
            Text(shift.scheduledStart, style: .relative)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(WidgetColors.accent)
            
            Spacer()
            
            Link(destination: URL(string: "shiftpro://schedule")!) {
                Text("View Schedule")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(WidgetColors.accent.opacity(0.2))
                    .foregroundStyle(WidgetColors.accent)
                    .clipShape(Capsule())
            }
        }
    }
    
    private var noShiftSmallView: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.title)
                .foregroundStyle(WidgetColors.inkSubtle.opacity(0.5))
            
            Text("No shifts today")
                .font(.caption)
                .foregroundStyle(WidgetColors.inkSubtle)
            
            Spacer()
            
            Link(destination: URL(string: "shiftpro://add-shift")!) {
                Label("Add Shift", systemImage: "plus.circle.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(WidgetColors.accent.opacity(0.2))
                    .foregroundStyle(WidgetColors.accent)
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Medium Widget
    
    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: Status and info
            VStack(alignment: .leading, spacing: 8) {
                if let shift = entry.data.currentShift, shift.status == .inProgress {
                    HStack {
                        Circle()
                            .fill(WidgetColors.success)
                            .frame(width: 10, height: 10)
                        Text("On Shift")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(WidgetColors.success)
                    }
                    
                    Text(shift.title)
                        .font(.headline)
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                    
                    if let elapsed = shift.elapsedMinutes {
                        HStack(spacing: 4) {
                            Text(formatDuration(minutes: elapsed))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(WidgetColors.ink)
                            Text("elapsed")
                                .font(.caption)
                                .foregroundStyle(WidgetColors.inkSubtle)
                        }
                    }
                    
                    WidgetTimeDisplay(start: shift.effectiveStart, end: shift.effectiveEnd)
                } else if let shift = entry.data.currentShift ?? entry.data.upcomingShifts.first {
                    Text("Ready to start")
                        .font(.subheadline)
                        .foregroundStyle(WidgetColors.inkSubtle)
                    
                    Text(shift.title)
                        .font(.headline)
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                    
                    WidgetTimeDisplay(start: shift.scheduledStart, end: shift.scheduledEnd)
                    
                    Text(shift.dateFormatted)
                        .font(.caption)
                        .foregroundStyle(WidgetColors.inkSubtle)
                } else {
                    Text("No upcoming shifts")
                        .font(.headline)
                        .foregroundStyle(WidgetColors.inkSubtle)
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Actions
            VStack(spacing: 8) {
                if let shift = entry.data.currentShift, shift.status == .inProgress {
                    Button(intent: ClockOutIntent()) {
                        VStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title2)
                            Text("Clock Out")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .frame(width: 70, height: 60)
                        .background(WidgetColors.danger.opacity(0.2))
                        .foregroundStyle(WidgetColors.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Button(intent: LogBreakIntent()) {
                        VStack(spacing: 4) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title3)
                            Text("Break")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .frame(width: 70, height: 50)
                        .background(WidgetColors.warning.opacity(0.2))
                        .foregroundStyle(WidgetColors.warning)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                } else if entry.data.currentShift != nil || !entry.data.upcomingShifts.isEmpty {
                    Button(intent: ClockInIntent()) {
                        VStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                            Text("Clock In")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .frame(width: 70, height: 70)
                        .background(WidgetColors.success.opacity(0.2))
                        .foregroundStyle(WidgetColors.success)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "shiftpro://add-shift")!) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Add Shift")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .frame(width: 70, height: 70)
                        .background(WidgetColors.accent.opacity(0.2))
                        .foregroundStyle(WidgetColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

#Preview(as: .systemSmall) {
    QuickActionsWidget()
} timeline: {
    ShiftWidgetEntry.preview()
}

#Preview(as: .systemMedium) {
    QuickActionsWidget()
} timeline: {
    ShiftWidgetEntry.preview()
}
