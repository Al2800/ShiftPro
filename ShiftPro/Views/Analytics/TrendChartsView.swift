import SwiftUI
import Charts

/// Detailed trend charts view with multiple visualizations.
struct TrendChartsView: View {
    let weeklyStats: WeeklyStats?
    let monthlyStats: MonthlyStats?
    let yearlyStats: YearlyStats?
    
    @State private var selectedChart: ChartType = .hours
    
    var body: some View {
        VStack(spacing: 20) {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Hours Over Time")
                .font(.headline)
            
            if let monthly = monthlyStats {
                Chart(monthly.weeklyData) { week in
                    LineMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Hours", week.hours)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)
                    
                    AreaMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Hours", week.hours)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 250)
            } else {
                noDataView
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Weekday Distribution Chart
    
    private var weekdayChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hours by Day")
                .font(.headline)
            
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
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Earnings Chart
    
    private var earningsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Earnings")
                .font(.headline)
            
            if let yearly = yearlyStats {
                Chart(yearly.monthlyData) { month in
                    BarMark(
                        x: .value("Month", month.monthName),
                        y: .value("Hours", month.hours)
                    )
                    .foregroundStyle(.green.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 250)
            } else {
                noDataView
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Not enough data")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private func dayColor(_ weekday: Int) -> Color {
        if weekday == 1 || weekday == 7 {
            return .orange // Weekend
        }
        return .blue // Weekday
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Pattern")
                .font(.headline)
            
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(data) { day in
                    VStack(spacing: 4) {
                        Text(day.weekdayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(heatColor(hours: day.totalHours))
                            .frame(height: 40)
                            .overlay {
                                if day.totalHours > 0 {
                                    Text(String(format: "%.0f", day.totalHours))
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
            
            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(level: level))
                        .frame(width: 12, height: 12)
                }
                
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private func heatColor(hours: Double) -> Color {
        let maxHours = data.map { $0.totalHours }.max() ?? 1
        let normalized = hours / maxHours
        let level = Int(normalized * 4)
        return heatColor(level: level)
    }
    
    private func heatColor(level: Int) -> Color {
        switch level {
        case 0: return .blue.opacity(0.1)
        case 1: return .blue.opacity(0.3)
        case 2: return .blue.opacity(0.5)
        case 3: return .blue.opacity(0.7)
        default: return .blue.opacity(0.9)
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
