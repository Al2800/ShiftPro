import Foundation
import SwiftData

/// Analyzes shift patterns and identifies trends.
struct TrendAnalyzer {
    
    // MARK: - Work Pattern Analysis
    
    /// Identifies preferred shift times based on historical data.
    static func analyzeShiftPreferences(shifts: [Shift]) -> ShiftPreferences {
        var morningCount = 0
        var afternoonCount = 0
        var eveningCount = 0
        var nightCount = 0
        
        let calendar = Calendar.current
        
        for shift in shifts {
            let hour = calendar.component(.hour, from: shift.scheduledStart)
            switch hour {
            case 5..<12: morningCount += 1
            case 12..<17: afternoonCount += 1
            case 17..<21: eveningCount += 1
            default: nightCount += 1
            }
        }
        
        let total = shifts.count
        guard total > 0 else {
            return ShiftPreferences(morning: 0, afternoon: 0, evening: 0, night: 0, preferredSlot: .none)
        }
        
        let counts = [
            (ShiftTimeSlot.morning, morningCount),
            (ShiftTimeSlot.afternoon, afternoonCount),
            (ShiftTimeSlot.evening, eveningCount),
            (ShiftTimeSlot.night, nightCount)
        ]
        
        let preferred = counts.max(by: { $0.1 < $1.1 })?.0 ?? .none
        
        return ShiftPreferences(
            morning: Double(morningCount) / Double(total),
            afternoon: Double(afternoonCount) / Double(total),
            evening: Double(eveningCount) / Double(total),
            night: Double(nightCount) / Double(total),
            preferredSlot: preferred
        )
    }
    
    /// Detects patterns in shift scheduling.
    static func detectPatterns(shifts: [Shift]) -> [DetectedPattern] {
        var patterns: [DetectedPattern] = []
        
        // Check for regular weekly pattern
        if let weeklyPattern = detectWeeklyPattern(shifts: shifts) {
            patterns.append(weeklyPattern)
        }
        
        // Check for rotating pattern
        if let rotatingPattern = detectRotatingPattern(shifts: shifts) {
            patterns.append(rotatingPattern)
        }
        
        // Check for consistent duration
        if let durationPattern = detectDurationPattern(shifts: shifts) {
            patterns.append(durationPattern)
        }
        
        return patterns
    }
    
    private static func detectWeeklyPattern(shifts: [Shift]) -> DetectedPattern? {
        let calendar = Calendar.current
        var weekdayShifts: [Int: Int] = [:]
        
        for shift in shifts {
            let weekday = calendar.component(.weekday, from: shift.scheduledStart)
            weekdayShifts[weekday, default: 0] += 1
        }
        
        // Check if there's a consistent pattern
        let workdays = weekdayShifts.filter { $0.value > shifts.count / 10 }
        if workdays.count >= 3 && workdays.count <= 6 {
            let days = workdays.keys.sorted().map { dayName($0) }.joined(separator: ", ")
            return DetectedPattern(
                type: .weekly,
                name: "Weekly Pattern",
                description: "You typically work on: \(days)",
                confidence: Double(workdays.values.reduce(0, +)) / Double(shifts.count)
            )
        }
        
        return nil
    }
    
    private static func detectRotatingPattern(shifts: [Shift]) -> DetectedPattern? {
        // Simplified rotating pattern detection
        // Would need more sophisticated analysis for complex rotations
        guard shifts.count >= 10 else { return nil }
        
        var consecutiveWorkDays: [Int] = []
        var currentStreak = 1
        
        let sortedShifts = shifts.sorted { $0.scheduledStart < $1.scheduledStart }
        let calendar = Calendar.current
        
        for index in 1..<sortedShifts.count {
            let prevDate = calendar.startOfDay(for: sortedShifts[index - 1].scheduledStart)
            let currDate = calendar.startOfDay(for: sortedShifts[index].scheduledStart)
            let daysDiff = calendar.dateComponents([.day], from: prevDate, to: currDate).day ?? 0
            
            if daysDiff == 1 {
                currentStreak += 1
            } else {
                if currentStreak > 1 {
                    consecutiveWorkDays.append(currentStreak)
                }
                currentStreak = 1
            }
        }
        
        if currentStreak > 1 {
            consecutiveWorkDays.append(currentStreak)
        }
        
        // Check for common patterns like 4-on/4-off
        let total = Double(consecutiveWorkDays.reduce(0, +))
        let count = Double(consecutiveWorkDays.count)
        let avgStreak = consecutiveWorkDays.isEmpty ? 0 : total / count
        
        if avgStreak >= 3 && avgStreak <= 5 {
            return DetectedPattern(
                type: .rotating,
                name: "Rotating Schedule",
                description: "You work approximately \(Int(avgStreak)) consecutive days per rotation.",
                confidence: 0.7
            )
        }
        
        return nil
    }
    
    private static func detectDurationPattern(shifts: [Shift]) -> DetectedPattern? {
        guard !shifts.isEmpty else { return nil }
        
        let durations = shifts.map { $0.effectiveDurationMinutes }
        let avgDuration = Double(durations.reduce(0, +)) / Double(durations.count)
        
        // Calculate variance
        let variance = durations.map { Double($0) - avgDuration }.map { $0 * $0 }.reduce(0, +) / Double(durations.count)
        let stdDev = sqrt(variance)
        
        // Low variance indicates consistent shift duration
        if stdDev < 60 { // Less than 1 hour deviation
            let hours = Int(avgDuration / 60)
            return DetectedPattern(
                type: .duration,
                name: "Consistent Duration",
                description: "Your shifts are typically around \(hours) hours.",
                confidence: 1.0 - (stdDev / 120)
            )
        }
        
        return nil
    }
    
    private static func dayName(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols[weekday - 1]
    }
    
    // MARK: - Overtime Analysis
    
    static func analyzeOvertimeTrends(shifts: [Shift]) -> OvertimeTrend {
        let overtimeShifts = shifts.filter { $0.rateMultiplier > 1.0 }
        
        guard !shifts.isEmpty else {
            return OvertimeTrend(
                frequency: 0,
                averageHoursPerOccurrence: 0,
                mostCommonDay: nil,
                mostCommonTime: nil,
                trend: .stable
            )
        }
        
        let frequency = Double(overtimeShifts.count) / Double(shifts.count)
        let totalPaidMinutes = Double(overtimeShifts.reduce(0) { $0 + $1.paidMinutes })
        let overtimeCount = Double(overtimeShifts.count)
        let avgHours = overtimeShifts.isEmpty ? 0 : totalPaidMinutes / overtimeCount / 60.0
        
        // Find most common day for overtime
        let calendar = Calendar.current
        var dayCount: [Int: Int] = [:]
        for shift in overtimeShifts {
            let day = calendar.component(.weekday, from: shift.scheduledStart)
            dayCount[day, default: 0] += 1
        }
        let mostCommonDay = dayCount.max(by: { $0.value < $1.value })?.key
        
        return OvertimeTrend(
            frequency: frequency,
            averageHoursPerOccurrence: avgHours,
            mostCommonDay: mostCommonDay,
            mostCommonTime: nil,
            trend: .stable
        )
    }
    
    // MARK: - Work-Life Balance Score
    
    static func calculateWorkLifeBalance(weeklyMetrics: WeeklyMetrics?) -> WorkLifeBalanceScore {
        guard let metrics = weeklyMetrics else {
            return WorkLifeBalanceScore(score: 0.5, factors: [], recommendations: [])
        }
        
        var score = 1.0
        var factors: [BalanceFactor] = []
        var recommendations: [String] = []
        
        // Check total hours (40-50 is ideal)
        if metrics.totalHours > 50 {
            score -= 0.2
            factors.append(BalanceFactor(
                name: "High Hours",
                impact: -0.2,
                description: "Working over 50 hours per week"
            ))
            recommendations.append("Consider reducing weekly hours for better balance")
        } else if metrics.totalHours > 40 {
            score -= 0.1
            factors.append(BalanceFactor(
                name: "Above Average",
                impact: -0.1,
                description: "Working 40-50 hours per week"
            ))
        } else if metrics.totalHours < 20 {
            factors.append(BalanceFactor(
                name: "Low Hours",
                impact: 0,
                description: "Working under 20 hours per week"
            ))
        } else {
            factors.append(BalanceFactor(
                name: "Healthy Hours",
                impact: 0.1,
                description: "Working 20-40 hours per week"
            ))
            score += 0.1
        }

        // Check overtime percentage
        let overtimePercent = metrics.premiumHours / max(1, metrics.totalHours)
        if overtimePercent > 0.3 {
            score -= 0.15
            factors.append(BalanceFactor(
                name: "High Overtime",
                impact: -0.15,
                description: "Over 30% of hours are overtime"
            ))
            recommendations.append("Try to balance overtime with regular shifts")
        }
        
        // Check shift distribution
        if let byDay = metrics.byDay {
            let workedDays = byDay.filter { $0.hours > 0 }.count
            if workedDays >= 6 {
                score -= 0.1
                factors.append(BalanceFactor(
                    name: "Few Rest Days",
                    impact: -0.1,
                    description: "Working 6+ days per week"
                ))
                recommendations.append("Ensure at least 2 rest days per week")
            } else if workedDays <= 4 {
                score += 0.1
                factors.append(BalanceFactor(
                    name: "Good Rest",
                    impact: 0.1,
                    description: "3+ rest days per week"
                ))
            }
        }
        
        return WorkLifeBalanceScore(
            score: max(0, min(1, score)),
            factors: factors,
            recommendations: recommendations
        )
    }
}

// MARK: - Trend Models

struct ShiftPreferences {
    let morning: Double
    let afternoon: Double
    let evening: Double
    let night: Double
    let preferredSlot: ShiftTimeSlot
}

enum ShiftTimeSlot: String {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"
    case none = "None"
}

struct DetectedPattern: Identifiable {
    let id = UUID()
    let type: PatternType
    let name: String
    let description: String
    let confidence: Double
    
    enum PatternType {
        case weekly
        case rotating
        case duration
        case custom
    }
}

struct OvertimeTrend: Sendable {
    let frequency: Double
    let averageHoursPerOccurrence: Double
    let mostCommonDay: Int?
    let mostCommonTime: Int?
    let trend: Trend

    enum Trend: Sendable {
        case increasing
        case decreasing
        case stable
    }

    init(
        frequency: Double = 0,
        averageHoursPerOccurrence: Double = 0,
        mostCommonDay: Int? = nil,
        mostCommonTime: Int? = nil,
        trend: Trend = .stable
    ) {
        self.frequency = frequency
        self.averageHoursPerOccurrence = averageHoursPerOccurrence
        self.mostCommonDay = mostCommonDay
        self.mostCommonTime = mostCommonTime
        self.trend = trend
    }
}

struct WorkLifeBalanceScore {
    let score: Double
    let factors: [BalanceFactor]
    let recommendations: [String]
    
    var rating: String {
        switch score {
        case 0.8...: return "Excellent"
        case 0.6..<0.8: return "Good"
        case 0.4..<0.6: return "Fair"
        default: return "Needs Attention"
        }
    }
    
    var color: String {
        switch score {
        case 0.8...: return "green"
        case 0.6..<0.8: return "blue"
        case 0.4..<0.6: return "orange"
        default: return "red"
        }
    }
}

struct BalanceFactor: Identifiable {
    let id = UUID()
    let name: String
    let impact: Double
    let description: String
}
