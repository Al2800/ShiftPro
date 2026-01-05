import SwiftUI

struct HoursDisplay: View {
    let totalHours: Double
    let regularHours: Double
    let overtimeHours: Double
    var trendDelta: Double?
    var estimatedPay: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack(alignment: .top) {
                AnimatedCounter(
                    title: "Total Hours",
                    value: totalHours,
                    titleFont: ShiftProTypography.caption,
                    titleColor: ShiftProColor.textSecondary,
                    valueFont: ShiftProTypography.title,
                    valueColor: ShiftProColor.textPrimary
                )

                Spacer()

                if let trend = trendDelta {
                    trendBadge(delta: trend)
                }
            }

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

            if let pay = estimatedPay {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(ShiftProColors.success)
                    Text("Est. \(formatCurrency(pay))")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
                .padding(.top, 4)
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

    // MARK: - Trend Badge

    @ViewBuilder
    private func trendBadge(delta: Double) -> some View {
        let isPositive = delta >= 0
        let icon = isPositive ? "arrow.up.right" : "arrow.down.right"
        let color = isPositive ? ShiftProColors.success : ShiftProColors.warning
        let formattedDelta = String(format: "%+.1fh", delta)

        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(formattedDelta)
                .font(ShiftProTypography.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .accessibilityLabel("\(isPositive ? "Up" : "Down") \(abs(delta)) hours vs last period")
    }

    // MARK: - Currency Formatting

    private func formatCurrency(_ amount: Double) -> String {
        CurrencyFormatter.format(amount) ?? "£\(String(format: "%.2f", amount))"
    }
}

#Preview {
    HoursDisplay(totalHours: 86.5, regularHours: 72.0, overtimeHours: 14.5)
        .padding()
        .background(ShiftProColor.background)
}
