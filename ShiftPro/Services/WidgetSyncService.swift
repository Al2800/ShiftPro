import Foundation
import SwiftData
import WidgetKit

/// Service responsible for syncing shift data to iOS Widgets via App Groups.
/// Call `syncToWidgets()` whenever shift data changes.
@MainActor
final class WidgetSyncService: ObservableObject {
    static let shared = WidgetSyncService()
    
    private let appGroupIdentifier = "group.com.shiftpro.shared"
    private let dataFileName = "widget_data.json"
    
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    private var dataFileURL: URL? {
        sharedContainerURL?.appendingPathComponent(dataFileName)
    }
    
    /// Syncs current shift data to widgets.
    /// Call this after any shift CRUD operations.
    func syncToWidgets(modelContext: ModelContext) {
        let container = buildWidgetDataContainer(from: modelContext)
        saveAndReload(container)
    }
    
    /// Quick sync for when a shift's status changes (clock in/out).
    func syncShiftStatusChange(modelContext: ModelContext) {
        syncToWidgets(modelContext: modelContext)
        
        // Reload specific widgets that show current shift status
        WidgetCenter.shared.reloadTimelines(ofKind: "CurrentShiftWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "ScheduleOverviewWidget")
    }
    
    /// Sync hours data specifically (after pay period calculations).
    func syncHoursUpdate(modelContext: ModelContext) {
        syncToWidgets(modelContext: modelContext)
        
        // Reload hours-related widgets
        WidgetCenter.shared.reloadTimelines(ofKind: "HoursSummaryWidget")
    }
    
    /// Forces all widgets to reload their timelines.
    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Private Methods
    
    private func buildWidgetDataContainer(from modelContext: ModelContext) -> WidgetDataContainer {
        let now = Date()
        
        // Fetch current in-progress shift
        let currentShift = fetchCurrentShift(from: modelContext, now: now)
        
        // Fetch upcoming shifts (next 7 days)
        let upcomingShifts = fetchUpcomingShifts(from: modelContext, now: now)
        
        // Fetch current pay period hours
        let hoursData = fetchHoursData(from: modelContext, now: now)
        
        return WidgetDataContainer(
            currentShift: currentShift,
            upcomingShifts: upcomingShifts,
            hoursData: hoursData,
            lastUpdated: now
        )
    }
    
    private func fetchCurrentShift(from modelContext: ModelContext, now: Date) -> WidgetShiftData? {
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil &&
                shift.statusRaw == 1 // .inProgress
            },
            sortBy: [SortDescriptor(\.scheduledStart, order: .forward)]
        )
        
        guard let shift = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return mapToWidgetShiftData(shift)
    }
    
    private func fetchUpcomingShifts(from modelContext: ModelContext, now: Date) -> [WidgetShiftData] {
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        
        let descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil &&
                shift.statusRaw == 0 && // .scheduled
                shift.scheduledStart > now &&
                shift.scheduledStart < weekFromNow
            },
            sortBy: [SortDescriptor(\.scheduledStart, order: .forward)]
        )
        
        guard let shifts = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        return shifts.prefix(10).map { mapToWidgetShiftData($0) }
    }
    
    private func fetchHoursData(from modelContext: ModelContext, now: Date) -> WidgetHoursData? {
        // Fetch current pay period
        let descriptor = FetchDescriptor<PayPeriod>(
            predicate: #Predicate<PayPeriod> { period in
                period.startDate <= now && period.endDate >= now
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        guard let period = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        
        // Calculate hours from shifts in this period
        let shiftDescriptor = FetchDescriptor<Shift>(
            predicate: #Predicate<Shift> { shift in
                shift.deletedAt == nil &&
                shift.scheduledStart >= period.startDate &&
                shift.scheduledStart <= period.endDate
            }
        )
        
        guard let shifts = try? modelContext.fetch(shiftDescriptor) else {
            return nil
        }
        
        let totalMinutes = shifts.reduce(0) { $0 + $1.paidMinutes }
        let premiumMinutes = shifts.reduce(0) { $0 + $1.premiumMinutes }
        let regularMinutes = totalMinutes - premiumMinutes
        
        let totalHours = Double(totalMinutes) / 60.0
        let regularHours = Double(regularMinutes) / 60.0
        let premiumHours = Double(premiumMinutes) / 60.0
        
        // Get target hours from user profile or use default
        let targetHours: Double = 80.0 // Default bi-weekly target
        
        // Estimate pay (simplified calculation)
        let estimatedPayCents: Int? = nil // Would need base rate from user profile
        
        return WidgetHoursData(
            periodStart: period.startDate,
            periodEnd: period.endDate,
            totalHours: totalHours,
            regularHours: regularHours,
            premiumHours: premiumHours,
            targetHours: targetHours,
            estimatedPayCents: estimatedPayCents
        )
    }
    
    private func mapToWidgetShiftData(_ shift: Shift) -> WidgetShiftData {
        let widgetStatus: WidgetShiftStatus
        switch shift.status {
        case .scheduled:
            widgetStatus = .scheduled
        case .inProgress:
            widgetStatus = .inProgress
        case .completed:
            widgetStatus = .completed
        case .cancelled:
            widgetStatus = .cancelled
        }
        
        return WidgetShiftData(
            id: shift.id,
            title: shift.pattern?.name ?? "Shift",
            scheduledStart: shift.scheduledStart,
            scheduledEnd: shift.scheduledEnd,
            actualStart: shift.actualStart,
            actualEnd: shift.actualEnd,
            status: widgetStatus,
            rateMultiplier: shift.rateMultiplier,
            rateLabel: shift.rateLabel,
            location: nil, // Could be added if location tracking is implemented
            notes: shift.notes
        )
    }
    
    private func saveAndReload(_ container: WidgetDataContainer) {
        guard let url = dataFileURL else {
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(container)
            try data.write(to: url, options: .atomic)
            
            // Trigger widget timeline refresh
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Silently fail - widgets will show stale data
            print("Failed to sync widget data: \(error)")
        }
    }
}

// MARK: - WidgetDataContainer Extension for Main App

extension WidgetDataContainer {
    /// Creates an empty container when no data is available.
    static var empty: WidgetDataContainer {
        WidgetDataContainer(
            currentShift: nil,
            upcomingShifts: [],
            hoursData: nil,
            lastUpdated: Date()
        )
    }
}
