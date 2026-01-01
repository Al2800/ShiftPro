import SwiftUI
import SwiftData
import Charts

/// Main analytics dashboard view.
struct AnalyticsDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var analyticsEngine = AnalyticsEngine()
    @State private var selectedPeriod: AnalyticsPeriod = .week
    @State private var showingAddShift = false
    @State private var showingImport = false

    var body: some View {
        ScrollView {
            VStack(spacing: ShiftProSpacing.large) {
                periodPicker

                if analyticsEngine.isLoading {
                    ProgressView("Analyzing data...")
                        .padding()
                } else if let errorMessage = analyticsEngine.errorMessage {
                    errorState(message: errorMessage)
                } else if !hasAnyData {
                    emptyState
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
        .background(ShiftProColors.background)
        .task {
            analyticsEngine.configure(with: modelContext)
            await refreshAnalytics()
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task {
                await refreshAnalytics()
            }
        }
        .sheet(isPresented: $showingAddShift) {
            ShiftFormView()
        }
        .sheet(isPresented: $showingImport) {
            ImportView()
        }
    }

    private var hasAnyData: Bool {
        (analyticsEngine.weeklyMetrics?.shiftCount ?? 0) > 0 ||
        (analyticsEngine.monthlyMetrics?.shiftCount ?? 0) > 0 ||
        (analyticsEngine.yearlyMetrics?.shiftCount ?? 0) > 0
    }

    private var emptyState: some View {
        VStack(spacing: ShiftProSpacing.medium) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(ShiftProColors.inkSubtle)

            Text("No Analytics Data")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            Text("Complete some shifts to see your analytics and insights")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
                .multilineTextAlignment(.center)

            callToActionButtons
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ShiftProSpacing.extraLarge)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: ShiftProSpacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(ShiftProColors.warning)

            Text("Analytics Unavailable")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            Text(message)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await refreshAnalytics() }
            }
            .font(ShiftProTypography.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ShiftProSpacing.extraLarge)
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
        VStack(spacing: ShiftProSpacing.medium) {
            Text("Overview")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let metrics = currentMetrics, metrics.shiftCount > 0 {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: ShiftProSpacing.medium) {
                    metricCard(
                        title: "Total Hours",
                        value: metrics.totalHours,
                        format: "%.1f",
                        icon: "clock.fill",
                        color: ShiftProColors.accent
                    )

                    metricCard(
                        title: "Shifts",
                        value: Double(metrics.shiftCount),
                        format: "%.0f",
                        icon: "calendar",
                        color: ShiftProColors.success
                    )

                    metricCard(
                        title: "Avg Duration",
                        value: metrics.averageShiftDuration,
                        format: "%.1fh",
                        icon: "timer",
                        color: ShiftProColors.warning
                    )

                    metricCard(
                        title: "Premium Hours",
                        value: metrics.premiumHours,
                        format: "%.1f",
                        icon: "star.fill",
                        color: ShiftProColors.accentMuted
                    )
                }
            } else {
                Text("No shifts in this period yet.")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    private func metricCard(title: String, value: Double, format: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(String(format: format, value))
                .font(ShiftProTypography.title)
                .fontWeight(.bold)
                .foregroundStyle(ShiftProColors.ink)

            Text(title)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - Insights Section
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            Text("Insights")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            if analyticsEngine.insights.isEmpty {
                VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                    Text("No insights yet.")
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColors.ink)
                    Text("Track a few more shifts to unlock personalized insights.")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
                .padding(ShiftProSpacing.medium)
            } else {
                ForEach(analyticsEngine.insights) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    // MARK: - Trends Section
    
    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            Text("Trends")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            if let metrics = currentMetrics, metrics.shiftCount > 0 {
                let change = metrics.comparedToPrevious
                TrendIndicator(
                    title: "vs Previous Period",
                    change: change,
                    isPositive: change >= 0
                )
            } else {
                Text("Add shifts to start tracking trends.")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            Text("Hours Breakdown")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            Group {
                switch selectedPeriod {
                case .week:
                    if let weekly = analyticsEngine.weeklyMetrics, let byDay = weekly.byDay, !byDay.isEmpty {
                        Chart(byDay) { day in
                            BarMark(
                                x: .value("Day", day.dayName),
                                y: .value("Hours", day.hours)
                            )
                            .foregroundStyle(ShiftProColors.accent.gradient)
                        }
                        .frame(height: 200)
                        .chartYAxisLabel("Hours")
                    } else {
                        chartEmptyState
                    }
                case .month:
                    if let monthly = analyticsEngine.monthlyMetrics, let byWeek = monthly.byWeek, !byWeek.isEmpty {
                        Chart(byWeek) { week in
                            BarMark(
                                x: .value("Week", "W\(week.weekOfMonth)"),
                                y: .value("Hours", week.hours)
                            )
                            .foregroundStyle(ShiftProColors.accent.gradient)
                        }
                        .frame(height: 200)
                        .chartYAxisLabel("Hours")
                    } else {
                        chartEmptyState
                    }
                case .year:
                    if let yearly = analyticsEngine.yearlyMetrics, let byMonth = yearly.byMonth, !byMonth.isEmpty {
                        Chart(byMonth) { month in
                            BarMark(
                                x: .value("Month", month.monthName),
                                y: .value("Hours", month.hours)
                            )
                            .foregroundStyle(ShiftProColors.accent.gradient)
                        }
                        .frame(height: 200)
                        .chartYAxisLabel("Hours")
                    } else {
                        chartEmptyState
                    }
                }
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var chartEmptyState: some View {
        VStack(spacing: ShiftProSpacing.small) {
            Image(systemName: "chart.bar")
                .font(.system(size: 32))
                .foregroundStyle(ShiftProColors.inkSubtle)
            Text("No data for this period")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
            Button("Add Shift") {
                showingAddShift = true
            }
            .font(ShiftProTypography.caption)
            .foregroundStyle(ShiftProColors.accent)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var callToActionButtons: some View {
        VStack(spacing: ShiftProSpacing.small) {
            QuickActionButton(title: "Add Shift", systemImage: "plus.circle.fill") {
                showingAddShift = true
            }

            Button("Import Shifts") {
                showingImport = true
            }
            .font(ShiftProTypography.caption)
            .foregroundStyle(ShiftProColors.accent)
        }
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

    private func refreshAnalytics() async {
        await analyticsEngine.refreshAllMetrics()
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
        HStack(spacing: ShiftProSpacing.medium) {
            Circle()
                .fill(insightColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: insightIcon)
                        .foregroundStyle(insightColor)
                }

            VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                Text(insight.title)
                    .font(ShiftProTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ShiftProColors.ink)

                Text(insight.message)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            Spacer()

            if let action = insight.actionLabel {
                Button(action) {}
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.accent)
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var insightColor: Color {
        switch insight.type {
        case .positive: return ShiftProColors.success
        case .warning: return ShiftProColors.warning
        case .info: return ShiftProColors.accent
        case .suggestion: return ShiftProColors.accentMuted
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
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.ink)

            Spacer()

            HStack(spacing: ShiftProSpacing.extraExtraSmall) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                Text(String(format: "%+.1f%%", change * 100))
            }
            .font(ShiftProTypography.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(isPositive ? ShiftProColors.success : ShiftProColors.danger)
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
