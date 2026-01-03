import WidgetKit
import SwiftUI

/// Complication configuration for Apple Watch faces.
struct ShiftComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShiftComplicationEntry {
        ShiftComplicationEntry(date: Date(), shift: nil, hours: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ShiftComplicationEntry) -> Void) {
        let entry = ShiftComplicationEntry(
            date: Date(),
            shift: previewShift,
            hours: previewHours
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShiftComplicationEntry>) -> Void) {
        // Load data from shared container
        let data = loadComplicationData()
        
        var entries: [ShiftComplicationEntry] = []
        let now = Date()
        
        // Create entries for the next hour
        for minuteOffset in stride(from: 0, to: 60, by: 15) {
            guard let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now) else {
                continue
            }
            let entry = ShiftComplicationEntry(
                date: entryDate,
                shift: data.currentShift,
                hours: data.hours
            )
            entries.append(entry)
        }
        
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now)
            ?? now.addingTimeInterval(15 * 60)
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // MARK: - Data Loading
    
    private func loadComplicationData() -> (currentShift: WatchShiftData?, hours: WatchHoursData?) {
        guard let data = UserDefaults.standard.data(forKey: "cachedWatchData"),
              let container = try? JSONDecoder().decode(WatchDataContainer.self, from: data) else {
            return (nil, nil)
        }
        return (container.currentShift, container.hoursData)
    }
    
    private var previewShift: WatchShiftData {
        WatchShiftData(
            id: UUID(),
            title: "Day Shift",
            scheduledStart: Date().addingTimeInterval(-3600),
            scheduledEnd: Date().addingTimeInterval(3600 * 6),
            actualStart: Date().addingTimeInterval(-3600),
            actualEnd: nil,
            status: .inProgress,
            rateMultiplier: 1.0,
            rateLabel: nil,
            location: nil
        )
    }
    
    private var previewHours: WatchHoursData {
        WatchHoursData(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(3600 * 24 * 14),
            totalHours: 32.5,
            regularHours: 28.0,
            premiumHours: 4.5,
            targetHours: 40.0,
            estimatedPayCents: 125000
        )
    }
}

/// Timeline entry for complications
struct ShiftComplicationEntry: TimelineEntry {
    let date: Date
    let shift: WatchShiftData?
    let hours: WatchHoursData?
}

/// Main complication widget
struct ShiftComplication: Widget {
    let kind: String = "ShiftComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShiftComplicationProvider()) { entry in
            ShiftComplicationView(entry: entry)
        }
        .configurationDisplayName("Shift Status")
        .description("Shows current shift status and hours progress.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

// MARK: - Complication Views

struct ShiftComplicationView: View {
    let entry: ShiftComplicationEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        @unknown default:
            circularView
        }
    }
    
    // MARK: - Circular
    
    private var circularView: some View {
        ZStack {
            if let shift = entry.shift, shift.isInProgress {
                // Show elapsed time
                Gauge(value: shiftProgress(shift)) {
                    Image(systemName: "briefcase.fill")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(.green)
            } else if let hours = entry.hours {
                // Show hours progress
                Gauge(value: hours.progress) {
                    Image(systemName: "clock.fill")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(.blue)
            } else {
                Image(systemName: "calendar")
                    .font(.title3)
            }
        }
    }
    
    // MARK: - Rectangular
    
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let shift = entry.shift, shift.isInProgress {
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(shift.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                if let remaining = shift.remainingFormatted {
                    Text("\(remaining) left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                ProgressView(value: shiftProgress(shift))
                    .tint(.green)
            } else if let hours = entry.hours {
                HStack {
                    Text("Hours")
                        .font(.headline)
                    Spacer()
                    Text("\(hours.hoursFormatted)/\(Int(hours.targetHours))h")
                        .font(.caption)
                }
                
                ProgressView(value: hours.progress)
                    .tint(.blue)
                
                Text(hours.periodFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("ShiftPro")
                    .font(.headline)
                Text("No active shift")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Corner
    
    private var cornerView: some View {
        if let shift = entry.shift, shift.isInProgress {
            Text(shift.elapsedFormatted ?? "0m")
                .font(.headline)
                .widgetCurvesContent()
                .widgetLabel {
                    Gauge(value: shiftProgress(shift)) {
                        Text("Shift")
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(.green)
                }
        } else if let hours = entry.hours {
            Text(hours.hoursFormatted + "h")
                .font(.headline)
                .widgetCurvesContent()
                .widgetLabel {
                    Gauge(value: hours.progress) {
                        Text("Hours")
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(.blue)
                }
        } else {
            Image(systemName: "calendar")
                .widgetCurvesContent()
        }
    }
    
    // MARK: - Inline
    
    private var inlineView: some View {
        if let shift = entry.shift, shift.isInProgress {
            Label(shift.remainingFormatted ?? "Active", systemImage: "briefcase.fill")
        } else if let hours = entry.hours {
            Label("\(hours.hoursFormatted)h", systemImage: "clock")
        } else {
            Label("No shift", systemImage: "calendar")
        }
    }
    
    // MARK: - Helpers
    
    private func shiftProgress(_ shift: WatchShiftData) -> Double {
        guard let elapsed = shift.elapsedMinutes else { return 0 }
        let total = shift.durationMinutes
        guard total > 0 else { return 0 }
        return min(1.0, Double(elapsed) / Double(total))
    }
}

#Preview(as: .accessoryCircular) {
    ShiftComplication()
} timeline: {
    ShiftComplicationEntry(date: Date(), shift: nil, hours: nil)
}
