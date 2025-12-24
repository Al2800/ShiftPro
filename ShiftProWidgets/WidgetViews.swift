import SwiftUI
import WidgetKit

// MARK: - Widget Colors (Widget-safe alternatives to ShiftProColors)

enum WidgetColors {
    static let background = Color("WidgetBackground", bundle: nil)
    static let surface = Color("WidgetSurface", bundle: nil)
    static let ink = Color.primary
    static let inkSubtle = Color.secondary
    static let accent = Color.accentColor
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    
    static func rateColor(multiplier: Double) -> Color {
        switch multiplier {
        case 2.0: return danger
        case 1.5: return warning
        case 1.3: return accent
        default: return success
        }
    }
}

// MARK: - Shift Status Badge

struct ShiftStatusBadge: View {
    let status: WidgetShiftStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundStyle(statusColor)
        .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .scheduled: return WidgetColors.accent
        case .inProgress: return WidgetColors.success
        case .completed: return WidgetColors.inkSubtle
        case .cancelled: return WidgetColors.danger
        }
    }
}

// MARK: - Rate Badge

struct WidgetRateBadge: View {
    let multiplier: Double
    let label: String?
    
    var body: some View {
        if multiplier > 1.0 {
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                Text(label ?? String(format: "%.1fx", multiplier))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(WidgetColors.rateColor(multiplier: multiplier).opacity(0.2))
            .foregroundStyle(WidgetColors.rateColor(multiplier: multiplier))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Time Display

struct WidgetTimeDisplay: View {
    let start: Date
    let end: Date
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption)
            Text(timeRange)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(WidgetColors.inkSubtle)
    }
    
    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let foregroundColor: Color
    let backgroundColor: Color
    
    init(
        progress: Double,
        lineWidth: CGFloat = 6,
        foregroundColor: Color = WidgetColors.accent,
        backgroundColor: Color = WidgetColors.inkSubtle.opacity(0.2)
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(foregroundColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
        }
    }
}

// MARK: - Hours Progress Bar

struct HoursProgressBar: View {
    let progress: Double
    let height: CGFloat
    
    init(progress: Double, height: CGFloat = 8) {
        self.progress = progress
        self.height = height
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(WidgetColors.inkSubtle.opacity(0.2))
                
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(progressColor)
                    .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)))
            }
        }
        .frame(height: height)
    }
    
    private var progressColor: Color {
        if progress >= 1.0 {
            return WidgetColors.success
        } else if progress >= 0.9 {
            return WidgetColors.warning
        } else {
            return WidgetColors.accent
        }
    }
}

// MARK: - Countdown Display

struct CountdownDisplay: View {
    let targetDate: Date
    
    var body: some View {
        Text(targetDate, style: .relative)
            .font(.caption)
            .foregroundStyle(WidgetColors.accent)
    }
}

// MARK: - Empty State View

struct WidgetEmptyState: View {
    let title: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(WidgetColors.inkSubtle.opacity(0.5))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(WidgetColors.inkSubtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shift Card (Compact)

struct CompactShiftCard: View {
    let shift: WidgetShiftData
    let showRate: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(shift.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
                
                Spacer()
                
                if showRate {
                    WidgetRateBadge(multiplier: shift.rateMultiplier, label: shift.rateLabel)
                }
            }
            
            WidgetTimeDisplay(start: shift.effectiveStart, end: shift.effectiveEnd)
        }
    }
}

// MARK: - Shift Card (Full)

struct FullShiftCard: View {
    let shift: WidgetShiftData
    let showLocation: Bool
    let showRate: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(shift.title)
                    .font(.headline)
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
                
                Spacer()
                
                ShiftStatusBadge(status: shift.status)
            }
            
            HStack(spacing: 12) {
                WidgetTimeDisplay(start: shift.effectiveStart, end: shift.effectiveEnd)
                
                Text(shift.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(WidgetColors.inkSubtle)
            }
            
            if showLocation, let location = shift.location {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(location)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(WidgetColors.inkSubtle)
            }
            
            if showRate, shift.rateMultiplier > 1.0 {
                WidgetRateBadge(multiplier: shift.rateMultiplier, label: shift.rateLabel)
            }
        }
    }
}

// MARK: - Schedule Row

struct ScheduleRow: View {
    let shift: WidgetShiftData
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(shift.dateFormatted)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(WidgetColors.inkSubtle)
                
                Text(shift.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(shift.timeRangeFormatted)
                .font(.caption2)
                .foregroundStyle(WidgetColors.inkSubtle)
        }
        .padding(.vertical, 4)
    }
}
