import SwiftUI
import SwiftData

struct HoursDashboard: View {
    @Query(filter: #Predicate<Shift> { $0.deletedAt == nil }, sort: [SortDescriptor(\Shift.scheduledStart, order: .forward)])
    private var shifts: [Shift]

    @Query(filter: #Predicate<PayPeriod> { $0.deletedAt == nil }, sort: [SortDescriptor(\PayPeriod.startDate, order: .reverse)])
    private var payPeriods: [PayPeriod]

    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    @State private var rateChartStyle: RateBreakdownChart.ChartStyle = .pie
    @State private var showingAddShift = false
    @State private var showingImport = false

    private let calculator = PayPeriodCalculator()
    private let overtimePredictor = OvertimePredictor()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                if shifts.isEmpty {
                    emptyState
                    dataActionsCard
                } else {
                    // Primary card - dominant visual hierarchy
                    heroCard

                    // Secondary section - insights and details
                    VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                        Text("Details")
                            .font(ShiftProTypography.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                            .textCase(.uppercase)
                            .padding(.top, ShiftProSpacing.small)

                        NavigationLink {
                            PayPeriodDetailView(
                                period: currentPeriod,
                                shifts: periodShifts,
                                baseRateCents: profile?.baseRateCents
                            )
                        } label: {
                            summaryCard
                        }
                        .buttonStyle(.plain)

                        chartCard

                        rateBreakdownCard

                        overtimeCard
                    }

                    // Tertiary section - history and actions
                    VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                        Text("History")
                            .font(ShiftProTypography.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                            .textCase(.uppercase)
                            .padding(.top, ShiftProSpacing.small)

                        recentPeriodsCard

                        dataActionsCard
                    }
                }
            }
            .padding(.horizontal, ShiftProSpacing.medium)
            .padding(.vertical, ShiftProSpacing.large)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Hours")
        .toolbar {
            NavigationLink("Rates") {
                RateMultiplierView()
            }
        }
        .sheet(isPresented: $showingAddShift) {
            ShiftFormView()
        }
        .sheet(isPresented: $showingImport) {
            ImportView()
        }
    }

    private var profile: UserProfile? {
        profiles.first
    }

    private var storedCurrentPeriod: PayPeriod? {
        payPeriods.first(where: { $0.isCurrent })
    }

    private var currentPeriod: PayPeriod {
        if let stored = storedCurrentPeriod { return stored }
        return calculator.period(for: Date(), type: profile?.payPeriodType ?? .biweekly, referenceDate: profile?.startDate)
    }

    private var periodShifts: [Shift] {
        calculator.shifts(in: currentPeriod, from: shifts)
    }

    private var summary: HoursCalculator.PeriodSummary {
        calculator.summary(for: periodShifts, baseRateCents: profile?.baseRateCents)
    }

    private var rateData: [RateBreakdownChart.RateData] {
        let buckets = calculator.rateBreakdown(for: periodShifts)
        return buckets.map { RateBreakdownChart.RateData(label: $0.label, hours: $0.hours, multiplier: $0.multiplier) }
    }

    private var dailyTotals: [(date: Date, hours: Double)] {
        calculator.dailyTotals(for: periodShifts, within: currentPeriod).map { ($0.date, $0.hours) }
    }

    private var overtimeForecast: OvertimeForecast {
        let threshold = Double(profile?.regularHoursPerPay ?? 80)
        return overtimePredictor.forecast(for: periodShifts, within: currentPeriod, thresholdHours: threshold)
    }

    /// Next upcoming shift in the current pay period (not yet completed)
    private var nextUpcomingShift: Shift? {
        let now = Date()
        return periodShifts.first { shift in
            shift.scheduledStart > now && shift.status != .completed && shift.status != .cancelled
        }
    }

    /// Impact message for the next shift on overtime threshold
    private var nextShiftImpactMessage: String? {
        guard let nextShift = nextUpcomingShift else { return nil }

        let threshold = overtimeForecast.thresholdHours
        let currentHours = summary.totalHours
        let shiftHours = Double(max(0, nextShift.scheduledDurationMinutes - nextShift.breakMinutes)) / 60.0
        let afterNextShift = currentHours + shiftHours

        if afterNextShift > threshold {
            let excess = afterNextShift - threshold
            return String(format: "Next shift would exceed by %.1f hrs", excess)
        } else {
            return String(format: "After next shift: %.1f hrs", afterNextShift)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "clock.badge.questionmark",
            title: "No hours tracked yet",
            subtitle: "Add your first shift to see hours, pay, and overtime forecasts.",
            actionTitle: "Add Shift",
            action: { showingAddShift = true },
            secondaryActionTitle: "Import Shifts",
            secondaryAction: { showingImport = true }
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Current Pay Period")
                .font(ShiftProTypography.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))

            Text(currentPeriod.dateRangeFormatted)
                .font(ShiftProTypography.title)
                .foregroundStyle(.white)

            ProgressView(value: currentPeriod.progress)
                .tint(.white)

            HStack(spacing: ShiftProSpacing.medium) {
                heroMetricView(title: "Total", value: String(format: "%.1f", summary.totalHours))
                heroMetricView(title: "Regular", value: String(format: "%.1f", summary.regularHours))
                heroMetricView(title: "Premium", value: String(format: "%.1f", summary.premiumHours))
            }

            if let estimated = summary.estimatedPayCents {
                Text("Est. \(estimated.centsFormatted)")
                    .font(ShiftProTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.top, ShiftProSpacing.extraExtraSmall)
            }
        }
        .padding(ShiftProSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShiftProColors.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: ShiftProColors.accent.opacity(0.25), radius: 18, x: 0, y: 12)
        .accessibilityIdentifier("hours.heroCard")
    }

    private func heroMetricView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
            Text(title)
                .font(ShiftProTypography.caption)
                .foregroundStyle(.white.opacity(0.75))
            Text("\(value)h")
                .font(ShiftProTypography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack {
                Text("Pay Period Summary")
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(ShiftProColors.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            Text("Total paid minutes: \(summary.totalPaidMinutes.minutesToHoursFormatted)")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.inkSubtle)

            if let estimated = summary.estimatedPayCents {
                Text("Estimated pay: \(estimated.centsFormatted)")
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(ShiftProColors.ink)
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier("hours.summaryCard")
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Hours Trend")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            HoursChart(dataPoints: dailyTotals, targetHours: profile?.regularHoursPerPay)
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier("hours.chartCard")
    }

    private var rateBreakdownCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack {
                Text("Rate Breakdown")
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(ShiftProColors.ink)
                Spacer()
                Picker("Style", selection: $rateChartStyle) {
                    Text("Pie").tag(RateBreakdownChart.ChartStyle.pie)
                    Text("Bar").tag(RateBreakdownChart.ChartStyle.bar)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            if rateData.isEmpty {
                VStack(spacing: ShiftProSpacing.small) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 32))
                        .foregroundStyle(ShiftProColors.inkSubtle)
                    Text("No hours recorded")
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                RateBreakdownChart(rateData: rateData, style: rateChartStyle)
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var overtimeCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Overtime Forecast")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            HStack {
                VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                    Text("Projected")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                    Text(String(format: "%.1f hrs", overtimeForecast.projectedHours))
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColors.ink)
                }
                Spacer()
                VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                    Text("Threshold")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                    Text(String(format: "%.0f hrs", overtimeForecast.thresholdHours))
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColors.ink)
                }
            }

            Text(overtimeForecast.message)
                .font(ShiftProTypography.body)
                .foregroundStyle(color(for: overtimeForecast.status))

            if let impactMessage = nextShiftImpactMessage {
                Text(impactMessage)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
                    .padding(.top, ShiftProSpacing.extraExtraSmall)
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier("hours.overtimeCard")
    }

    private var recentPeriodsCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Recent Periods")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            if payPeriods.isEmpty {
                VStack(spacing: ShiftProSpacing.small) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32))
                        .foregroundStyle(ShiftProColors.inkSubtle)
                    Text("No pay periods yet")
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                    Text("Complete shifts to build your history")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ShiftProSpacing.medium)
            } else {
                ForEach(payPeriods.prefix(4), id: \.id) { period in
                    HStack {
                        VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                            Text(period.dateRangeFormatted)
                                .font(ShiftProTypography.body)
                                .foregroundStyle(ShiftProColors.ink)
                            Text("\(period.paidMinutes.minutesToHoursFormatted) • \(period.shiftCount) shifts")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                        Spacer()
                        if period.isComplete {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(ShiftProColors.success)
                        }
                    }
                    .padding(.vertical, ShiftProSpacing.extraExtraSmall)

                    if period.id != payPeriods.prefix(4).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var dataActionsCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("More")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            VStack(spacing: 0) {
                NavigationLink {
                    AnalyticsDashboard()
                } label: {
                    actionRow(
                        title: "Analytics",
                        subtitle: "Insights and trends",
                        systemImage: "chart.bar.xaxis"
                    )
                }

                Divider()

                NavigationLink {
                    ExportOptionsView(period: currentPeriod, shifts: periodShifts)
                } label: {
                    actionRow(
                        title: "Export",
                        subtitle: "Share reports and summaries",
                        systemImage: "square.and.arrow.up"
                    )
                }

                Divider()

                NavigationLink {
                    ImportView()
                } label: {
                    actionRow(
                        title: "Import",
                        subtitle: "Bring in shifts and backups",
                        systemImage: "square.and.arrow.down"
                    )
                }
            }
            .background(ShiftProColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func actionRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: ShiftProSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(ShiftProColors.accent)
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                Text(title)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)
                Text(subtitle)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
        .padding(.vertical, ShiftProSpacing.small)
        .padding(.horizontal, ShiftProSpacing.small)
    }

    private func metricView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
            Text(title)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
            Text("\(value)h")
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for status: OvertimeForecast.Status) -> Color {
        switch status {
        case .safe:
            return ShiftProColors.success
        case .approaching:
            return ShiftProColors.warning
        case .exceeded:
            return ShiftProColors.danger
        }
    }
}

#Preview {
    NavigationStack {
        HoursDashboard()
    }
    .modelContainer(ModelContainerFactory.unsafePreviewContainer())
}
