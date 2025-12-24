import Foundation

/// Generates actionable insights from analytics data.
actor InsightsGenerator {
    
    // MARK: - Public Methods
    
    /// Generate insights from analyzed data
    func generateInsights(
        shifts: [Shift],
        weeklyStats: WeeklyStats?,
        monthlyStats: MonthlyStats?,
        trends: TrendAnalysis
    ) async -> [ShiftInsight] {
        var insights: [ShiftInsight] = []
        
        // Hours-based insights
        if let weekly = weeklyStats {
            insights.append(contentsOf: generateHoursInsights(weekly: weekly, trends: trends))
        }
        
        // Overtime insights
        insights.append(contentsOf: generateOvertimeInsights(trends: trends))
        
        // Schedule pattern insights
        insights.append(contentsOf: generatePatternInsights(trends: trends))
        
        // Work-life balance insights
        if let monthly = monthlyStats {
            insights.append(contentsOf: generateBalanceInsights(monthly: monthly, trends: trends))
        }
        
        // Performance insights
        insights.append(contentsOf: generatePerformanceInsights(shifts: shifts, trends: trends))
        
        // Sort by priority and return top insights
        return insights
            .sorted { $0.priority.rawValue < $1.priority.rawValue }
            .prefix(10)
            .map { $0 }
    }
    
    // MARK: - Hours Insights
    
    private func generateHoursInsights(weekly: WeeklyStats, trends: TrendAnalysis) -> [ShiftInsight] {
        var insights: [ShiftInsight] = []
        
        // Hours trend insight
        switch trends.hoursTrend {
        case .increasing:
            insights.append(ShiftInsight(
                id: UUID(),
                type: .trend,
                title: "Hours Increasing",
                description: "Your working hours are trending up. Consider your work-life balance.",
                priority: .medium,
                iconName: "arrow.up.right.circle",
                actionable: true,
                action: "Review your schedule for the next few weeks"
            ))
        case .decreasing:
            insights.append(ShiftInsight(
                id: UUID(),
                type: .trend,
                title: "Hours Decreasing",
                description: "Your working hours are trending down from recent weeks.",
                priority: .low,
                iconName: "arrow.down.right.circle",
                actionable: false,
                action: nil
            ))
        case .stable:
            if weekly.totalHours >= 40 {
                insights.append(ShiftInsight(
                    id: UUID(),
                    type: .positive,
                    title: "Consistent Schedule",
                    description: "You're maintaining a steady workload of \(String(format: "%.1f", weekly.totalHours)) hours this week.",
                    priority: .low,
                    iconName: "checkmark.circle",
                    actionable: false,
                    action: nil
                ))
            }
        }
        
        // High hours warning
        if weekly.totalHours > 50 {
            insights.append(ShiftInsight(
                id: UUID(),
                type: .warning,
                title: "High Weekly Hours",
                description: "You're at \(String(format: "%.1f", weekly.totalHours)) hours this week. Consider rest.",
                priority: .high,
                iconName: "exclamationmark.triangle",
                actionable: true,
                action: "Consider taking time off or reducing upcoming shifts"
            ))
        }
        
        return insights
    }
    
    // MARK: - Overtime Insights
    
    private func generateOvertimeInsights(trends: TrendAnalysis) -> [ShiftInsight] {
        var insights: [ShiftInsight] = []
        let overtime = trends.overtimeTrend
        
        switch overtime.riskLevel {
        case .high:
            insights.append(ShiftInsight(
                id: UUID(),
                type: .warning,
                title: "High Overtime",
                description: "Averaging \(String(format: "%.1f", overtime.averageOvertimePerWeek)) overtime hours/week. This may affect your well-being.",
                priority: .high,
                iconName: "clock.badge.exclamationmark",
                actionable: true,
                action: "Review shift durations and consider adjustments"
            ))
        case .medium:
            insights.append(ShiftInsight(
                id: UUID(),
                type: .info,
                title: "Moderate Overtime",
                description: "You're working \(String(format: "%.1f", overtime.averageOvertimePerWeek)) overtime hours/week on average.",
                priority: .medium,
                iconName: "clock.badge",
                actionable: false,
                action: nil
            ))
        case .low:
            if overtime.averageOvertimePerWeek > 0 {
                insights.append(ShiftInsight(
                    id: UUID(),
                    type: .positive,
                    title: "Healthy Overtime Levels",
                    description: "Your overtime is well-managed at \(String(format: "%.1f", overtime.averageOvertimePerWeek)) hours/week.",
                    priority: .low,
                    iconName: "checkmark.seal",
                    actionable: false,
                    action: nil
                ))
            }
        }
        
        return insights
    }
    
    // MARK: - Pattern Insights
    
    private func generatePatternInsights(trends: TrendAnalysis) -> [ShiftInsight] {
        var insights: [ShiftInsight] = []
        
        // Shift timing pattern
        switch trends.shiftTimingPattern {
        case .nightDominant:
            insights.append(ShiftInsight(
                id: UUID(),
                type: .info,
                title: "Night Shift Pattern",
                description: "Most of your shifts are during night hours. Prioritize sleep hygiene.",
                priority: .medium,
                iconName: "moon.stars",
                actionable: true,
                action: "Maintain consistent sleep schedule even on days off"
            ))
        case .morningDominant:
            insights.append(ShiftInsight(
                id: UUID(),
                type: .positive,
                title: "Morning Schedule",
                description: "You primarily work morning shifts, which aligns with natural circadian rhythms.",
                priority: .low,
                iconName: "sunrise",
                actionable: false,
                action: nil
            ))
        case .mixed:
            insights.append(ShiftInsight(
                id: UUID(),
                type: .info,
                title: "Varied Schedule",
                description: "Your shifts vary between morning, afternoon, and night. This can be challenging for sleep patterns.",
                priority: .medium,
                iconName: "clock",
                actionable: true,
                action: "Try to group similar shifts together when possible"
            ))
        case .afternoonDominant:
            break // No specific insight for afternoon shifts
        }
        
        // Consistency score
        if trends.consistencyScore >= 80 {
            insights.append(ShiftInsight(
                id: UUID(),
                type: .positive,
                title: "Consistent Shift Lengths",
                description: "Your shifts have consistent durations, which helps with planning.",
                priority: .low,
                iconName: "calendar.badge.checkmark",
                actionable: false,
                action: nil
            ))
        } else if trends.consistencyScore < 50 {
            insights.append(ShiftInsight(
                id: UUID(),
                type: .info,
                title: "Variable Shift Lengths",
                description: "Your shift durations vary significantly. Consider more consistency if possible.",
                priority: .low,
                iconName: "calendar.badge.minus",
                actionable: false,
                action: nil
            ))
        }
        
        return insights
    }
    
    // MARK: - Balance Insights
    
    private func generateBalanceInsights(monthly: MonthlyStats, trends: TrendAnalysis) -> [ShiftInsight] {
        var insights: [ShiftInsight] = []
        
        // Weekday distribution analysis
        let weekdayHours = trends.weekdayDistribution.filter { $0.weekday >= 2 && $0.weekday <= 6 }
        let weekendHours = trends.weekdayDistribution.filter { $0.weekday == 1 || $0.weekday == 7 }
        
        let totalWeekdayHours = weekdayHours.reduce(0.0) { $0 + $1.totalHours }
        let totalWeekendHours = weekendHours.reduce(0.0) { $0 + $1.totalHours }
        let totalHours = totalWeekdayHours + totalWeekendHours
        
        if totalHours > 0 {
            let weekendPercent = (totalWeekendHours / totalHours) * 100
            
            if weekendPercent > 40 {
                insights.append(ShiftInsight(
                    id: UUID(),
                    type: .info,
                    title: "High Weekend Work",
                    description: "\(String(format: "%.0f", weekendPercent))% of your hours are on weekends.",
                    priority: .medium,
                    iconName: "calendar.badge.clock",
                    actionable: true,
                    action: "Consider requesting more weekday shifts for better work-life balance"
                ))
            }
        }
        
        return insights
    }
    
    // MARK: - Performance Insights
    
    private func generatePerformanceInsights(shifts: [Shift], trends: TrendAnalysis) -> [ShiftInsight] {
        var insights: [ShiftInsight] = []
        
        // Punctuality analysis (based on actual vs scheduled start times)
        let completedShifts = shifts.filter { $0.status == .completed && $0.actualStart != nil }
        guard !completedShifts.isEmpty else { return insights }
        
        var lateStarts = 0
        var earlyStarts = 0
        
        for shift in completedShifts {
            guard let actualStart = shift.actualStart else { continue }
            let diff = actualStart.timeIntervalSince(shift.scheduledStart)
            
            if diff > 300 { // More than 5 minutes late
                lateStarts += 1
            } else if diff < -300 { // More than 5 minutes early
                earlyStarts += 1
            }
        }
        
        let latePercent = Double(lateStarts) / Double(completedShifts.count) * 100
        let earlyPercent = Double(earlyStarts) / Double(completedShifts.count) * 100
        
        if latePercent > 20 {
            insights.append(ShiftInsight(
                id: UUID(),
                type: .warning,
                title: "Late Start Pattern",
                description: "You've started \(String(format: "%.0f", latePercent))% of shifts after scheduled time.",
                priority: .medium,
                iconName: "clock.badge.exclamationmark",
                actionable: true,
                action: "Set earlier reminders or adjust your pre-shift routine"
            ))
        } else if earlyPercent > 60 {
            insights.append(ShiftInsight(
                id: UUID(),
                type: .positive,
                title: "Consistently Early",
                description: "You start most shifts ahead of schedule. Great reliability!",
                priority: .low,
                iconName: "star.circle",
                actionable: false,
                action: nil
            ))
        }
        
        return insights
    }
}

// MARK: - Insight Model

struct ShiftInsight: Identifiable, Sendable {
    let id: UUID
    let type: InsightType
    let title: String
    let description: String
    let priority: InsightPriority
    let iconName: String
    let actionable: Bool
    let action: String?
}

enum InsightType: String, Sendable {
    case positive = "positive"
    case warning = "warning"
    case info = "info"
    case trend = "trend"
    
    var color: String {
        switch self {
        case .positive: return "green"
        case .warning: return "orange"
        case .info: return "blue"
        case .trend: return "purple"
        }
    }
}

enum InsightPriority: Int, Sendable {
    case high = 0
    case medium = 1
    case low = 2
}
