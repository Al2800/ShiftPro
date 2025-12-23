import SwiftUI
import SwiftData

/// Detailed view of a specific pay period with shift breakdown
struct PayPeriodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    let period: PayPeriod

    @State private var calculator = PayPeriodCalculator()
    @State private var predictor = OvertimePredictor()
    @State private var showShareSheet = false

    private var profile: UserProfile? {
        profiles.first
    }

    private var analysis: PayPeriodCalculator.PeriodAnalysis {
        calculator.analyze(
            period: period,
            targetHours: profile?.regularHoursPerPay ?? 80,
            baseRateCents: profile?.baseRateCents
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.l) {
                headerSection
                summarySection
                shiftsSection
                rateBreakdownSection

                if period.isCurrent {
                    projectionSection
                }
            }
            .padding(ShiftProSpacing.m)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle(period.dateRangeFormatted)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: ShiftProSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", analysis.totalHours))
                    .font(.system(size: 48, design: .rounded).weight(.bold))
                    .foregroundStyle(ShiftProColors.ink)

                Text("hours")
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            if let estimatedPay = period.estimatedPayFormatted {
                Text(estimatedPay)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(ShiftProColors.success)
            }

            statusBadge
        }
        .frame(maxWidth: .infinity)
        .padding(ShiftProSpacing.m)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
            Text(statusText)
                .font(ShiftProTypography.caption)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusIcon: String {
        if period.isPast { return "checkmark.circle.fill" }
        if period.isCurrent { return "clock.fill" }
        return "calendar"
    }

    private var statusText: String {
        if period.isPast { return "Completed" }
        if period.isCurrent { return "In Progress" }
        return "Upcoming"
    }

    private var statusColor: Color {
        if period.isPast { return ShiftProColors.success }
        if period.isCurrent { return ShiftProColors.accent }
        return ShiftProColors.inkSubtle
    }

    // MARK: - Summary Section

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
            Text("Summary")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ShiftProSpacing.s) {
                summaryCard(label: "Shifts", value: "\(period.shiftCount)", icon: "calendar.badge.clock")
                summaryCard(label: "Regular", value: String(format: "%.1fh", analysis.regularHours), icon: "clock")
                summaryCard(label: "Premium", value: String(format: "%.1fh", analysis.premiumHours), icon: "star")
                summaryCard(label: "Days", value: "\(period.durationDays)", icon: "calendar")
            }
        }
        .padding(ShiftProSpacing.m)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func summaryCard(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(ShiftProTypography.caption)
            }
            .foregroundStyle(ShiftProColors.inkSubtle)

            Text(value)
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ShiftProSpacing.s)
        .background(ShiftProColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Shifts Section

    @ViewBuilder
    private var shiftsSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
            HStack {
                Text("Shifts")
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(ShiftProColors.ink)

                Spacer()

                Text("\(period.completedShifts.count) completed")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            if period.activeShifts.isEmpty {
                emptyShiftsView
            } else {
                ForEach(period.activeShifts.sorted { $0.scheduledStart < $1.scheduledStart }) { shift in
                    shiftRow(shift)
                }
            }
        }
        .padding(ShiftProSpacing.m)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func shiftRow(_ shift: Shift) -> some View {
        HStack(alignment: .center, spacing: ShiftProSpacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(shift.dateFormatted)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)

                Text(shift.timeRangeFormatted)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            Spacer()

            if shift.isCompleted {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1fh", shift.paidHours))
                        .font(ShiftProTypography.mono)
                        .foregroundStyle(ShiftProColors.ink)

                    if shift.hasPremiumPay {
                        RateBadge(multiplier: shift.rateMultiplier)
                    }
                }
            } else {
                StatusIndicator(status: shift.status)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, ShiftProSpacing.s)
        .background(ShiftProColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyShiftsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(ShiftProColors.inkSubtle)

            Text("No shifts in this period")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(ShiftProSpacing.l)
    }

    // MARK: - Rate Breakdown Section

    @ViewBuilder
    private var rateBreakdownSection: some View {
        let breakdown = calculator.calculateRateBreakdown(
            for: period,
            baseRateCents: profile?.baseRateCents
        )

        if !breakdown.isEmpty {
            VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
                Text("Rate Breakdown")
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(ShiftProColors.ink)

                ForEach(breakdown) { rate in
                    HStack {
                        RateBadge(multiplier: rate.multiplier)

                        Text(rate.label)
                            .font(ShiftProTypography.body)
                            .foregroundStyle(ShiftProColors.ink)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "%.1f hrs", rate.hours))
                                .font(ShiftProTypography.mono)
                                .foregroundStyle(ShiftProColors.ink)

                            if let estimatedPay = rate.estimatedPayCents {
                                let dollars = Double(estimatedPay) / 100.0
                                Text(String(format: "$%.2f", dollars))
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, ShiftProSpacing.s)
                    .background(ShiftProColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(ShiftProSpacing.m)
            .background(ShiftProColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Projection Section

    @ViewBuilder
    private var projectionSection: some View {
        let prediction = predictor.predict(
            for: period,
            targetHours: profile?.regularHoursPerPay ?? 80
        )

        VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
            Text("Projection")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            VStack(spacing: ShiftProSpacing.s) {
                projectionRow(
                    label: "Current Hours",
                    value: String(format: "%.1fh", prediction.currentHours),
                    icon: "clock.fill"
                )

                projectionRow(
                    label: "Projected Total",
                    value: String(format: "%.1fh", prediction.projectedHours),
                    icon: "chart.line.uptrend.xyaxis"
                )

                projectionRow(
                    label: "Days Remaining",
                    value: "\(prediction.daysRemaining)",
                    icon: "calendar"
                )

                projectionRow(
                    label: "Avg. Hours/Day",
                    value: String(format: "%.1fh", prediction.averageHoursPerDay),
                    icon: "arrow.up.right"
                )
            }

            if prediction.warningLevel != .none {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ShiftProColors.warning)
                    Text(prediction.message)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
                .padding(ShiftProSpacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ShiftProColors.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(ShiftProSpacing.m)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func projectionRow(label: String, value: String, icon: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(ShiftProColors.accent)
                    .frame(width: 20)
                Text(label)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)
            }

            Spacer()

            Text(value)
                .font(ShiftProTypography.mono)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PayPeriod.self, Shift.self, UserProfile.self, configurations: config)

    let period = PayPeriod(
        startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
        endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
        paidMinutes: 4800,
        premiumMinutes: 600,
        estimatedPayCents: 120000
    )

    return NavigationStack {
        PayPeriodDetailView(period: period)
            .modelContainer(container)
    }
}
