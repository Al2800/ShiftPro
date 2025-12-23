import SwiftUI
import SwiftData

/// Comprehensive hours tracking dashboard with pay period management
struct HoursDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PayPeriod.startDate, order: .reverse) private var allPeriods: [PayPeriod]
    @Query private var profiles: [UserProfile]

    @State private var selectedPeriod: PayPeriod?
    @State private var showPeriodDetail = false
    @State private var calculator = PayPeriodCalculator()
    @State private var predictor = OvertimePredictor()

    private var profile: UserProfile? {
        profiles.first
    }

    private var currentPeriod: PayPeriod? {
        allPeriods.first { $0.isCurrent && $0.deletedAt == nil }
    }

    private var recentPeriods: [PayPeriod] {
        allPeriods
            .filter { $0.deletedAt == nil }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.l) {
                if let period = currentPeriod {
                    currentPeriodSection(period)
                    overtimeWarningSection(period)
                    rateBreakdownSection(period)
                    trendSection
                } else {
                    emptyStateView
                }
            }
            .padding(.horizontal, ShiftProSpacing.m)
            .padding(.vertical, ShiftProSpacing.l)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Hours Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedPeriod) { period in
            NavigationStack {
                PayPeriodDetailView(period: period)
            }
        }
    }

    // MARK: - Current Period Section

    @ViewBuilder
    private func currentPeriodSection(_ period: PayPeriod) -> some View {
        let analysis = calculator.analyze(
            period: period,
            targetHours: profile?.regularHoursPerPay ?? 80,
            baseRateCents: profile?.baseRateCents
        )

        VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Pay Period")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    Text(period.dateRangeFormatted)
                        .font(ShiftProTypography.title)
                        .foregroundStyle(ShiftProColors.ink)
                }

                Spacer()

                Button {
                    selectedPeriod = period
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ShiftProColors.accent)
                }
            }

            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(format: "%.1f", analysis.totalHours))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(ShiftProColors.ink)
                    Text("/ \(analysis.targetHours) hours")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ShiftProColors.surfaceMuted)
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(progressColor(analysis.progressPercentage))
                            .frame(
                                width: min(geometry.size.width, geometry.size.width * (analysis.progressPercentage / 100.0)),
                                height: 12
                            )
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("\(Int(analysis.progressPercentage))% complete")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    Spacer()

                    if let projected = analysis.projectedTotalHours {
                        Text("Projected: \(String(format: "%.1f", projected))h")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            }

            // Quick Stats
            HStack(spacing: ShiftProSpacing.m) {
                statCard(
                    label: "Regular",
                    value: String(format: "%.1f", analysis.regularHours),
                    icon: "clock.fill",
                    color: ShiftProColors.success
                )

                statCard(
                    label: "Premium",
                    value: String(format: "%.1f", analysis.premiumHours),
                    icon: "star.fill",
                    color: ShiftProColors.warning
                )

                if let estimatedPay = period.estimatedPayFormatted {
                    statCard(
                        label: "Est. Pay",
                        value: estimatedPay,
                        icon: "dollarsign.circle.fill",
                        color: ShiftProColors.accent
                    )
                }
            }
        }
        .padding(ShiftProSpacing.m)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }

    // MARK: - Overtime Warning Section

    @ViewBuilder
    private func overtimeWarningSection(_ period: PayPeriod) -> some View {
        let prediction = predictor.predict(
            for: period,
            targetHours: profile?.regularHoursPerPay ?? 80
        )

        if prediction.warningLevel != .none {
            VStack(alignment: .leading, spacing: ShiftProSpacing.s) {
                HStack {
                    Image(systemName: prediction.warningLevel.iconName)
                        .foregroundStyle(warningColor(prediction.warningLevel))
                    Text(prediction.warningLevel.displayName)
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)
                }

                Text(prediction.message)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.inkSubtle)

                if let recommended = prediction.recommendedDailyHours, prediction.daysRemaining > 0 {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(ShiftProColors.accent)
                        Text("Average \(String(format: "%.1f", recommended)) hours/day to hit target")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(ShiftProSpacing.m)
            .background(warningColor(prediction.warningLevel).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(warningColor(prediction.warningLevel).opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Rate Breakdown Section

    @ViewBuilder
    private func rateBreakdownSection(_ period: PayPeriod) -> some View {
        let breakdown = calculator.calculateRateBreakdown(
            for: period,
            baseRateCents: profile?.baseRateCents
        )

        if !breakdown.isEmpty {
            VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
                Text("Rate Breakdown")
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(ShiftProColors.ink)

                let chartData = breakdown.map {
                    RateBreakdownChart.RateData(
                        label: $0.label,
                        hours: $0.hours,
                        multiplier: $0.multiplier
                    )
                }

                RateBreakdownChart(rateData: chartData, style: .pie)

                // Detail rows
                ForEach(breakdown) { rate in
                    rateDetailRow(rate)
                }
            }
            .padding(ShiftProSpacing.m)
            .background(ShiftProColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
        }
    }

    // MARK: - Trend Section

    @ViewBuilder
    private var trendSection: some View {
        if recentPeriods.count >= 2 {
            VStack(alignment: .leading, spacing: ShiftProSpacing.m) {
                Text("Trend")
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(ShiftProColors.ink)

                let trendData = calculator.calculateTrend(periods: recentPeriods)

                HoursChart(
                    dataPoints: trendData,
                    targetHours: profile?.regularHoursPerPay
                )

                // Period comparison
                if let current = currentPeriod,
                   let previous = recentPeriods.dropFirst().first {
                    let comparison = calculator.compareToPrevious(current: current, previous: previous)

                    HStack {
                        Image(systemName: comparison.hoursDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundStyle(comparison.hoursDelta >= 0 ? ShiftProColors.success : ShiftProColors.warning)

                        Text(String(format: "%.1f hours %@ last period", abs(comparison.hoursDelta), comparison.hoursDelta >= 0 ? "more than" : "less than"))
                            .font(ShiftProTypography.body)
                            .foregroundStyle(ShiftProColors.inkSubtle)

                        Spacer()

                        Text(String(format: "%+.1f%%", comparison.percentageChange))
                            .font(ShiftProTypography.mono)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(ShiftProSpacing.m)
            .background(ShiftProColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: ShiftProSpacing.m) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(ShiftProColors.inkSubtle)

            Text("No Active Pay Period")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            Text("Start adding shifts to see your hours dashboard")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.inkSubtle)
                .multilineTextAlignment(.center)
        }
        .padding(ShiftProSpacing.xl)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func statCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(ShiftProTypography.caption)
            }
            .foregroundStyle(ShiftProColors.inkSubtle)

            Text(value)
                .font(ShiftProTypography.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ShiftProSpacing.s)
        .background(ShiftProColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func rateDetailRow(_ rate: PayPeriodCalculator.RateBreakdown) -> some View {
        HStack {
            RateBadge(multiplier: rate.multiplier)

            Text(rate.label)
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.ink)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
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
        .padding(.vertical, 4)
    }

    // MARK: - Helper Methods

    private func progressColor(_ percentage: Double) -> Color {
        if percentage >= 100 {
            return ShiftProColors.success
        } else if percentage >= 80 {
            return ShiftProColors.accent
        } else if percentage >= 50 {
            return ShiftProColors.warning
        } else {
            return ShiftProColors.inkSubtle
        }
    }

    private func warningColor(_ level: OvertimePredictor.WarningLevel) -> Color {
        switch level {
        case .none:
            return ShiftProColors.success
        case .approaching:
            return ShiftProColors.accent
        case .warning:
            return ShiftProColors.warning
        case .critical, .exceeded:
            return ShiftProColors.danger
        }
    }
}

#Preview {
    NavigationStack {
        HoursDashboard()
            .modelContainer(for: [PayPeriod.self, Shift.self, UserProfile.self], inMemory: true)
    }
}
