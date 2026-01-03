import Foundation
import SwiftData

/// Provides data access for Siri Intents.
/// Lightweight wrapper around SwiftData for intent handlers.
@MainActor
final class ShiftIntentDataProvider {
    static let shared = ShiftIntentDataProvider()
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    private init() {
        setupModelContainer()
    }
    
    private func setupModelContainer() {
        do {
            let schema = Schema([
                Shift.self,
                ShiftPattern.self,
                PayPeriod.self,
                UserProfile.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier("group.com.shiftpro.shared")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = modelContainer?.mainContext
        } catch {
            print("Failed to create model container for intents: \(error)")
        }
    }
    
    // MARK: - Shift Queries
    
    func getCurrentShift() async throws -> IntentShiftData? {
        guard let context = modelContext else { return nil }
        
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil && shift.statusRaw == 1
            }
        )
        
        guard let shift = try context.fetch(descriptor).first else {
            return nil
        }
        
        return IntentShiftData(from: shift)
    }
    
    func findScheduledShift() async throws -> IntentShiftData? {
        guard let context = modelContext else { return nil }
        
        let now = Date()
        let tolerance = TimeInterval(30 * 60) // 30 minutes before/after scheduled time
        let startWindow = now.addingTimeInterval(-tolerance)
        let endWindow = now.addingTimeInterval(tolerance)
        
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil &&
                shift.statusRaw == 0 &&
                shift.scheduledStart >= startWindow &&
                shift.scheduledStart <= endWindow
            },
            sortBy: [SortDescriptor(\.scheduledStart, order: .forward)]
        )
        
        guard let shift = try context.fetch(descriptor).first else {
            return nil
        }
        
        return IntentShiftData(from: shift)
    }
    
    func getNextShift() async throws -> IntentShiftData? {
        guard let context = modelContext else { return nil }
        
        let now = Date()
        
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil &&
                shift.statusRaw == 0 &&
                shift.scheduledStart > now
            },
            sortBy: [SortDescriptor(\.scheduledStart, order: .forward)]
        )
        
        guard let shift = try context.fetch(descriptor).first else {
            return nil
        }
        
        return IntentShiftData(from: shift)
    }
    
    // MARK: - Shift Actions
    
    func clockIn(shift: IntentShiftData) async throws {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { s in
                s.id == shift.id
            }
        )
        
        guard let shiftModel = try context.fetch(descriptor).first else { return }
        
        shiftModel.clockIn()
        try context.save()
    }
    
    func clockOut(shift: IntentShiftData) async throws -> Double {
        guard let context = modelContext else { return 0 }
        
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { s in
                s.id == shift.id
            }
        )
        
        guard let shiftModel = try context.fetch(descriptor).first else { return 0 }
        
        shiftModel.clockOut()
        try context.save()
        
        return shiftModel.paidHours
    }
    
    func logBreak(shift: IntentShiftData, minutes: Int) async throws {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { s in
                s.id == shift.id
            }
        )
        
        guard let shiftModel = try context.fetch(descriptor).first else { return }
        
        shiftModel.breakMinutes += minutes
        shiftModel.recalculatePaidMinutes()
        try context.save()
    }
    
    func addOvertime(shift: IntentShiftData, hours: Double, multiplier: Double) async throws {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { s in
                s.id == shift.id
            }
        )
        
        guard let shiftModel = try context.fetch(descriptor).first else { return }
        
        shiftModel.premiumMinutes += Int(hours * 60)
        shiftModel.rateMultiplier = multiplier
        try context.save()
    }
    
    // MARK: - Hours Queries
    
    func getWeeklyHours() async throws -> IntentHoursData {
        guard let context = modelContext else {
            return IntentHoursData(total: 0, regular: 0, premium: 0)
        }
        
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return IntentHoursData(total: 0, regular: 0, premium: 0)
        }
        
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil &&
                shift.scheduledStart >= weekStart &&
                shift.scheduledStart < weekEnd
            }
        )
        
        let shifts = try context.fetch(descriptor)
        
        let totalMinutes = shifts.reduce(0) { $0 + $1.paidMinutes }
        let premiumMinutes = shifts.reduce(0) { $0 + $1.premiumMinutes }
        let regularMinutes = totalMinutes - premiumMinutes
        
        return IntentHoursData(
            total: Double(totalMinutes) / 60.0,
            regular: Double(regularMinutes) / 60.0,
            premium: Double(premiumMinutes) / 60.0
        )
    }
    
    func getPayPeriodSummary() async throws -> IntentPayPeriodData {
        guard let context = modelContext else {
            return IntentPayPeriodData.empty
        }
        
        let now = Date()
        
        let periodDescriptor = FetchDescriptor<PayPeriod>(
            predicate: #Predicate<PayPeriod> { period in
                period.startDate <= now && period.endDate >= now
            }
        )
        
        guard let period = try context.fetch(periodDescriptor).first else {
            return IntentPayPeriodData.empty
        }
        
        let shiftDescriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil &&
                shift.scheduledStart >= period.startDate &&
                shift.scheduledStart <= period.endDate
            }
        )
        
        let shifts = try context.fetch(shiftDescriptor)
        
        let totalMinutes = shifts.reduce(0) { $0 + $1.paidMinutes }
        let premiumMinutes = shifts.reduce(0) { $0 + $1.premiumMinutes }
        
        return IntentPayPeriodData(
            totalHours: Double(totalMinutes) / 60.0,
            targetHours: 80.0,
            overtimeHours: Double(premiumMinutes) / 60.0,
            estimatedPay: 0 // Would need base rate from UserProfile
        )
    }
    
    func getOvertimeSummary() async throws -> IntentOvertimeData {
        let summary = try await getPayPeriodSummary()
        return IntentOvertimeData(
            totalHours: summary.overtimeHours,
            estimatedEarnings: summary.overtimeHours * 50 // Placeholder rate
        )
    }
}

// MARK: - Intent Data Types

struct IntentShiftData {
    let id: UUID
    let title: String
    let scheduledStart: Date
    let scheduledEnd: Date
    let actualStart: Date?
    let actualEnd: Date?
    
    init(from shift: Shift) {
        self.id = shift.id
        self.title = shift.pattern?.name ?? "Shift"
        self.scheduledStart = shift.scheduledStart
        self.scheduledEnd = shift.scheduledEnd
        self.actualStart = shift.actualStart
        self.actualEnd = shift.actualEnd
    }
    
    var elapsedFormatted: String {
        guard let start = actualStart else { return "0m" }
        let elapsed = Int(Date().timeIntervalSince(start) / 60)
        let hours = elapsed / 60
        let mins = elapsed % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }
    
    var remainingFormatted: String {
        let remaining = Int(scheduledEnd.timeIntervalSince(Date()) / 60)
        let hours = remaining / 60
        let mins = remaining % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }
    
    var countdownFormatted: String {
        let interval = scheduledStart.timeIntervalSince(Date())
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 24 {
            return "in \(hours / 24) days"
        } else if hours > 0 {
            return "in \(hours) hours"
        } else if minutes > 0 {
            return "in \(minutes) minutes"
        }
        return "now"
    }
}

struct IntentHoursData {
    let total: Double
    let regular: Double
    let premium: Double
}

struct IntentPayPeriodData {
    let totalHours: Double
    let targetHours: Double
    let overtimeHours: Double
    let estimatedPay: Double
    
    var progress: Double {
        guard targetHours > 0 else { return 0 }
        return min(1.0, totalHours / targetHours)
    }
    
    static let empty = IntentPayPeriodData(
        totalHours: 0,
        targetHours: 80,
        overtimeHours: 0,
        estimatedPay: 0
    )
}

struct IntentOvertimeData {
    let totalHours: Double
    let estimatedEarnings: Double
}
