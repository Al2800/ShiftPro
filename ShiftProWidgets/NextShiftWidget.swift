import SwiftUI
import WidgetKit
import AppIntents

/// Widget showing the next upcoming shift with countdown.
struct NextShiftWidget: Widget {
    static let kind = "NextShiftWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: ConfigurationAppIntent.self,
            provider: ShiftTimelineProvider()
        ) { entry in
            NextShiftWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Shift")
        .description("Shows your upcoming shift with countdown timer.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NextShiftWidgetView: View {
    let entry: ShiftWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if let shift = nextUpcomingShift {
            switch family {
            case .systemSmall:
                smallView(shift: shift)
            case .systemMedium:
                mediumView(shift: shift)
            default:
                smallView(shift: shift)
            }
        } else {
            noUpcomingShiftView
        }
    }
    
    private var nextUpcomingShift: WidgetShiftData? {
        // If there's a current shift in progress, get the next one
        if let current = entry.data.currentShift, current.status == .inProgress {
            return entry.data.upcomingShifts.first
        }
        // Otherwise return the first upcoming shift or current if scheduled
        return entry.data.upcomingShifts.first ?? entry.data.currentShift
    }
    
    // MARK: - Small Widget
    
    private func smallView(shift: WidgetShiftData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(WidgetColors.accent)
                
                Spacer()
                
                if shift.rateMultiplier > 1.0 {
                    WidgetRateBadge(multiplier: shift.rateMultiplier, label: shift.rateLabel)
                }
            }
            
            Spacer()
            
            Text(shift.title)
                .font(.headline)
                .foregroundStyle(WidgetColors.ink)
                .lineLimit(1)
            
            Text(shift.dateFormatted)
                .font(.caption)
                .foregroundStyle(WidgetColors.inkSubtle)
            
            HStack(spacing: 4) {
                if shift.isFuture {
                    Text(shift.scheduledStart, style: .relative)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(WidgetColors.accent)
                } else {
                    Text("Now")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(WidgetColors.success)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Medium Widget
    
    private func mediumView(shift: WidgetShiftData) -> some View {
        HStack(spacing: 16) {
            // Left: Countdown
            VStack(spacing: 4) {
                if shift.isFuture {
                    Text(shift.scheduledStart, style: .relative)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(WidgetColors.accent)
                        .multilineTextAlignment(.center)
                    
                    Text("until shift")
                        .font(.caption2)
                        .foregroundStyle(WidgetColors.inkSubtle)
                } else {
                    Image(systemName: "bell.badge.fill")
                        .font(.title)
                        .foregroundStyle(WidgetColors.success)
                    
                    Text("Starting now!")
                        .font(.caption)
                        .foregroundStyle(WidgetColors.success)
                }
            }
            .frame(width: 80)
            
            Divider()
            
            // Right: Shift details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(shift.title)
                        .font(.headline)
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if shift.rateMultiplier > 1.0 {
                        WidgetRateBadge(multiplier: shift.rateMultiplier, label: shift.rateLabel)
                    }
                }
                
                Text(shift.dateFormatted)
                    .font(.subheadline)
                    .foregroundStyle(WidgetColors.inkSubtle)
                
                WidgetTimeDisplay(start: shift.scheduledStart, end: shift.scheduledEnd)
                
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text(shift.durationFormatted)
                        .font(.caption)
                }
                .foregroundStyle(WidgetColors.inkSubtle)
                
                if let location = shift.location, entry.configuration?.showLocation != false {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    
    // MARK: - No Upcoming Shift
    
    private var noUpcomingShiftView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(WidgetColors.inkSubtle.opacity(0.5))
            
            Text("No upcoming shifts")
                .font(.subheadline)
                .foregroundStyle(WidgetColors.inkSubtle)
            
            Text("Open ShiftPro to add shifts")
                .font(.caption)
                .foregroundStyle(WidgetColors.inkSubtle.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview(as: .systemSmall) {
    NextShiftWidget()
} timeline: {
    ShiftWidgetEntry.preview()
}

#Preview(as: .systemMedium) {
    NextShiftWidget()
} timeline: {
    ShiftWidgetEntry.preview()
}
