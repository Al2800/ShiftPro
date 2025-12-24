import SwiftUI
import WidgetKit
import AppIntents

/// Widget showing the currently active shift with elapsed time and remaining time.
struct CurrentShiftWidget: Widget {
    static let kind = "CurrentShiftWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: ConfigurationAppIntent.self,
            provider: ShiftTimelineProvider()
        ) { entry in
            CurrentShiftWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Current Shift")
        .description("Shows your active shift with elapsed and remaining time.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CurrentShiftWidgetView: View {
    let entry: ShiftWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if let shift = entry.data.currentShift, shift.status == .inProgress {
            switch family {
            case .systemSmall:
                smallView(shift: shift)
            case .systemMedium:
                mediumView(shift: shift)
            default:
                smallView(shift: shift)
            }
        } else {
            noActiveShiftView
        }
    }
    
    // MARK: - Small Widget
    
    private func smallView(shift: WidgetShiftData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(WidgetColors.success)
                
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
            
            if let elapsed = shift.elapsedMinutes {
                HStack(spacing: 4) {
                    Text(formatDuration(minutes: elapsed))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(WidgetColors.ink)
                    
                    Text("elapsed")
                        .font(.caption2)
                        .foregroundStyle(WidgetColors.inkSubtle)
                }
            }
            
            WidgetTimeDisplay(start: shift.effectiveStart, end: shift.effectiveEnd)
        }
        .padding()
    }
    
    // MARK: - Medium Widget
    
    private func mediumView(shift: WidgetShiftData) -> some View {
        HStack(spacing: 16) {
            // Left: Progress ring
            VStack {
                ZStack {
                    ProgressRing(
                        progress: shiftProgress(shift),
                        lineWidth: 8,
                        foregroundColor: WidgetColors.success
                    )
                    .frame(width: 70, height: 70)
                    
                    VStack(spacing: 0) {
                        if let remaining = shift.remainingMinutes {
                            Text(formatDuration(minutes: remaining))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(WidgetColors.ink)
                            Text("left")
                                .font(.caption2)
                                .foregroundStyle(WidgetColors.inkSubtle)
                        }
                    }
                }
            }
            
            // Right: Shift details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ShiftStatusBadge(status: .inProgress)
                    Spacer()
                    if shift.rateMultiplier > 1.0 {
                        WidgetRateBadge(multiplier: shift.rateMultiplier, label: shift.rateLabel)
                    }
                }
                
                Text(shift.title)
                    .font(.headline)
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
                
                WidgetTimeDisplay(start: shift.effectiveStart, end: shift.effectiveEnd)
                
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
    
    // MARK: - No Active Shift
    
    private var noActiveShiftView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.largeTitle)
                .foregroundStyle(WidgetColors.inkSubtle.opacity(0.5))
            
            Text("No active shift")
                .font(.subheadline)
                .foregroundStyle(WidgetColors.inkSubtle)
            
            if let nextShift = entry.data.upcomingShifts.first {
                VStack(spacing: 2) {
                    Text("Next: \(nextShift.title)")
                        .font(.caption)
                        .foregroundStyle(WidgetColors.ink)
                    
                    if let countdown = nextShift.countdownFormatted {
                        Text(countdown)
                            .font(.caption2)
                            .foregroundStyle(WidgetColors.accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helpers
    
    private func shiftProgress(_ shift: WidgetShiftData) -> Double {
        guard let elapsed = shift.elapsedMinutes else { return 0 }
        let total = shift.durationMinutes
        guard total > 0 else { return 0 }
        return Double(elapsed) / Double(total)
    }
    
    private func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

#Preview(as: .systemSmall) {
    CurrentShiftWidget()
} timeline: {
    ShiftWidgetEntry.preview()
}

#Preview(as: .systemMedium) {
    CurrentShiftWidget()
} timeline: {
    ShiftWidgetEntry.preview()
}
