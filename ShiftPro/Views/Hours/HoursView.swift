import SwiftUI

struct HoursView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.l) {
                HoursDisplay(totalHours: 84.5, regularHours: 72.0, overtimeHours: 12.5)

                VStack(alignment: .leading, spacing: ShiftProSpacing.s) {
                    Text("Rate Summary")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    rateRow(label: "Standard", hours: 58.0, multiplier: 1.0)
                    rateRow(label: "Night Shift", hours: 14.0, multiplier: 1.3)
                    rateRow(label: "Overtime", hours: 10.5, multiplier: 1.5)
                    rateRow(label: "Holiday", hours: 2.0, multiplier: 2.0)
                }
                .padding(ShiftProSpacing.m)
                .background(ShiftProColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(ShiftProColors.accentMuted, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: ShiftProSpacing.s) {
                    Text("Insights")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    Text("You are on track to exceed your target hours by 6.5 this cycle.")
                        .font(ShiftProTypography.body)
                        .foregroundStyle(ShiftProColors.ink)
                }
                .padding(ShiftProSpacing.m)
                .background(ShiftProColors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, ShiftProSpacing.m)
            .padding(.vertical, ShiftProSpacing.l)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Hours")
    }

    private func rateRow(label: String, hours: Double, multiplier: Double) -> some View {
        HStack {
            Text(label)
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.ink)

            Spacer()

            Text(String(format: "%.1f", hours))
                .font(ShiftProTypography.mono)
                .foregroundStyle(ShiftProColors.inkSubtle)

            RateBadge(multiplier: multiplier)
        }
        .padding(.vertical, ShiftProSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(String(format: "%.1f hours at %.1fx", hours, multiplier))
    }
}

#Preview {
    NavigationStack {
        HoursView()
    }
}
