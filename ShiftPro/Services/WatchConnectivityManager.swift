import Foundation
import WatchConnectivity
import SwiftData

/// Manages communication between iPhone and Apple Watch.
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published private(set) var isReachable = false
    @Published private(set) var isPaired = false
    @Published private(set) var isWatchAppInstalled = false
    
    private var session: WCSession?
    private var modelContext: ModelContext?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    /// Configure with the SwiftData model context for data access.
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Sends updated shift data to the watch.
    func syncDataToWatch() {
        guard let session = session,
              session.isPaired,
              session.isWatchAppInstalled else {
            return
        }
        
        let data = buildWatchDataPayload()
        
        do {
            // Use application context for guaranteed delivery
            try session.updateApplicationContext(data)
        } catch {
            print("Failed to update application context: \(error)")
        }
    }
    
    /// Forces an immediate sync when the watch is reachable.
    func sendImmediateUpdate() {
        guard let session = session, session.isReachable else {
            return
        }
        
        let data = buildWatchDataPayload()
        session.sendMessage(data, replyHandler: nil, errorHandler: nil)
    }
    
    // MARK: - Private Methods
    
    private func buildWatchDataPayload() -> [String: Any] {
        guard let modelContext = modelContext else {
            return [:]
        }
        
        // Fetch current shift
        let currentShift = fetchCurrentShift(from: modelContext)
        
        // Fetch upcoming shifts
        let upcomingShifts = fetchUpcomingShifts(from: modelContext)
        
        // Fetch hours data
        let hoursData = fetchHoursData(from: modelContext)
        
        let container = WatchDataPayload(
            currentShift: currentShift,
            upcomingShifts: upcomingShifts,
            hoursData: hoursData,
            lastUpdated: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(container)
            return ["data": jsonData]
        } catch {
            return [:]
        }
    }
    
    private func fetchCurrentShift(from modelContext: ModelContext) -> WatchShiftPayload? {
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil && shift.statusRaw == 1
            },
            sortBy: [SortDescriptor(\.scheduledStart, order: .forward)]
        )
        
        guard let shift = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return mapToWatchPayload(shift)
    }
    
    private func fetchUpcomingShifts(from modelContext: ModelContext) -> [WatchShiftPayload] {
        let now = Date()
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil &&
                shift.statusRaw == 0 &&
                shift.scheduledStart > now &&
                shift.scheduledStart < weekFromNow
            },
            sortBy: [SortDescriptor(\.scheduledStart, order: .forward)]
        )
        
        guard let shifts = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        return shifts.prefix(5).map { mapToWatchPayload($0) }
    }
    
    private func fetchHoursData(from modelContext: ModelContext) -> WatchHoursPayload? {
        let now = Date()
        
        // Fetch all pay periods and filter in-memory to avoid predicate issues
        let periodDescriptor = FetchDescriptor<PayPeriod>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        let dayStart = Calendar.current.startOfDay(for: now)
        guard let allPeriods = try? modelContext.fetch(periodDescriptor),
              let period = allPeriods.first(where: { $0.startDate <= now && $0.endDate >= dayStart }) else {
            return nil
        }
        
        // Fetch all non-deleted shifts and filter in-memory
        let shiftDescriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil
            }
        )
        
        guard let allShifts = try? modelContext.fetch(shiftDescriptor) else {
            return nil
        }
        
        // Filter shifts in-memory for the pay period
        let shifts = allShifts.filter { shift in
            period.contains(date: shift.scheduledStart)
        }
        
        let totalMinutes = shifts.reduce(0) { $0 + $1.paidMinutes }
        let premiumMinutes = shifts.reduce(0) { $0 + $1.premiumMinutes }
        
        return WatchHoursPayload(
            periodStart: period.startDate,
            periodEnd: period.endDate,
            totalHours: Double(totalMinutes) / 60.0,
            regularHours: Double(totalMinutes - premiumMinutes) / 60.0,
            premiumHours: Double(premiumMinutes) / 60.0,
            targetHours: 80.0
        )
    }
    
    private func mapToWatchPayload(_ shift: Shift) -> WatchShiftPayload {
        WatchShiftPayload(
            id: shift.id,
            title: shift.pattern?.name ?? "Shift",
            scheduledStart: shift.scheduledStart,
            scheduledEnd: shift.scheduledEnd,
            actualStart: shift.actualStart,
            actualEnd: shift.actualEnd,
            status: shift.statusRaw,
            rateMultiplier: shift.rateMultiplier,
            rateLabel: shift.rateLabel,
            location: shift.locationDisplay
        )
    }
    
    // MARK: - Handle Watch Actions
    
    private func handleWatchAction(_ message: [String: Any]) -> [String: Any] {
        guard let action = message["action"] as? String,
              let modelContext = modelContext else {
            return ["success": false, "error": "Invalid action"]
        }
        
        switch action {
        case "refreshData":
            return buildWatchDataPayload()
            
        case "clockIn":
            return handleClockIn(modelContext: modelContext)
            
        case "clockOut":
            return handleClockOut(modelContext: modelContext)
            
        case "logBreak":
            let minutes = message["minutes"] as? Int ?? 30
            return handleLogBreak(minutes: minutes, modelContext: modelContext)
            
        default:
            return ["success": false, "error": "Unknown action"]
        }
    }
    
    private func handleClockIn(modelContext: ModelContext) -> [String: Any] {
        // Find the next scheduled shift
        let now = Date()
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil &&
                shift.statusRaw == 0 &&
                shift.scheduledStart <= now
            },
            sortBy: [SortDescriptor(\.scheduledStart, order: .reverse)]
        )
        
        guard let shift = try? modelContext.fetch(descriptor).first else {
            return ["success": false, "error": "No shift to start"]
        }
        
        shift.clockIn()
        try? modelContext.save()
        
        var response = buildWatchDataPayload()
        response["success"] = true
        return response
    }
    
    private func handleClockOut(modelContext: ModelContext) -> [String: Any] {
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil && shift.statusRaw == 1
            }
        )
        
        guard let shift = try? modelContext.fetch(descriptor).first else {
            return ["success": false, "error": "No active shift"]
        }
        
        shift.clockOut()
        try? modelContext.save()
        
        var response = buildWatchDataPayload()
        response["success"] = true
        return response
    }
    
    private func handleLogBreak(minutes: Int, modelContext: ModelContext) -> [String: Any] {
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil && shift.statusRaw == 1
            }
        )
        
        guard let shift = try? modelContext.fetch(descriptor).first else {
            return ["success": false, "error": "No active shift"]
        }
        
        shift.breakMinutes += minutes
        shift.recalculatePaidMinutes()
        try? modelContext.save()
        
        var response = buildWatchDataPayload()
        response["success"] = true
        return response
    }
}

// MARK: - WCSessionDelegate

// swiftlint:disable line_length
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            let response = self.handleWatchAction(message)
            replyHandler(response)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            _ = self.handleWatchAction(message)
        }
    }
}
// swiftlint:enable line_length

// MARK: - Payload Types

struct WatchDataPayload: Codable {
    let currentShift: WatchShiftPayload?
    let upcomingShifts: [WatchShiftPayload]
    let hoursData: WatchHoursPayload?
    let lastUpdated: Date
}

struct WatchShiftPayload: Codable {
    let id: UUID
    let title: String
    let scheduledStart: Date
    let scheduledEnd: Date
    let actualStart: Date?
    let actualEnd: Date?
    let status: Int16
    let rateMultiplier: Double
    let rateLabel: String?
    let location: String?
}

struct WatchHoursPayload: Codable {
    let periodStart: Date
    let periodEnd: Date
    let totalHours: Double
    let regularHours: Double
    let premiumHours: Double
    let targetHours: Double
}
