import Foundation
import SwiftData

/// Provides predictions and forecasts based on historical data.
struct PredictiveModels {
    
    // MARK: - Hours Projection
    
    /// Projects end-of-period hours based on current pace.
    static func projectPeriodHours(
        currentHours: Double,
        daysPassed: Int,
        totalDays: Int
    ) -> HoursProjection {
        guard daysPassed > 0 && totalDays > 0 else {
            return HoursProjection(
                projectedTotal: 0,
                dailyRate: 0,
                daysRemaining: totalDays,
                onTrack: false,
                targetHours: 80
            )
        }
        
        let dailyRate = currentHours / Double(daysPassed)
        let daysRemaining = totalDays - daysPassed
        let projectedTotal = currentHours + (dailyRate * Double(daysRemaining))
        let targetHours: Double = 80 // Standard bi-weekly target
        
        return HoursProjection(
            projectedTotal: projectedTotal,
            dailyRate: dailyRate,
            daysRemaining: daysRemaining,
            onTrack: projectedTotal >= targetHours * 0.9,
            targetHours: targetHours
        )
    }
    
    // MARK: - Overtime Prediction
    
    /// Predicts likelihood of overtime based on current schedule.
    static func predictOvertime(
        scheduledShifts: [Shift],
        weeklyTarget: Double = 40
    ) -> OvertimePrediction {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        
        // Calculate scheduled hours for this week
        let thisWeekShifts = scheduledShifts.filter {
            $0.scheduledStart >= weekStart && $0.scheduledStart < weekEnd
        }
        
        let scheduledHours = Double(thisWeekShifts.reduce(0) { $0 + $1.scheduledDurationMinutes }) / 60.0
        
        let overtimeHours = max(0, scheduledHours - weeklyTarget)
        let probability = min(1.0, scheduledHours / weeklyTarget)
        
        var warnings: [String] = []
        if scheduledHours > weeklyTarget {
            warnings.append("You have \(String(format: "%.1f", overtimeHours)) hours of overtime scheduled this week.")
        }
        if scheduledHours > weeklyTarget * 1.25 {
            warnings.append("Consider balancing your workload to avoid burnout.")
        }
        
        return OvertimePrediction(
            probability: probability,
            predictedHours: overtimeHours,
            scheduledHours: scheduledHours,
            warnings: warnings
        )
    }
    
    // MARK: - Optimal Shift Scheduling
    
    /// Suggests optimal shift times based on historical patterns.
    static func suggestOptimalShifts(
        preferences: ShiftPreferences,
        existingPattern: DetectedPattern?,
        targetHoursPerWeek: Double = 40
    ) -> [ShiftSuggestion] {
        var suggestions: [ShiftSuggestion] = []
        
        // Suggest based on preferred time slot
        switch preferences.preferredSlot {
        case .morning:
            suggestions.append(ShiftSuggestion(
                timeSlot: .morning,
                reason: "You prefer morning shifts (\(Int(preferences.morning * 100))% of your shifts).",
                confidence: preferences.morning
            ))
        case .afternoon:
            suggestions.append(ShiftSuggestion(
                timeSlot: .afternoon,
                reason: "You prefer afternoon shifts (\(Int(preferences.afternoon * 100))% of your shifts).",
                confidence: preferences.afternoon
            ))
        case .evening:
            suggestions.append(ShiftSuggestion(
                timeSlot: .evening,
                reason: "You prefer evening shifts (\(Int(preferences.evening * 100))% of your shifts).",
                confidence: preferences.evening
            ))
        case .night:
            suggestions.append(ShiftSuggestion(
                timeSlot: .night,
                reason: "You prefer night shifts (\(Int(preferences.night * 100))% of your shifts).",
                confidence: preferences.night
            ))
        case .none:
            break
        }
        
        // Add general suggestions
        if targetHoursPerWeek <= 40 {
            suggestions.append(ShiftSuggestion(
                timeSlot: .morning,
                reason: "Morning shifts allow for afternoon personal time.",
                confidence: 0.5
            ))
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Burnout Risk Assessment
    
    /// Assesses burnout risk based on work patterns.
    static func assessBurnoutRisk(
        weeklyHours: Double,
        consecutiveWorkDays: Int,
        overtimeFrequency: Double,
        restDaysPerWeek: Int
    ) -> BurnoutRiskAssessment {
        var riskScore = 0.0
        var factors: [RiskFactor] = []
        
        // High weekly hours
        if weeklyHours > 50 {
            riskScore += 0.25
            factors.append(RiskFactor(
                name: "Excessive Hours",
                severity: .high,
                description: "Working over 50 hours per week increases burnout risk."
            ))
        } else if weeklyHours > 45 {
            riskScore += 0.15
            factors.append(RiskFactor(
                name: "High Hours",
                severity: .medium,
                description: "Working 45-50 hours per week may lead to fatigue."
            ))
        }
        
        // Consecutive work days
        if consecutiveWorkDays >= 7 {
            riskScore += 0.3
            factors.append(RiskFactor(
                name: "No Rest Days",
                severity: .high,
                description: "Working 7+ consecutive days without rest is unsustainable."
            ))
        } else if consecutiveWorkDays >= 5 {
            riskScore += 0.15
            factors.append(RiskFactor(
                name: "Long Stretch",
                severity: .medium,
                description: "Working 5-6 consecutive days may cause fatigue."
            ))
        }
        
        // Overtime frequency
        if overtimeFrequency > 0.5 {
            riskScore += 0.2
            factors.append(RiskFactor(
                name: "Frequent Overtime",
                severity: .medium,
                description: "Over 50% of shifts include overtime."
            ))
        }
        
        // Rest days
        if restDaysPerWeek < 1 {
            riskScore += 0.25
            factors.append(RiskFactor(
                name: "Insufficient Rest",
                severity: .high,
                description: "Less than 1 rest day per week."
            ))
        } else if restDaysPerWeek < 2 {
            riskScore += 0.1
            factors.append(RiskFactor(
                name: "Limited Rest",
                severity: .low,
                description: "Only 1 rest day per week."
            ))
        }
        
        let level: BurnoutRiskLevel
        switch riskScore {
        case 0..<0.25: level = .low
        case 0.25..<0.5: level = .moderate
        case 0.5..<0.75: level = .high
        default: level = .critical
        }
        
        var recommendations: [String] = []
        if riskScore >= 0.5 {
            recommendations.append("Consider taking a day off soon.")
            recommendations.append("Review your schedule for opportunities to reduce hours.")
        }
        if restDaysPerWeek < 2 {
            recommendations.append("Try to schedule at least 2 rest days per week.")
        }
        
        return BurnoutRiskAssessment(
            level: level,
            score: min(1.0, riskScore),
            factors: factors,
            recommendations: recommendations
        )
    }
}

// MARK: - Prediction Models

struct HoursProjection {
    let projectedTotal: Double
    let dailyRate: Double
    let daysRemaining: Int
    let onTrack: Bool
    let targetHours: Double
    
    var progressPercent: Double {
        guard targetHours > 0 else { return 0 }
        return min(1.0, projectedTotal / targetHours)
    }
}

struct OvertimePrediction {
    let probability: Double
    let predictedHours: Double
    let scheduledHours: Double
    let warnings: [String]
    
    var hasOvertime: Bool {
        predictedHours > 0
    }
}

struct ShiftSuggestion: Identifiable {
    let id = UUID()
    let timeSlot: ShiftTimeSlot
    let reason: String
    let confidence: Double
}

struct BurnoutRiskAssessment {
    let level: BurnoutRiskLevel
    let score: Double
    let factors: [RiskFactor]
    let recommendations: [String]
}

enum BurnoutRiskLevel: String {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

struct RiskFactor: Identifiable {
    let id = UUID()
    let name: String
    let severity: Severity
    let description: String
    
    enum Severity {
        case low
        case medium
        case high
    }
}
