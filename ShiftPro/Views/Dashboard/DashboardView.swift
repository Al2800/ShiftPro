import SwiftUI

struct DashboardView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.l) {
                heroCard

                VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
                    Text("Upcoming")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    ShiftCardView(
                        title: "Day Patrol",
                        timeRange: "7:00 AM - 7:00 PM",
                        location: "Central Precinct",
                        status: .scheduled,
                        rateMultiplier: 1.5,
                        notes: "Briefing at 6:30 AM. Body cam check before roll call."
                    )

                    ShiftCardView(
                        title: "Night Patrol",
                        timeRange: "7:00 PM - 7:00 AM",
                        location: "North District",
                        status: .inProgress,
                        rateMultiplier: 2.0,
                        notes: "Overtime shift due to staffing shortage."
                    )
                }

                VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
                    Text("Hours")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    HoursDisplay(totalHours: 84.5, regularHours: 72.0, overtimeHours: 12.5)
                }

                quickActions
            }
            .padding(.horizontal, ShiftProSpacing.m)
            .padding(.vertical, ShiftProSpacing.l)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(ShiftProColors.accent)
                }
                .accessibilityLabel("Notifications")
            }
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(ShiftProColors.heroGradient)
                .frame(maxWidth: .infinity)
                .frame(height: 180)

            VStack(alignment: .leading, spacing: ShiftProSpacing.s) {
                Text("Ready for roll call")
                    .font(ShiftProTypography.title)
                    .foregroundStyle(.white)

                Text("Next shift starts in 45 minutes")
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                QuickActionButton(title: "Start Shift", systemImage: "play.fill") {}
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(ShiftProSpacing.l)
        }
        .shadow(color: ShiftProColors.accent.opacity(0.25), radius: 18, x: 0, y: 12)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
            Text("Quick Actions")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            HStack(spacing: ShiftProSpacing.s) {
                QuickActionButton(title: "Log Break", systemImage: "cup.and.saucer.fill") {}
                QuickActionButton(title: "Add Shift", systemImage: "plus") {}
            }
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
