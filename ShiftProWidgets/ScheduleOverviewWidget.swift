import SwiftUI
import WidgetKit

/// Widget showing an overview of upcoming shifts in a schedule format.
struct ScheduleOverviewWidget: Widget {
    static let kind = "ScheduleOverviewWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: SimpleShiftTimelineProvider()
        ) { entry in
            ScheduleOverviewWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Schedule Overview")
        .description("Shows your upcoming shifts at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct ScheduleOverviewWidgetView: View {
    let entry: ShiftWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        let allShifts = allUpcomingShifts
        
        if allShifts.isEmpty {
            noShiftsView
        } else {
            switch family {
            case .systemMedium:
                mediumView(shifts: Array(allShifts.prefix(3)))
            case .systemLarge:
                largeView(shifts: Array(allShifts.prefix(6)))
            default:
                mediumView(shifts: Array(allShifts.prefix(3)))
            }
        }
    }
    
    private var allUpcomingShifts: [WidgetShiftData] {
        var shifts: [WidgetShiftData] = []
        
        // Add current shift if it exists and is scheduled or in progress
        if let current = entry.data.currentShift,
           current.status == .scheduled || current.status == .inProgress {
            shifts.append(current)
        }
        
        // Add upcoming shifts
        shifts.append(contentsOf: entry.data.upcomingShifts)
        
        return shifts
    }
    
    // MARK: - Medium Widget
    
    private func mediumView(shifts: [WidgetShiftData]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .font(.headline)
                    .foregroundStyle(WidgetColors.accent)
                
                Text("Upcoming Shifts")
                    .font(.headline)
                    .foregroundStyle(WidgetColors.ink)
                
                Spacer()
                
                Text("\(allUpcomingShifts.count) total")
                    .font(.caption)
                    .foregroundStyle(WidgetColors.inkSubtle)
            }
            
            Divider()
            
            ForEach(shifts) { shift in
                shiftRow(shift)
                
                if shift.id != shifts.last?.id {
                    Divider()
                        .opacity(0.5)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding()
    }
    
    // MARK: - Large Widget
    
    private func largeView(shifts: [WidgetShiftData]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Schedule")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(WidgetColors.ink)
                    
                    Text("\(allUpcomingShifts.count) upcoming shifts")
                        .font(.caption)
                        .foregroundStyle(WidgetColors.inkSubtle)
                }
                
                Spacer()
                
                if let hours = entry.data.hoursData {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(hours.hoursFormatted + "h")
                            .font(.headline)
                            .foregroundStyle(WidgetColors.accent)
                        Text("this period")
                            .font(.caption2)
                            .foregroundStyle(WidgetColors.inkSubtle)
                    }
                }
            }
            
            Divider()
            
            ForEach(shifts) { shift in
                detailedShiftRow(shift)
                
                if shift.id != shifts.last?.id {
                    Divider()
                        .opacity(0.5)
                }
            }
            
            Spacer(minLength: 0)
            
            if allUpcomingShifts.count > shifts.count {
                HStack {
                    Spacer()
                    Text("+ \(allUpcomingShifts.count - shifts.count) more")
                        .font(.caption)
                        .foregroundStyle(WidgetColors.inkSubtle)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Shift Rows
    
    private func shiftRow(_ shift: WidgetShiftData) -> some View {
        HStack(spacing: 12) {
            // Date column
            VStack(spacing: 0) {
                Text(dayOfWeek(shift.scheduledStart))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(isToday(shift.scheduledStart) ? WidgetColors.accent : WidgetColors.inkSubtle)
                
                Text(dayNumber(shift.scheduledStart))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(isToday(shift.scheduledStart) ? WidgetColors.accent : WidgetColors.ink)
            }
            .frame(width: 36)
            
            // Shift info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(shift.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                    
                    if shift.status == .inProgress {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(WidgetColors.success)
                    }
                }
                
                Text(shift.timeRangeFormatted)
                    .font(.caption)
                    .foregroundStyle(WidgetColors.inkSubtle)
            }
            
            Spacer()
            
            // Duration and rate
            VStack(alignment: .trailing, spacing: 2) {
                Text(shift.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(WidgetColors.ink)
                
                if shift.rateMultiplier > 1.0 {
                    Text(shift.rateLabel ?? String(format: "%.1fx", shift.rateMultiplier))
                        .font(.caption2)
                        .foregroundStyle(WidgetColors.rateColor(multiplier: shift.rateMultiplier))
                }
            }
        }
    }
    
    private func detailedShiftRow(_ shift: WidgetShiftData) -> some View {
        HStack(spacing: 12) {
            // Date block
            VStack(spacing: 2) {
                Text(dayOfWeek(shift.scheduledStart))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(isToday(shift.scheduledStart) ? WidgetColors.accent : WidgetColors.inkSubtle)
                
                Text(dayNumber(shift.scheduledStart))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(isToday(shift.scheduledStart) ? WidgetColors.accent : WidgetColors.ink)
                
                Text(monthAbbrev(shift.scheduledStart))
                    .font(.caption2)
                    .foregroundStyle(WidgetColors.inkSubtle)
            }
            .frame(width: 44)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isToday(shift.scheduledStart) ? WidgetColors.accent.opacity(0.1) : Color.clear)
            )
            
            // Shift details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(shift.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                    
                    if shift.status == .inProgress {
                        ShiftStatusBadge(status: .inProgress)
                    }
                    
                    Spacer()
                    
                    if shift.rateMultiplier > 1.0 {
                        WidgetRateBadge(multiplier: shift.rateMultiplier, label: shift.rateLabel)
                    }
                }
                
                HStack(spacing: 12) {
                    WidgetTimeDisplay(start: shift.scheduledStart, end: shift.scheduledEnd)
                    
                    Text(shift.durationFormatted)
                        .font(.caption)
                        .foregroundStyle(WidgetColors.inkSubtle)
                }
                
                if let location = shift.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(WidgetColors.inkSubtle)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - No Shifts View
    
    private var noShiftsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(WidgetColors.inkSubtle.opacity(0.5))
            
            Text("No upcoming shifts")
                .font(.headline)
                .foregroundStyle(WidgetColors.inkSubtle)
            
            Text("Open ShiftPro to add shifts to your schedule")
                .font(.caption)
                .foregroundStyle(WidgetColors.inkSubtle.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Date Helpers
    
    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func monthAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

#Preview(as: .systemMedium) {
    ScheduleOverviewWidget()
} timeline: {
    ShiftWidgetEntry.preview()
}

#Preview(as: .systemLarge) {
    ScheduleOverviewWidget()
} timeline: {
    ShiftWidgetEntry.preview()
}
