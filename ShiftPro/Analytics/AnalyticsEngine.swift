import Combine
import Foundation
import SwiftData

/// Core analytics engine providing data aggregation and metrics computation.
@MainActor
final class AnalyticsEngine: ObservableObject {
    @Published private(set) var weeklyMetrics: WeeklyMetrics?
    @Published private(set) var monthlyMetrics: MonthlyMetrics?
    @Published private(set) var yearlyMetrics: YearlyMetrics?
    @Published private(set) var insights: [AnalyticsInsight] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    
    init() {}
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Metrics Computation
    
    func refreshAllMetrics() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        guard modelContext != nil else {
            errorMessage = "Analytics data is unavailable right now."
            weeklyMetrics = nil
            monthlyMetrics = nil
            yearlyMetrics = nil
            insights = []
            return
        }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.computeWeeklyMetrics() }
            group.addTask { await self.computeMonthlyMetrics() }
            group.addTask { await self.computeYearlyMetrics() }
        }

        if weeklyMetrics != nil || monthlyMetrics != nil || yearlyMetrics != nil {
            errorMessage = nil
        }
        
        await generateInsights()
    }
    
    func computeWeeklyMetrics() async {
        guard let context = modelContext else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        
        do {
            // Fetch shifts for this week
            let shifts = try fetchShifts(from: weekStart, to: weekEnd, context: context)
            
            // Also fetch previous week for comparison
            let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart)!
            let prevShifts = try fetchShifts(from: prevWeekStart, to: weekStart, context: context)
            
            let currentHours = computeHours(from: shifts)
            let previousHours = computeHours(from: prevShifts)
            
            weeklyMetrics = WeeklyMetrics(
                periodStart: weekStart,
                periodEnd: weekEnd,
                totalHours: currentHours.total,
                regularHours: currentHours.regular,
                premiumHours: currentHours.premium,
                shiftCount: shifts.count,
                averageShiftDuration: shifts.isEmpty ? 0 : currentHours.total / Double(shifts.count),
                comparedToPrevious: previousHours.total > 0 ? (currentHours.total - previousHours.total) / previousHours.total : 0,
                byDay: computeHoursByDay(shifts: shifts, weekStart: weekStart)
            )
        } catch {
            weeklyMetrics = nil
            errorMessage = "We couldn't load weekly analytics."
        }
        
    }
    
    func computeMonthlyMetrics() async {
        guard let context = modelContext else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        
        do {
            let shifts = try fetchShifts(from: monthStart, to: monthEnd, context: context)
            let prevMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart)!
            let prevShifts = try fetchShifts(from: prevMonthStart, to: monthStart, context: context)
            
            let currentHours = computeHours(from: shifts)
            let previousHours = computeHours(from: prevShifts)
            
            monthlyMetrics = MonthlyMetrics(
                periodStart: monthStart,
                periodEnd: monthEnd,
                totalHours: currentHours.total,
                regularHours: currentHours.regular,
                premiumHours: currentHours.premium,
                overtimeHours: currentHours.overtime,
                shiftCount: shifts.count,
                averageShiftDuration: shifts.isEmpty ? 0 : currentHours.total / Double(shifts.count),
                comparedToPrevious: previousHours.total > 0 ? (currentHours.total - previousHours.total) / previousHours.total : 0,
                byWeek: computeHoursByWeek(shifts: shifts, monthStart: monthStart)
            )
        } catch {
            monthlyMetrics = nil
            errorMessage = "We couldn't load monthly analytics."
        }
    }
    
    func computeYearlyMetrics() async {
        guard let context = modelContext else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)!
        
        do {
            let shifts = try fetchShifts(from: yearStart, to: yearEnd, context: context)
            let prevYearStart = calendar.date(byAdding: .year, value: -1, to: yearStart)!
            let prevShifts = try fetchShifts(from: prevYearStart, to: yearStart, context: context)
            
            let currentHours = computeHours(from: shifts)
            let previousHours = computeHours(from: prevShifts)
            
            yearlyMetrics = YearlyMetrics(
                year: calendar.component(.year, from: now),
                totalHours: currentHours.total,
                regularHours: currentHours.regular,
                premiumHours: currentHours.premium,
                overtimeHours: currentHours.overtime,
                shiftCount: shifts.count,
                averageShiftDuration: shifts.isEmpty ? 0 : currentHours.total / Double(shifts.count),
                comparedToPrevious: previousHours.total > 0 ? (currentHours.total - previousHours.total) / previousHours.total : 0,
                byMonth: computeHoursByMonth(shifts: shifts, yearStart: yearStart)
            )
        } catch {
            yearlyMetrics = nil
            errorMessage = "We couldn't load yearly analytics."
        }
    }
    
    // MARK: - Insights Generation
    
    private func generateInsights() async {
        var newInsights: [AnalyticsInsight] = []
        
        // Overtime pattern insight
        if let monthly = monthlyMetrics, monthly.totalHours > 0, monthly.overtimeHours > monthly.totalHours * 0.2 {
            let otHours = String(format: "%.1f", monthly.overtimeHours)
            let otPercent = Int(monthly.overtimeHours / monthly.totalHours * 100)
            newInsights.append(AnalyticsInsight(
                id: UUID(),
                type: .warning,
                title: "High Overtime",
                message: "You've worked \(otHours) overtime hours this month, " +
                         "which is \(otPercent)% of your total hours.",
                actionLabel: "View Details",
                priority: .high
            ))
        }
        
        // Improvement trend insight
        if let weekly = weeklyMetrics, weekly.comparedToPrevious > 0.1 {
            newInsights.append(AnalyticsInsight(
                id: UUID(),
                type: .positive,
                title: "Hours Increasing",
                message: "Your hours are up \(Int(weekly.comparedToPrevious * 100))% compared to last week.",
                actionLabel: nil,
                priority: .medium
            ))
        }
        
        // Consistency insight
        if let weekly = weeklyMetrics, let byDay = weekly.byDay {
            let variance = computeVariance(byDay.map { $0.hours })
            if variance < 2.0 && !byDay.isEmpty {
                newInsights.append(AnalyticsInsight(
                    id: UUID(),
                    type: .positive,
                    title: "Consistent Schedule",
                    message: "Your shifts are well-distributed throughout the week.",
                    actionLabel: nil,
                    priority: .low
                ))
            }
        }
        
        // Premium rate insight
        if let monthly = monthlyMetrics, monthly.totalHours > 0, monthly.premiumHours > 0 {
            let premiumPercent = monthly.premiumHours / monthly.totalHours * 100
            newInsights.append(AnalyticsInsight(
                id: UUID(),
                type: .info,
                title: "Premium Rate Shifts",
                message: "\(Int(premiumPercent))% of your hours this month are at premium rates.",
                actionLabel: "View Breakdown",
                priority: .medium
            ))
        }
        
        insights = newInsights.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // MARK: - Helper Methods
    
    private func fetchShifts(from start: Date, to end: Date, context: ModelContext) throws -> [Shift] {
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil &&
                shift.scheduledStart >= start &&
                shift.scheduledStart < end
            },
            sortBy: [SortDescriptor(\.scheduledStart, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
    
    private func computeHours(from shifts: [Shift]) -> HoursBreakdown {
        let totalMinutes = shifts.reduce(0) { $0 + $1.paidMinutes }
        let premiumMinutes = shifts.reduce(0) { $0 + $1.premiumMinutes }
        let regularMinutes = totalMinutes - premiumMinutes
        
        // Overtime is premium hours above standard multiplier
        let overtimeMinutes = shifts.filter { $0.rateMultiplier > 1.0 }.reduce(0) { $0 + $1.paidMinutes }
        
        return HoursBreakdown(
            total: Double(totalMinutes) / 60.0,
            regular: Double(regularMinutes) / 60.0,
            premium: Double(premiumMinutes) / 60.0,
            overtime: Double(overtimeMinutes) / 60.0
        )
    }
    
    private func computeHoursByDay(shifts: [Shift], weekStart: Date) -> [DayHours] {
        guard !shifts.isEmpty else { return [] }
        let calendar = Calendar.current
        var byDay: [Int: Double] = [:]
        
        for shift in shifts {
            let weekday = calendar.component(.weekday, from: shift.scheduledStart)
            byDay[weekday, default: 0] += Double(shift.paidMinutes) / 60.0
        }
        
        return (1...7).map { weekday in
            DayHours(
                dayOfWeek: weekday,
                hours: byDay[weekday] ?? 0
            )
        }
    }
    
    private func computeHoursByWeek(shifts: [Shift], monthStart: Date) -> [WeekHours] {
        let calendar = Calendar.current
        var byWeek: [Int: Double] = [:]
        
        for shift in shifts {
            let week = calendar.component(.weekOfMonth, from: shift.scheduledStart)
            byWeek[week, default: 0] += Double(shift.paidMinutes) / 60.0
        }
        
        return byWeek.map { WeekHours(weekOfMonth: $0.key, hours: $0.value) }
            .sorted { $0.weekOfMonth < $1.weekOfMonth }
    }
    
    private func computeHoursByMonth(shifts: [Shift], yearStart: Date) -> [MonthHours] {
        let calendar = Calendar.current
        var byMonth: [Int: Double] = [:]
        
        for shift in shifts {
            let month = calendar.component(.month, from: shift.scheduledStart)
            byMonth[month, default: 0] += Double(shift.paidMinutes) / 60.0
        }
        
        return byMonth.map { MonthHours(month: $0.key, hours: $0.value) }
            .sorted { $0.month < $1.month }
    }
    
    private func computeVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
}

// MARK: - Metrics Models

struct HoursBreakdown {
    let total: Double
    let regular: Double
    let premium: Double
    let overtime: Double
}

struct WeeklyMetrics {
    let periodStart: Date
    let periodEnd: Date
    let totalHours: Double
    let regularHours: Double
    let premiumHours: Double
    let shiftCount: Int
    let averageShiftDuration: Double
    let comparedToPrevious: Double
    let byDay: [DayHours]?
}

struct MonthlyMetrics {
    let periodStart: Date
    let periodEnd: Date
    let totalHours: Double
    let regularHours: Double
    let premiumHours: Double
    let overtimeHours: Double
    let shiftCount: Int
    let averageShiftDuration: Double
    let comparedToPrevious: Double
    let byWeek: [WeekHours]?
}

struct YearlyMetrics {
    let year: Int
    let totalHours: Double
    let regularHours: Double
    let premiumHours: Double
    let overtimeHours: Double
    let shiftCount: Int
    let averageShiftDuration: Double
    let comparedToPrevious: Double
    let byMonth: [MonthHours]?
}

struct DayHours: Identifiable {
    let id = UUID()
    let dayOfWeek: Int
    let hours: Double
    
    var dayName: String {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols[dayOfWeek - 1]
    }
}

struct WeekHours: Identifiable {
    let id = UUID()
    let weekOfMonth: Int
    let hours: Double
}

struct MonthHours: Identifiable {
    let id = UUID()
    let month: Int
    let hours: Double
    
    var monthName: String {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[month - 1]
    }
}

struct AnalyticsInsight: Identifiable {
    let id: UUID
    let type: InsightType
    let title: String
    let message: String
    let actionLabel: String?
    let priority: InsightPriority
    
    enum InsightType {
        case positive
        case warning
        case info
        case suggestion
    }
    
    enum InsightPriority: Int {
        case low = 0
        case medium = 1
        case high = 2
    }
}
