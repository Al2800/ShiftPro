import SwiftUI
import WidgetKit

/// Widget showing pay period hours progress and summary.
struct HoursSummaryWidget: Widget {
    static let kind = "HoursSummaryWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: SimpleShiftTimelineProvider()
        ) { entry in
            HoursSummaryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hours Summary")
        .description("Shows your pay period hours progress and earnings.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HoursSummaryWidgetView: View {
    let entry: ShiftWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if let hours = entry.data.hoursData {
            switch family {
            case .systemSmall:
                smallView(hours: hours)
            case .systemMedium:
                mediumView(hours: hours)
            default:
                smallView(hours: hours)
            }
        } else {
            noDataView
        }
    }
    
    // MARK: - Small Widget
    
    private func smallView(hours: WidgetHoursData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(WidgetColors.accent)
                
                Spacer()
            }
            
            Spacer()
            
            ZStack {
                ProgressRing(
                    progress: hours.progress,
                    lineWidth: 10,
                    foregroundColor: progressColor(hours.progress)
                )
                .frame(width: 60, height: 60)
                
                VStack(spacing: 0) {
                    Text(hours.hoursFormatted)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(WidgetColors.ink)
                    Text("hrs")
                        .font(.caption2)
                        .foregroundStyle(WidgetColors.inkSubtle)
                }
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hours.periodFormatted)
                    .font(.caption2)
                    .foregroundStyle(WidgetColors.inkSubtle)
                
                Text("\(Int(hours.progress * 100))% of target")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(progressColor(hours.progress))
            }
        }
        .padding()
    }
    
    // MARK: - Medium Widget
    
    private func mediumView(hours: WidgetHoursData) -> some View {
        HStack(spacing: 20) {
            // Left: Progress ring with hours
            VStack(spacing: 4) {
                ZStack {
                    ProgressRing(
                        progress: hours.progress,
                        lineWidth: 10,
                        foregroundColor: progressColor(hours.progress)
                    )
                    .frame(width: 80, height: 80)
                    
                    VStack(spacing: 0) {
                        Text(hours.hoursFormatted)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(WidgetColors.ink)
                        Text("/ \(Int(hours.targetHours))")
                            .font(.caption)
                            .foregroundStyle(WidgetColors.inkSubtle)
                    }
                }
                
                Text(hours.periodFormatted)
                    .font(.caption2)
                    .foregroundStyle(WidgetColors.inkSubtle)
            }
            
            // Right: Breakdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Hours Breakdown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(WidgetColors.ink)
                
                HStack {
                    Label {
                        Text("Regular")
                            .font(.caption)
                    } icon: {
                        Circle()
                            .fill(WidgetColors.accent)
                            .frame(width: 8, height: 8)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.1fh", hours.regularHours))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(WidgetColors.ink)
                }
                
                HStack {
                    Label {
                        Text("Premium")
                            .font(.caption)
                    } icon: {
                        Circle()
                            .fill(WidgetColors.warning)
                            .frame(width: 8, height: 8)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.1fh", hours.premiumHours))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(WidgetColors.ink)
                }
                
                if let pay = hours.estimatedPayFormatted {
                    Divider()
                    
                    HStack {
                        Text("Est. Pay")
                            .font(.caption)
                            .foregroundStyle(WidgetColors.inkSubtle)
                        
                        Spacer()
                        
                        Text(pay)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(WidgetColors.success)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    
    // MARK: - No Data View
    
    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundStyle(WidgetColors.inkSubtle.opacity(0.5))
            
            Text("No hours data")
                .font(.subheadline)
                .foregroundStyle(WidgetColors.inkSubtle)
            
            Text("Complete shifts to see progress")
                .font(.caption)
                .foregroundStyle(WidgetColors.inkSubtle.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helpers
    
    private func progressColor(_ progress: Double) -> Color {
        if progress >= 1.0 {
            return WidgetColors.success
        } else if progress >= 0.9 {
            return WidgetColors.warning
        } else {
            return WidgetColors.accent
        }
    }
}

#Preview(as: .systemSmall) {
    HoursSummaryWidget()
} timeline: {
    ShiftWidgetEntry.preview()
}

#Preview(as: .systemMedium) {
    HoursSummaryWidget()
} timeline: {
    ShiftWidgetEntry.preview()
}
