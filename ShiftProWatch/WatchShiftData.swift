import Foundation

/// Lightweight shift data model for watch consumption.
/// Mirrors WidgetShiftData for consistency across extensions.
struct WatchShiftData: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let scheduledStart: Date
    let scheduledEnd: Date
    let actualStart: Date?
    let actualEnd: Date?
    let status: WatchShiftStatus
    let rateMultiplier: Double
    let rateLabel: String?
    let location: String?

    var isInProgress: Bool {
        status == .inProgress
    }

    var isFuture: Bool {
        scheduledStart > Date()
    }

    var effectiveStart: Date {
        actualStart ?? scheduledStart
    }

    var effectiveEnd: Date {
        actualEnd ?? scheduledEnd
    }

    var durationMinutes: Int {
        Int(effectiveEnd.timeIntervalSince(effectiveStart) / 60)
    }

    var durationFormatted: String {
        let hours = durationMinutes / 60
        let mins = durationMinutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }

    var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: effectiveStart)) - \(formatter.string(from: effectiveEnd))"
    }

    var startTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: scheduledStart)
    }

    var dayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: scheduledStart)
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: scheduledStart)
    }

    var elapsedMinutes: Int? {
        guard status == .inProgress, let start = actualStart else { return nil }
        return Int(Date().timeIntervalSince(start) / 60)
    }

    var elapsedFormatted: String? {
        guard let elapsed = elapsedMinutes else { return nil }
        let hours = elapsed / 60
        let mins = elapsed % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    var remainingMinutes: Int? {
        guard status == .inProgress else { return nil }
        let remaining = Int(scheduledEnd.timeIntervalSince(Date()) / 60)
        return max(0, remaining)
    }

    var remainingFormatted: String? {
        guard let remaining = remainingMinutes else { return nil }
        let hours = remaining / 60
        let mins = remaining % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    var countdownFormatted: String? {
        guard isFuture else { return nil }
        let interval = scheduledStart.timeIntervalSince(Date())
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            let days = hours / 24
            return "in \(days)d"
        } else if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "in \(minutes)m"
        } else {
            return "now"
        }
    }
}

enum WatchShiftStatus: Int, Codable, Sendable {
    case scheduled = 0
    case inProgress = 1
    case completed = 2
    case cancelled = 3

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var iconName: String {
        switch self {
        case .scheduled: return "calendar"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .scheduled: return "blue"
        case .inProgress: return "green"
        case .completed: return "gray"
        case .cancelled: return "red"
        }
    }
}

/// Hours summary data for watch display
struct WatchHoursData: Codable, Sendable {
    let periodStart: Date
    let periodEnd: Date
    let totalHours: Double
    let regularHours: Double
    let premiumHours: Double
    let targetHours: Double
    let estimatedPayCents: Int?

    var progress: Double {
        guard targetHours > 0 else { return 0 }
        return min(1.0, totalHours / targetHours)
    }

    var periodFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: periodStart)) - \(formatter.string(from: periodEnd))"
    }

    var hoursFormatted: String {
        String(format: "%.1f", totalHours)
    }

    var estimatedPayFormatted: String? {
        guard let cents = estimatedPayCents else { return nil }
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var progressPercent: Int {
        Int(progress * 100)
    }
}

/// Container for all watch data, synced from iPhone
struct WatchDataContainer: Codable, Sendable {
    let currentShift: WatchShiftData?
    let upcomingShifts: [WatchShiftData]
    let hoursData: WatchHoursData?
    let lastUpdated: Date

    static let empty = WatchDataContainer(
        currentShift: nil,
        upcomingShifts: [],
        hoursData: nil,
        lastUpdated: Date()
    )

    static var preview: WatchDataContainer {
        let now = Date()
        let currentShift = WatchShiftData(
            id: UUID(),
            title: "Day Shift",
            scheduledStart: now.addingTimeInterval(-3600 * 2),
            scheduledEnd: now.addingTimeInterval(3600 * 6),
            actualStart: now.addingTimeInterval(-3600 * 2),
            actualEnd: nil,
            status: .inProgress,
            rateMultiplier: 1.0,
            rateLabel: nil,
            location: "Main Station"
        )

        let upcoming = [
            WatchShiftData(
                id: UUID(),
                title: "Night Shift",
                scheduledStart: now.addingTimeInterval(3600 * 24),
                scheduledEnd: now.addingTimeInterval(3600 * 32),
                actualStart: nil,
                actualEnd: nil,
                status: .scheduled,
                rateMultiplier: 1.3,
                rateLabel: "Night",
                location: "Downtown"
            ),
            WatchShiftData(
                id: UUID(),
                title: "Day Shift",
                scheduledStart: now.addingTimeInterval(3600 * 48),
                scheduledEnd: now.addingTimeInterval(3600 * 56),
                actualStart: nil,
                actualEnd: nil,
                status: .scheduled,
                rateMultiplier: 1.0,
                rateLabel: nil,
                location: "Main Station"
            )
        ]

        let hours = WatchHoursData(
            periodStart: now.addingTimeInterval(-3600 * 24 * 7),
            periodEnd: now.addingTimeInterval(3600 * 24 * 7),
            totalHours: 32.5,
            regularHours: 28.0,
            premiumHours: 4.5,
            targetHours: 40.0,
            estimatedPayCents: 125000
        )

        return WatchDataContainer(
            currentShift: currentShift,
            upcomingShifts: upcoming,
            hoursData: hours,
            lastUpdated: now
        )
    }
}

/// Actions that can be sent from watch to iPhone
enum WatchAction: String, Codable {
    case startShift
    case endShift
    case logBreak
    case markOvertime
    case refreshData
}

/// Response from iPhone after watch action
struct WatchActionResponse: Codable {
    let action: WatchAction
    let success: Bool
    let message: String?
    let updatedData: WatchDataContainer?
}
