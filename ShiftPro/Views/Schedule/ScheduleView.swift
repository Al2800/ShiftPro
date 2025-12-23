import SwiftUI

struct ScheduleView: View {
    private let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.l) {
                calendarStrip

                VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
                    Text("This Week")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    ShiftCardView(
                        title: "Training",
                        timeRange: "9:00 AM - 1:00 PM",
                        location: "Academy",
                        status: .scheduled,
                        rateMultiplier: 1.0,
                        notes: "Quarterly readiness training."
                    )

                    ShiftCardView(
                        title: "Day Patrol",
                        timeRange: "7:00 AM - 7:00 PM",
                        location: "Central Precinct",
                        status: .scheduled,
                        rateMultiplier: 1.3,
                        notes: "Partner with Officer Diaz."
                    )
                }
            }
            .padding(.horizontal, ShiftProSpacing.m)
            .padding(.vertical, ShiftProSpacing.l)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Schedule")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ShiftProColors.accent)
                }
                .accessibilityLabel("Add shift")
            }
        }
    }

    private var calendarStrip: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.s) {
            Text("December")
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.inkSubtle)

            HStack(spacing: ShiftProSpacing.s) {
                ForEach(weekDays, id: \.self) { day in
                    VStack(spacing: ShiftProSpacing.xxs) {
                        Text(day)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                        Text("12")
                            .font(ShiftProTypography.subheadline)
                            .foregroundStyle(ShiftProColors.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ShiftProSpacing.xs)
                    .background(ShiftProColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScheduleView()
    }
}
