import SwiftUI

struct HoursDisplay: View {
    let totalHours: Double
    let regularHours: Double
    let overtimeHours: Double

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            AnimatedCounter(
                title: "Total Hours",
                value: totalHours,
                titleFont: ShiftProTypography.caption,
                titleColor: ShiftProColor.textSecondary,
                valueFont: ShiftProTypography.title,
                valueColor: ShiftProColor.textPrimary
            )

            HStack(spacing: ShiftProSpacing.medium) {
                AnimatedCounter(
                    title: "Regular",
                    value: regularHours,
                    titleFont: ShiftProTypography.caption,
                    titleColor: ShiftProColor.textSecondary,
                    valueFont: ShiftProTypography.subheadline,
                    valueColor: ShiftProColor.textPrimary
                )

                AnimatedCounter(
                    title: "Overtime",
                    value: overtimeHours,
                    titleFont: ShiftProTypography.caption,
                    titleColor: ShiftProColor.textSecondary,
                    valueFont: ShiftProTypography.subheadline,
                    valueColor: ShiftProColor.textPrimary
                )
            }
        }
        .padding(ShiftProSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ShiftProColor.surface)
                .shadow(color: ShiftProColor.accentSoft.opacity(0.3), radius: 10, x: 0, y: 6)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total hours \(totalHours)")
    }
}

#Preview {
    HoursDisplay(totalHours: 86.5, regularHours: 72.0, overtimeHours: 14.5)
        .padding()
        .background(ShiftProColor.background)
}
