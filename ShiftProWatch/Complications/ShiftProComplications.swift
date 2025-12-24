import WidgetKit
import SwiftUI

// MARK: - Complication Entry

struct ShiftComplicationEntry: TimelineEntry {
    let date: Date
    let currentShift: WatchShiftData?
    let nextShift: WatchShiftData?
    let hoursData: WatchHoursData?
    
    static let placeholder = ShiftComplicationEntry(
        date: Date(),
        currentShift: nil,
        nextShift: nil,
        hoursData: nil
    )
}

// MARK: - Timeline Provider

struct ShiftComplicationProvider: TimelineProvider {
    typealias Entry = ShiftComplicationEntry
    
    func placeholder(in context: Context) -> Entry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let entry = ShiftComplicationEntry(
            date: Date(),
            currentShift: loadCurrentShift(),
            nextShift: loadNextShift(),
            hoursData: loadHoursData()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let currentDate = Date()
        var entries: [Entry] = []
        
        // Create entries for the next 4 hours
        for minuteOffset in stride(from: 0, through: 240, by: 15) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = ShiftComplicationEntry(
                date: entryDate,
                currentShift: loadCurrentShift(),
                nextShift: loadNextShift(),
                hoursData: loadHoursData()
            )
            entries.append(entry)
        }
        
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        completion(Timeline(entries: entries, policy: .after(nextUpdate)))
    }
    
    // MARK: - Data Loading
    
    private func loadCurrentShift() -> WatchShiftData? {
        // Load from shared UserDefaults with App Groups
        guard let data = UserDefaults(suiteName: "group.com.shiftpro.shared")?.data(forKey: "currentShift"),
              let shift = try? JSONDecoder().decode(WatchShiftData.self, from: data) else {
            return nil
        }
        return shift
    }
    
    private func loadNextShift() -> WatchShiftData? {
        guard let data = UserDefaults(suiteName: "group.com.shiftpro.shared")?.data(forKey: "nextShift"),
              let shift = try? JSONDecoder().decode(WatchShiftData.self, from: data) else {
            return nil
        }
        return shift
    }
    
    private func loadHoursData() -> WatchHoursData? {
        guard let data = UserDefaults(suiteName: "group.com.shiftpro.shared")?.data(forKey: "hoursData"),
              let hours = try? JSONDecoder().decode(WatchHoursData.self, from: data) else {
            return nil
        }
        return hours
    }
}

// MARK: - Complication Views

struct CornerComplicationView: View {
    let entry: ShiftComplicationEntry
    
    var body: some View {
        if let shift = entry.currentShift, shift.isInProgress {
            VStack(spacing: 0) {
                Image(systemName: "play.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                if let elapsed = shift.elapsedMinutes {
                    Text(formatShort(elapsed))
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }
        } else if let next = entry.nextShift ?? entry.currentShift {
            VStack(spacing: 0) {
                Image(systemName: "calendar")
                    .font(.caption)
                
                Text(next.scheduledStart, style: .timer)
                    .font(.caption2)
            }
        } else {
            Image(systemName: "calendar.badge.plus")
                .font(.caption)
        }
    }
    
    private func formatShort(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h\(m)m" : "\(m)m"
    }
}

struct CircularComplicationView: View {
    let entry: ShiftComplicationEntry
    
    var body: some View {
        if let hours = entry.hoursData {
            Gauge(value: hours.progress) {
                Image(systemName: "clock.fill")
            } currentValueLabel: {
                Text("\(Int(hours.totalHours))")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .gaugeStyle(.accessoryCircular)
        } else if let shift = entry.currentShift, shift.isInProgress {
            Gauge(value: shiftProgress(shift)) {
                Image(systemName: "play.fill")
            } currentValueLabel: {
                if let remaining = shift.remainingMinutes {
                    Text("\(remaining)m")
                        .font(.caption2)
                }
            }
            .gaugeStyle(.accessoryCircular)
            .tint(.green)
        } else {
            Image(systemName: "calendar")
                .font(.title2)
        }
    }
    
    private func shiftProgress(_ shift: WatchShiftData) -> Double {
        guard let elapsed = shift.elapsedMinutes else { return 0 }
        let total = shift.durationMinutes
        guard total > 0 else { return 0 }
        return min(1.0, Double(elapsed) / Double(total))
    }
}

struct RectangularComplicationView: View {
    let entry: ShiftComplicationEntry
    
    var body: some View {
        if let shift = entry.currentShift, shift.isInProgress {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("On Shift")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    
                    Text(shift.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let remaining = shift.remainingMinutes {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(remaining / 60)h \(remaining % 60)m")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else if let next = entry.nextShift ?? entry.currentShift {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Shift")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(next.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(next.scheduledStart, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.accent)
            }
        } else {
            HStack {
                Image(systemName: "calendar")
                Text("No shifts scheduled")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct InlineComplicationView: View {
    let entry: ShiftComplicationEntry
    
    var body: some View {
        if let shift = entry.currentShift, shift.isInProgress {
            if let elapsed = shift.elapsedMinutes {
                Text("On shift: \(elapsed / 60)h \(elapsed % 60)m")
            } else {
                Text("On shift")
            }
        } else if let next = entry.nextShift ?? entry.currentShift {
            Text("Next: \(next.title)")
        } else if let hours = entry.hoursData {
            Text("\(String(format: "%.1f", hours.totalHours))h this period")
        } else {
            Text("ShiftPro")
        }
    }
}
