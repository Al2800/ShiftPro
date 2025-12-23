import SwiftUI

struct PayPeriodDetailView: View {
    let period: PayPeriod
    let shifts: [Shift]
    let baseRateCents: Int64?

    private let calculator = PayPeriodCalculator()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.l) {
                summaryCard

                HoursChart(dataPoints: dailyTotals, targetHours: nil)
                    .padding(ShiftProSpacing.m)
                    .background(ShiftProColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                RateBreakdownChart(rateData: rateData, style: .bar)
                    .padding(ShiftProSpacing.m)
                    .background(ShiftProColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                shiftsList
            }
            .padding(.horizontal, ShiftProSpacing.m)
            .padding(.vertical, ShiftProSpacing.l)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Pay Period")
    }

    private var summary: HoursCalculator.PeriodSummary {
        calculator.summary(for: shifts, baseRateCents: baseRateCents)
    }

    private var dailyTotals: [(date: Date, hours: Double)] {
        calculator.dailyTotals(for: shifts, within: period).map { ($0.date, $0.hours) }
    }

    private var rateData: [RateBreakdownChart.RateData] {
        let buckets = calculator.rateBreakdown(for: shifts)
        return buckets.map { RateBreakdownChart.RateData(label: $0.label, hours: $0.hours, multiplier: $0.multiplier) }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.s) {
            Text(period.dateRangeFormatted)
                .font(ShiftProTypography.title)
                .foregroundStyle(ShiftProColors.ink)

            HStack(spacing: ShiftProSpacing.m) {
                metricView(title: "Total", value: String(format: "%.1f", summary.totalHours))
                metricView(title: "Regular", value: String(format: "%.1f", summary.regularHours))
                metricView(title: "Premium", value: String(format: "%.1f", summary.premiumHours))
            }

            if let estimated = summary.estimatedPayCents {
                Text("Estimated pay: \(estimated.centsFormatted)")
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(ShiftProColors.ink)
            }
        }
        .padding(ShiftProSpacing.m)
        .background(ShiftProColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var shiftsList: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.s) {
            Text("Shifts")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            if shifts.isEmpty {
                Text("No shifts logged in this period yet.")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            } else {
                ForEach(shifts.sorted(by: { $0.scheduledStart > $1.scheduledStart }), id: \.id) { shift in
                    ShiftCardView(
                        title: shift.pattern?.name ?? "Shift",
                        timeRange: "\(shift.dateFormatted) • \(shift.timeRangeFormatted)",
                        location: shift.owner?.department ?? "",
                        status: status(for: shift),
                        rateMultiplier: shift.rateMultiplier,
                        notes: shift.notes
                    )
                }
            }
        }
    }

    private func metricView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.xxs) {
            Text(title)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
            Text("\(value)h")
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func status(for shift: Shift) -> StatusIndicator.Status {
        switch shift.status {
        case .scheduled:
            return .scheduled
        case .inProgress:
            return .inProgress
        case .completed:
            return .completed
        case .cancelled:
            return .missed
        }
    }
}

#Preview {
    NavigationStack {
        PayPeriodDetailView(period: PayPeriod.currentWeek(), shifts: [], baseRateCents: 3200)
    }
}
