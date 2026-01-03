import Foundation
import WidgetKit

/// Provides data access for widgets via App Groups container.
enum WidgetDataProvider {
    static let appGroupIdentifier = "group.com.shiftpro.shared"
    static let dataFileName = "widget_data.json"
    
    private static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    private static var dataFileURL: URL? {
        sharedContainerURL?.appendingPathComponent(dataFileName)
    }
    
    /// Loads widget data from the shared App Groups container.
    static func loadData() -> WidgetDataContainer {
        guard let url = dataFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? readData(from: url),
              let container = try? JSONDecoder().decode(WidgetDataContainer.self, from: data) else {
            return .empty
        }
        return container
    }
    
    /// Saves widget data to the shared App Groups container.
    /// Called by the main app when shift data changes.
    static func saveData(_ container: WidgetDataContainer) {
        guard let url = dataFileURL,
              let data = try? JSONEncoder().encode(container) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }
    
    /// Requests all widgets to reload their timelines.
    static func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Requests a specific widget kind to reload.
    static func reloadTimeline(for kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    private static func readData(from url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        if let data = try handle.readToEnd() {
            return data
        }
        return Data()
    }
}

// MARK: - Timeline Entry

struct ShiftWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataContainer
    let configuration: ConfigurationAppIntent?
    
    static let placeholder = ShiftWidgetEntry(
        date: Date(),
        data: .empty,
        configuration: nil
    )
    
    static func preview() -> ShiftWidgetEntry {
        let now = Date()
        let calendar = Calendar.current
        
        let shiftStart = calendar.date(byAdding: .hour, value: -2, to: now)
            ?? now.addingTimeInterval(-2 * 60 * 60)
        let shiftEnd = calendar.date(byAdding: .hour, value: 6, to: now)
            ?? now.addingTimeInterval(6 * 60 * 60)
        
        let currentShift = WidgetShiftData(
            id: UUID(),
            title: "Day Shift",
            scheduledStart: shiftStart,
            scheduledEnd: shiftEnd,
            actualStart: shiftStart,
            actualEnd: nil,
            status: .inProgress,
            rateMultiplier: 1.0,
            rateLabel: nil,
            location: "Central Station",
            notes: nil
        )
        
        let nextShift = WidgetShiftData(
            id: UUID(),
            title: "Night Shift",
            scheduledStart: calendar.date(byAdding: .day, value: 1, to: now)
                ?? now.addingTimeInterval(24 * 60 * 60),
            scheduledEnd: calendar.date(byAdding: .hour, value: 32, to: now)
                ?? now.addingTimeInterval(32 * 60 * 60),
            actualStart: nil,
            actualEnd: nil,
            status: .scheduled,
            rateMultiplier: 1.3,
            rateLabel: "Night",
            location: "North District",
            notes: nil
        )
        
        let hoursData = WidgetHoursData(
            periodStart: calendar.date(byAdding: .day, value: -7, to: now)
                ?? now.addingTimeInterval(-7 * 24 * 60 * 60),
            periodEnd: calendar.date(byAdding: .day, value: 7, to: now)
                ?? now.addingTimeInterval(7 * 24 * 60 * 60),
            totalHours: 32.5,
            regularHours: 28.0,
            premiumHours: 4.5,
            targetHours: 80.0,
            estimatedPayCents: 187500
        )
        
        return ShiftWidgetEntry(
            date: now,
            data: WidgetDataContainer(
                currentShift: currentShift,
                upcomingShifts: [nextShift],
                hoursData: hoursData,
                lastUpdated: now
            ),
            configuration: nil
        )
    }
}

// MARK: - Configuration Intent

import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "ShiftPro Widget"
    static var description = IntentDescription("Configure your shift widget display.")
    
    @Parameter(title: "Show Location", default: true)
    var showLocation: Bool
    
    @Parameter(title: "Show Rate", default: true)
    var showRate: Bool
    
    @Parameter(title: "Compact Mode", default: false)
    var compactMode: Bool
}

// MARK: - Widget Timeline Provider

struct ShiftTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = ShiftWidgetEntry
    typealias Intent = ConfigurationAppIntent
    
    func placeholder(in context: Context) -> Entry {
        .placeholder
    }
    
    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        if context.isPreview {
            return .preview()
        }
        return Entry(
            date: Date(),
            data: WidgetDataProvider.loadData(),
            configuration: configuration
        )
    }
    
    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let data = WidgetDataProvider.loadData()
        let currentDate = Date()
        var entries: [Entry] = []
        
        // Create entries for the next 8 hours with 15-minute intervals
        // This ensures the widget updates regularly without excessive refreshes
        for minuteOffset in stride(from: 0, through: 480, by: 15) {
            if let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate) {
                entries.append(Entry(date: entryDate, data: data, configuration: configuration))
            }
        }
        
        // Schedule next refresh based on shift timing
        let nextRefresh: Date
        if let currentShift = data.currentShift, currentShift.status == .inProgress {
            // If a shift is in progress, refresh at the end time
            nextRefresh = currentShift.scheduledEnd
        } else if let nextShift = data.upcomingShifts.first {
            // If there's an upcoming shift, refresh at start time
            nextRefresh = nextShift.scheduledStart
        } else {
            // Default: refresh in 1 hour
            nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)
                ?? currentDate.addingTimeInterval(60 * 60)
        }
        
        return Timeline(entries: entries, policy: .after(nextRefresh))
    }
}

// MARK: - Simple Timeline Provider (for widgets without configuration)

struct SimpleShiftTimelineProvider: TimelineProvider {
    typealias Entry = ShiftWidgetEntry
    
    func placeholder(in context: Context) -> Entry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview {
            completion(.preview())
        } else {
            completion(Entry(
                date: Date(),
                data: WidgetDataProvider.loadData(),
                configuration: nil
            ))
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let data = WidgetDataProvider.loadData()
        let currentDate = Date()
        var entries: [Entry] = []
        
        for minuteOffset in stride(from: 0, through: 480, by: 15) {
            if let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate) {
                entries.append(Entry(date: entryDate, data: data, configuration: nil))
            }
        }
        
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)
            ?? currentDate.addingTimeInterval(60 * 60)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }
}
