import SwiftUI

/// A compact, pill-shaped shift preview for inline display in calendar cells.
/// Shows abbreviated time range with status-colored accent bar.
struct ShiftPreviewPill: View {
    let shift: Shift

    /// Hides pattern name for minimal display
    var compact: Bool = false

    /// Uses 24-hour format (e.g., "07-15") instead of 12-hour (e.g., "7a-3p")
    var use24Hour: Bool = false

    // MARK: - Shift Color

    /// Returns the pattern's custom color if available, otherwise falls back to status color
    private var shiftColor: Color {
        // Use pattern's custom color if available
        if let pattern = shift.pattern, !pattern.colorHex.isEmpty {
            return Color(hex: pattern.colorHex) ?? statusColor
        }
        return statusColor
    }

    private var statusColor: Color {
        switch shift.status {
        case .scheduled:
            return ShiftProColors.accent
        case .inProgress:
            return ShiftProColors.success
        case .completed:
            return ShiftProColors.inkSubtle
        case .cancelled:
            return ShiftProColors.danger
        }
    }

    // MARK: - Time Formatting

    private var abbreviatedTimeRange: String {
        if use24Hour {
            return formatTime24Hour(shift.effectiveStart) + "-" + formatTime24Hour(shift.effectiveEnd)
        } else {
            return formatTime12Hour(shift.effectiveStart) + "-" + formatTime12Hour(shift.effectiveEnd)
        }
    }

    private func formatTime12Hour(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let suffix = hour < 12 ? "a" : "p"

        if minute == 0 {
            return "\(hour12)\(suffix)"
        } else {
            return String(format: "%d:%02d%@", hour12, minute, suffix)
        }
    }

    private func formatTime24Hour(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        if minute == 0 {
            return String(format: "%02d", hour)
        } else {
            return String(format: "%02d:%02d", hour, minute)
        }
    }

    // MARK: - Pattern Name

    private var patternName: String? {
        guard !compact else { return nil }
        return shift.displayTitle
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var description = shift.status.displayName + " shift"
        description += ", " + shift.timeRangeFormatted
        if !shift.displayTitle.isEmpty {
            let name = shift.displayTitle
            description += ", " + name
        }
        return description
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: ShiftProSpacing.extraExtraSmall) {
            // Left accent bar with pattern color
            RoundedRectangle(cornerRadius: 1.5)
                .fill(shiftColor)
                .frame(width: 3)

            // Time range (abbreviated)
            Text(abbreviatedTimeRange)
                .font(ShiftProTypography.footnote)
                .foregroundStyle(ShiftProColors.ink)
                .lineLimit(1)

            // Pattern name (optional)
            if let name = patternName {
                Text(name)
                    .font(ShiftProTypography.footnote)
                    .foregroundStyle(ShiftProColors.inkSubtle)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.leading, ShiftProSpacing.extraExtraSmall)
        .padding(.trailing, ShiftProSpacing.extraSmall)
        .padding(.vertical, ShiftProSpacing.extraExtraSmall)
        .frame(height: 20)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(shiftColor.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Preview

#Preview("All States") {
    let calendar = Calendar.current
    let now = Date()
    let startTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
    let endTime = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now) ?? now

    return VStack(spacing: ShiftProSpacing.medium) {
        Group {
            // Scheduled shift
            ShiftPreviewPill(
                shift: Shift(
                    scheduledStart: startTime,
                    scheduledEnd: endTime,
                    status: .scheduled
                )
            )

            // In progress shift
            ShiftPreviewPill(
                shift: Shift(
                    scheduledStart: startTime,
                    scheduledEnd: endTime,
                    status: .inProgress
                )
            )

            // Completed shift
            ShiftPreviewPill(
                shift: Shift(
                    scheduledStart: startTime,
                    scheduledEnd: endTime,
                    status: .completed
                )
            )

            // Cancelled shift
            ShiftPreviewPill(
                shift: Shift(
                    scheduledStart: startTime,
                    scheduledEnd: endTime,
                    status: .cancelled
                )
            )
        }

        Divider()

        // Compact mode
        Text("Compact Mode:")
            .font(ShiftProTypography.caption)
            .foregroundStyle(ShiftProColors.inkSubtle)

        ShiftPreviewPill(
            shift: Shift(
                scheduledStart: startTime,
                scheduledEnd: endTime,
                status: .scheduled
            ),
            compact: true
        )

        // 24-hour format
        Text("24-Hour Format:")
            .font(ShiftProTypography.caption)
            .foregroundStyle(ShiftProColors.inkSubtle)

        ShiftPreviewPill(
            shift: Shift(
                scheduledStart: startTime,
                scheduledEnd: endTime,
                status: .inProgress
            ),
            use24Hour: true
        )

        // Night shift (crossing midnight)
        Text("Night Shift:")
            .font(ShiftProTypography.caption)
            .foregroundStyle(ShiftProColors.inkSubtle)

        let nightStart = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
        let nightEnd = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: now)!) ?? now

        ShiftPreviewPill(
            shift: Shift(
                scheduledStart: nightStart,
                scheduledEnd: nightEnd,
                status: .scheduled
            )
        )
    }
    .padding()
    .background(ShiftProColors.background)
}

#Preview("In Calendar Cell") {
    let calendar = Calendar.current
    let now = Date()
    let startTime = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: now) ?? now
    let endTime = calendar.date(bySettingHour: 17, minute: 30, second: 0, of: now) ?? now

    // Simulating a calendar day cell
    return VStack(spacing: ShiftProSpacing.extraSmall) {
        Text("Mon")
            .font(ShiftProTypography.caption)
            .foregroundStyle(ShiftProColors.inkSubtle)

        Text("12")
            .font(ShiftProTypography.headline)
            .foregroundStyle(ShiftProColors.ink)

        ShiftPreviewPill(
            shift: Shift(
                scheduledStart: startTime,
                scheduledEnd: endTime,
                status: .scheduled
            ),
            compact: true
        )
    }
    .frame(width: 50, height: 80)
    .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(ShiftProColors.surface)
    )
    .padding()
    .background(ShiftProColors.background)
}
