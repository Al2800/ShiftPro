import SwiftUI

struct HoursDisplay: View {
    let totalHours: Double
    let regularHours: Double
    let overtimeHours: Double

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Total Hours")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColor.textSecondary)

            Text(String(format: "%.1f", totalHours))
                .font(ShiftProTypography.title)
                .foregroundStyle(ShiftProColor.textPrimary)

            HStack(spacing: ShiftProSpacing.medium) {
                VStack(alignment: .leading, spacing: ShiftProSpacing.xSmall) {
                    Text("Regular")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColor.textSecondary)
                    Text(String(format: "%.1f", regularHours))
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColor.textPrimary)
                }

                VStack(alignment: .leading, spacing: ShiftProSpacing.xSmall) {
                    Text("Overtime")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColor.textSecondary)
                    Text(String(format: "%.1f", overtimeHours))
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColor.textPrimary)
                }
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
