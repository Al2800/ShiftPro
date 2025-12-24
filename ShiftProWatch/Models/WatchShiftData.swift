import Foundation

/// Lightweight shift data model for Apple Watch.
/// Synced from iPhone app via WatchConnectivity.
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
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }
    
    var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: effectiveStart)) - \(formatter.string(from: effectiveEnd))"
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
    
    var remainingMinutes: Int? {
        guard status == .inProgress else { return nil }
        let remaining = Int(scheduledEnd.timeIntervalSince(Date()) / 60)
        return max(0, remaining)
    }
    
    var countdownFormatted: String? {
        guard isFuture else { return nil }
        let interval = scheduledStart.timeIntervalSince(Date())
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 24 {
            return "in \(hours / 24)d"
        } else if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "in \(minutes)m"
        }
        return "now"
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
}

/// Hours summary for Watch display
struct WatchHoursData: Codable, Sendable {
    let periodStart: Date
    let periodEnd: Date
    let totalHours: Double
    let regularHours: Double
    let premiumHours: Double
    let targetHours: Double
    
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
}

/// Container for all Watch data
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
}
