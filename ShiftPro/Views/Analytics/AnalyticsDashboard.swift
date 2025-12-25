import SwiftUI
import Charts

/// Main analytics dashboard view.
struct AnalyticsDashboard: View {
    @StateObject private var analyticsEngine = AnalyticsEngine()
    @State private var selectedPeriod: AnalyticsPeriod = .week
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker
                
                if analyticsEngine.isLoading {
                    ProgressView("Analyzing data...")
                        .padding()
                } else {
                    metricsOverview
                    insightsSection
                    trendsSection
                    chartsSection
                }
            }
            .padding()
        }
        .navigationTitle("Analytics")
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            await analyticsEngine.refreshAllMetrics()
        }
    }
    
    // MARK: - Period Picker
    
    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Metrics Overview
    
    private var metricsOverview: some View {
        VStack(spacing: 16) {
            Text("Overview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                metricCard(
                    title: "Total Hours",
                    value: currentMetrics?.totalHours ?? 0,
                    format: "%.1f",
                    icon: "clock.fill",
                    color: .blue
                )
                
                metricCard(
                    title: "Shifts",
                    value: Double(currentMetrics?.shiftCount ?? 0),
                    format: "%.0f",
                    icon: "calendar",
                    color: .green
                )
                
                metricCard(
                    title: "Avg Duration",
                    value: currentMetrics?.averageShiftDuration ?? 0,
                    format: "%.1fh",
                    icon: "timer",
                    color: .orange
                )
                
                metricCard(
                    title: "Premium Hours",
                    value: currentMetrics?.premiumHours ?? 0,
                    format: "%.1f",
                    icon: "star.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func metricCard(title: String, value: Double, format: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(String(format: format, value))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Insights Section
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
            
            if analyticsEngine.insights.isEmpty {
                Text("No insights available yet. Keep tracking your shifts!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(analyticsEngine.insights) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Trends Section
    
    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends")
                .font(.headline)
            
            if let metrics = currentMetrics {
                let change = metrics.comparedToPrevious
                TrendIndicator(
                    title: "vs Previous Period",
                    change: change,
                    isPositive: change >= 0
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Charts Section
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hours Breakdown")
                .font(.headline)
            
            if let weekly = analyticsEngine.weeklyMetrics, let byDay = weekly.byDay {
                Chart(byDay) { day in
                    BarMark(
                        x: .value("Day", day.dayName),
                        y: .value("Hours", day.hours)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: 200)
                .chartYAxisLabel("Hours")
            } else {
                Text("No data available for chart")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Computed Properties
    
    private var currentMetrics: MetricsSnapshot? {
        switch selectedPeriod {
        case .week:
            guard let weeklyMetrics = analyticsEngine.weeklyMetrics else { return nil }
            return MetricsSnapshot(
                totalHours: weeklyMetrics.totalHours,
                shiftCount: weeklyMetrics.shiftCount,
                averageShiftDuration: weeklyMetrics.averageShiftDuration,
                premiumHours: weeklyMetrics.premiumHours,
                comparedToPrevious: weeklyMetrics.comparedToPrevious
            )
        case .month:
            guard let monthlyMetrics = analyticsEngine.monthlyMetrics else { return nil }
            return MetricsSnapshot(
                totalHours: monthlyMetrics.totalHours,
                shiftCount: monthlyMetrics.shiftCount,
                averageShiftDuration: monthlyMetrics.averageShiftDuration,
                premiumHours: monthlyMetrics.premiumHours,
                comparedToPrevious: monthlyMetrics.comparedToPrevious
            )
        case .year:
            guard let yearlyMetrics = analyticsEngine.yearlyMetrics else { return nil }
            return MetricsSnapshot(
                totalHours: yearlyMetrics.totalHours,
                shiftCount: yearlyMetrics.shiftCount,
                averageShiftDuration: yearlyMetrics.averageShiftDuration,
                premiumHours: yearlyMetrics.premiumHours,
                comparedToPrevious: yearlyMetrics.comparedToPrevious
            )
        }
    }
}

private struct MetricsSnapshot {
    let totalHours: Double
    let shiftCount: Int
    let averageShiftDuration: Double
    let premiumHours: Double
    let comparedToPrevious: Double
}

// MARK: - Supporting Views

struct InsightCard: View {
    let insight: AnalyticsInsight
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(insightColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: insightIcon)
                        .foregroundStyle(insightColor)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let action = insight.actionLabel {
                Button(action) {}
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var insightColor: Color {
        switch insight.type {
        case .positive: return .green
        case .warning: return .orange
        case .info: return .blue
        case .suggestion: return .purple
        }
    }
    
    private var insightIcon: String {
        switch insight.type {
        case .positive: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .suggestion: return "lightbulb.fill"
        }
    }
}

struct TrendIndicator: View {
    let title: String
    let change: Double
    let isPositive: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                Text(String(format: "%+.1f%%", change * 100))
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(isPositive ? .green : .red)
        }
    }
}

// MARK: - Analytics Period

enum AnalyticsPeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

#Preview {
    NavigationStack {
        AnalyticsDashboard()
    }
}
