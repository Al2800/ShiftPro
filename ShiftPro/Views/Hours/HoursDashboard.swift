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

    private let calculator = PayPeriodCalculator()
    private let overtimePredictor = OvertimePredictor()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                heroCard

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

                recentPeriodsCard
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
    }

    private var profile: UserProfile? {
        profiles.first
    }

    private var currentPeriod: PayPeriod {
        if let stored = payPeriods.first(where: { $0.isCurrent }) {
            return stored
        }
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

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Current Pay Period")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)

            Text(currentPeriod.dateRangeFormatted)
                .font(ShiftProTypography.title)
                .foregroundStyle(ShiftProColors.ink)

            ProgressView(value: currentPeriod.progress)
                .tint(ShiftProColors.accent)

            HStack(spacing: ShiftProSpacing.medium) {
                metricView(title: "Total", value: String(format: "%.1f", summary.totalHours))
                metricView(title: "Regular", value: String(format: "%.1f", summary.regularHours))
                metricView(title: "Premium", value: String(format: "%.1f", summary.premiumHours))
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ShiftProColors.accentMuted, lineWidth: 1)
        )
        .accessibilityIdentifier("hours.heroCard")
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
                Text("No paid hours recorded yet.")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
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
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
