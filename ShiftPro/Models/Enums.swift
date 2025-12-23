import Foundation

// MARK: - Pay Period Type
/// Defines the frequency of pay periods for hour aggregation
enum PayPeriodType: Int16, CaseIterable, Codable, Sendable {
    case weekly = 0
    case biweekly = 1
    case monthly = 2

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-Weekly"
        case .monthly: return "Monthly"
        }
    }

    var daysInPeriod: Int {
        switch self {
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30 // Approximate
        }
    }
}

// MARK: - Schedule Type
/// Defines whether a shift pattern follows a weekly or cycling rotation
enum ScheduleType: Int16, CaseIterable, Codable, Sendable {
    case weekly = 0   // Same pattern every week (uses daysOfWeekMask)
    case cycling = 1  // Rotating pattern (uses rotationDays)

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .cycling: return "Rotating"
        }
    }
}

// MARK: - Shift Status
/// Tracks the lifecycle state of a shift
enum ShiftStatus: Int16, CaseIterable, Codable, Sendable {
    case scheduled = 0   // Future shift, not started
    case inProgress = 1  // Currently working
    case completed = 2   // Finished normally
    case cancelled = 3   // Cancelled before completion

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
        case .scheduled: return "calendar.badge.clock"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// MARK: - Weekday
/// Days of the week for shift pattern configuration
enum Weekday: Int, CaseIterable, Codable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    /// Bitmask value for this weekday (for daysOfWeekMask)
    var mask: Int16 {
        Int16(1 << (rawValue - 1))
    }
}

// MARK: - Calendar Sync State
/// Tracks the synchronization state between shifts and calendar events
enum CalendarSyncState: Int16, CaseIterable, Codable, Sendable {
    case localOnly = 0    // Not synced to calendar
    case synced = 1       // In sync with calendar
    case needsUpdate = 2  // Local changes pending sync
    case failed = 3       // Sync attempted but failed
    case conflictDetected = 4 // Local and calendar changes diverged

    var displayName: String {
        switch self {
        case .localOnly: return "Local Only"
        case .synced: return "Synced"
        case .needsUpdate: return "Needs Update"
        case .failed: return "Sync Failed"
        case .conflictDetected: return "Conflict"
        }
    }
}

// MARK: - Rate Multiplier
/// Standard rate multipliers for shift pay calculations
enum RateMultiplier: Double, CaseIterable, Codable, Sendable {
    case regular = 1.0
    case overtimeBracket = 1.3
    case extra = 1.5
    case bankHoliday = 2.0

    var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .overtimeBracket: return "Overtime (Bracket)"
        case .extra: return "Extra"
        case .bankHoliday: return "Bank Holiday"
        }
    }

    var formattedMultiplier: String {
        String(format: "%.1fx", rawValue)
    }
}

// MARK: - Weekday Mask Helpers
extension Int16 {
    /// Check if a specific weekday is set in this mask
    func contains(weekday: Weekday) -> Bool {
        (self & weekday.mask) != 0
    }

    /// Returns all weekdays set in this mask
    var weekdays: [Weekday] {
        Weekday.allCases.filter { contains(weekday: $0) }
    }

    /// Creates a mask from an array of weekdays
    static func mask(from weekdays: [Weekday]) -> Int16 {
        weekdays.reduce(0) { $0 | $1.mask }
    }
}
