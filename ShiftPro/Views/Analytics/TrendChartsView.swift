import SwiftUI
import Charts

/// Detailed trend charts view with multiple visualizations.
struct TrendChartsView: View {
    let weeklyStats: WeeklyStats?
    let monthlyStats: MonthlyStats?
    let yearlyStats: YearlyStats?
    var onAddShift: (() -> Void)?

    @State private var selectedChart: ChartType = .hours

    var body: some View {
        VStack(spacing: ShiftProSpacing.large) {
            // Chart type selector
            Picker("Chart", selection: $selectedChart) {
                ForEach(ChartType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Selected chart
            switch selectedChart {
            case .hours:
                hoursChart
            case .weekday:
                weekdayChart
            case .earnings:
                earningsChart
            }
        }
    }
    
    // MARK: - Hours Chart

    private var hoursChart: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Hours Over Time")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            if let monthly = monthlyStats, !monthly.weeklyData.isEmpty {
                Chart(monthly.weeklyData) { week in
                    LineMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Hours", week.hours)
                    )
                    .foregroundStyle(ShiftProColors.accent)
                    .symbol(.circle)

                    AreaMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Hours", week.hours)
                    )
                    .foregroundStyle(ShiftProColors.accent.opacity(0.1))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 250)
            } else {
                noDataView
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShiftProShape(.standard)
    }
    
    // MARK: - Weekday Distribution Chart

    private var weekdayChart: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Hours by Day")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            if let weekly = weeklyStats, !weekly.dayBreakdown.isEmpty {
                Chart(weekly.dayBreakdown) { day in
                    BarMark(
                        x: .value("Day", day.weekdayName),
                        y: .value("Hours", day.totalHours)
                    )
                    .foregroundStyle(dayColor(day.weekday).gradient)
                    .cornerRadius(4)
                }
                .frame(height: 250)
            } else {
                noDataView
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShiftProShape(.standard)
    }

    // MARK: - Earnings Chart

    private var earningsChart: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Monthly Hours")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            if let yearly = yearlyStats, !yearly.monthlyData.isEmpty {
                Chart(yearly.monthlyData) { month in
                    BarMark(
                        x: .value("Month", month.monthName),
                        y: .value("Hours", month.hours)
                    )
                    .foregroundStyle(ShiftProColors.success.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 250)
            } else {
                noDataView
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShiftProShape(.standard)
    }
    
    // MARK: - Helpers

    private var noDataView: some View {
        VStack(spacing: ShiftProSpacing.medium) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(ShiftProColors.inkSubtle)

            VStack(spacing: ShiftProSpacing.extraSmall) {
                Text("Not Enough Data")
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(ShiftProColors.ink)

                Text("Add shifts to see your trends")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            if let onAddShift {
                Button(action: onAddShift) {
                    HStack(spacing: ShiftProSpacing.extraSmall) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Shift")
                    }
                    .font(ShiftProTypography.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, ShiftProSpacing.medium)
                    .padding(.vertical, ShiftProSpacing.small)
                    .background(ShiftProColors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    private func dayColor(_ weekday: Int) -> Color {
        if weekday == 1 || weekday == 7 {
            return ShiftProColors.warning // Weekend
        }
        return ShiftProColors.accent // Weekday
    }
}

// MARK: - Chart Type

enum ChartType: String, CaseIterable, Identifiable {
    case hours = "hours"
    case weekday = "weekday"
    case earnings = "earnings"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .hours: return "Hours"
        case .weekday: return "By Day"
        case .earnings: return "Earnings"
        }
    }
}

// MARK: - Heat Map View

struct WeekdayHeatMap: View {
    let data: [WeekdayData]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Weekly Pattern")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(data) { day in
                    VStack(spacing: 4) {
                        Text(day.weekdayName)
                            .font(ShiftProTypography.footnote)
                            .foregroundStyle(ShiftProColors.inkSubtle)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(heatColor(hours: day.totalHours))
                            .frame(height: 40)
                            .overlay {
                                if day.totalHours > 0 {
                                    Text(String(format: "%.0f", day.totalHours))
                                        .font(ShiftProTypography.footnote)
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(ShiftProTypography.footnote)
                    .foregroundStyle(ShiftProColors.inkSubtle)

                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(level: level))
                        .frame(width: 12, height: 12)
                }

                Text("More")
                    .font(ShiftProTypography.footnote)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func heatColor(hours: Double) -> Color {
        let maxHours = data.map { $0.totalHours }.max() ?? 1
        let normalized = hours / maxHours
        let level = Int(normalized * 4)
        return heatColor(level: level)
    }

    private func heatColor(level: Int) -> Color {
        switch level {
        case 0: return ShiftProColors.accent.opacity(0.1)
        case 1: return ShiftProColors.accent.opacity(0.3)
        case 2: return ShiftProColors.accent.opacity(0.5)
        case 3: return ShiftProColors.accent.opacity(0.7)
        default: return ShiftProColors.accent.opacity(0.9)
        }
    }
}

#Preview {
    TrendChartsView(
        weeklyStats: nil,
        monthlyStats: nil,
        yearlyStats: nil
    )
}
