import Foundation

// MARK: - Stats Types for Views

/// Weekly statistics for analytics views.
struct WeeklyStats: Sendable {
    let periodStart: Date
    let periodEnd: Date
    let totalHours: Double
    let shiftCount: Int
    let dayBreakdown: [WeekdayData]

    init(periodStart: Date = Date(), periodEnd: Date = Date(), totalHours: Double = 0, shiftCount: Int = 0, dayBreakdown: [WeekdayData] = []) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.totalHours = totalHours
        self.shiftCount = shiftCount
        self.dayBreakdown = dayBreakdown
    }
}

/// Monthly statistics for analytics views.
struct MonthlyStats: Sendable {
    let periodStart: Date
    let periodEnd: Date
    let totalHours: Double
    let shiftCount: Int
    let weeklyData: [WeekData]

    init(periodStart: Date = Date(), periodEnd: Date = Date(), totalHours: Double = 0, shiftCount: Int = 0, weeklyData: [WeekData] = []) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.totalHours = totalHours
        self.shiftCount = shiftCount
        self.weeklyData = weeklyData
    }
}

/// Yearly statistics for analytics views.
struct YearlyStats: Sendable {
    let year: Int
    let totalHours: Double
    let shiftCount: Int
    let monthlyData: [MonthData]

    init(year: Int = Calendar.current.component(.year, from: Date()), totalHours: Double = 0, shiftCount: Int = 0, monthlyData: [MonthData] = []) {
        self.year = year
        self.totalHours = totalHours
        self.shiftCount = shiftCount
        self.monthlyData = monthlyData
    }
}

// MARK: - Breakdown Data Types

/// Data for a specific weekday.
struct WeekdayData: Identifiable, Sendable {
    let id: UUID
    let weekday: Int  // 1 = Sunday, 7 = Saturday
    let totalHours: Double

    init(id: UUID = UUID(), weekday: Int, totalHours: Double) {
        self.id = id
        self.weekday = weekday
        self.totalHours = totalHours
    }

    var weekdayName: String {
        let formatter = DateFormatter()
        guard weekday >= 1 && weekday <= 7 else { return "" }
        return formatter.shortWeekdaySymbols[weekday - 1]
    }
}

/// Data for a specific week within a month.
struct WeekData: Identifiable, Sendable {
    let id: UUID
    let weekStart: Date
    let hours: Double

    init(id: UUID = UUID(), weekStart: Date, hours: Double) {
        self.id = id
        self.weekStart = weekStart
        self.hours = hours
    }
}

/// Data for a specific month within a year.
struct MonthData: Identifiable, Sendable {
    let id: UUID
    let month: Int  // 1 = January, 12 = December
    let hours: Double

    init(id: UUID = UUID(), month: Int, hours: Double) {
        self.id = id
        self.month = month
        self.hours = hours
    }

    var monthName: String {
        let formatter = DateFormatter()
        guard month >= 1 && month <= 12 else { return "" }
        return formatter.shortMonthSymbols[month - 1]
    }
}

// MARK: - Trend Analysis

/// Comprehensive trend analysis results.
struct TrendAnalysis: Sendable {
    let hoursTrend: HoursTrend
    let overtimeTrend: OvertimeTrend
    let shiftTimingPattern: ShiftTimingPattern
    let consistencyScore: Double  // 0-100
    let weekdayDistribution: [WeekdayData]

    init(
        hoursTrend: HoursTrend = .stable,
        overtimeTrend: OvertimeTrend = OvertimeTrend(),
        shiftTimingPattern: ShiftTimingPattern = .mixed,
        consistencyScore: Double = 50,
        weekdayDistribution: [WeekdayData] = []
    ) {
        self.hoursTrend = hoursTrend
        self.overtimeTrend = overtimeTrend
        self.shiftTimingPattern = shiftTimingPattern
        self.consistencyScore = consistencyScore
        self.weekdayDistribution = weekdayDistribution
    }
}

/// Trend direction for hours worked.
enum HoursTrend: String, Sendable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
}

/// Overtime trend information.
struct OvertimeTrend: Sendable {
    let riskLevel: OvertimeRiskLevel
    let averageOvertimePerWeek: Double
    let totalOvertimeHours: Double

    init(riskLevel: OvertimeRiskLevel = .low, averageOvertimePerWeek: Double = 0, totalOvertimeHours: Double = 0) {
        self.riskLevel = riskLevel
        self.averageOvertimePerWeek = averageOvertimePerWeek
        self.totalOvertimeHours = totalOvertimeHours
    }
}

/// Risk level for overtime.
enum OvertimeRiskLevel: String, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

/// Shift timing pattern classification.
enum ShiftTimingPattern: String, Sendable {
    case morningDominant = "morning"
    case afternoonDominant = "afternoon"
    case nightDominant = "night"
    case mixed = "mixed"
}

// MARK: - Shift Preferences (for PredictiveModels)

/// User's shift time preferences based on historical data.
struct ShiftPreferences: Sendable {
    let morning: Double    // 0.0 - 1.0
    let afternoon: Double
    let evening: Double
    let night: Double

    init(morning: Double = 0.25, afternoon: Double = 0.25, evening: Double = 0.25, night: Double = 0.25) {
        self.morning = morning
        self.afternoon = afternoon
        self.evening = evening
        self.night = night
    }

    var preferredSlot: ShiftTimeSlot {
        let max = [morning, afternoon, evening, night].max() ?? 0
        if max < 0.3 { return .none }
        if morning == max { return .morning }
        if afternoon == max { return .afternoon }
        if evening == max { return .evening }
        return .night
    }
}

/// Time slots for shifts.
enum ShiftTimeSlot: String, Sendable {
    case morning = "morning"      // 6am - 12pm
    case afternoon = "afternoon"  // 12pm - 6pm
    case evening = "evening"      // 6pm - 10pm
    case night = "night"          // 10pm - 6am
    case none = "none"

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        case .none: return "No Preference"
        }
    }
}

/// Detected work pattern.
struct DetectedPattern: Sendable {
    let patternType: PatternType
    let confidence: Double
    let description: String

    enum PatternType: String, Sendable {
        case regular = "regular"
        case rotating = "rotating"
        case irregular = "irregular"
        case compressed = "compressed"
    }
}
