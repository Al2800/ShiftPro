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
