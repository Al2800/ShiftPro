import SwiftUI
import SwiftData
import Charts

/// Main analytics dashboard view.
struct AnalyticsDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var analyticsEngine = AnalyticsEngine()

    @Query(filter: #Predicate<Shift> { $0.deletedAt == nil }, sort: [SortDescriptor(\Shift.scheduledStart, order: .forward)])
    private var shifts: [Shift]

    @Query(filter: #Predicate<PayPeriod> { $0.deletedAt == nil }, sort: [SortDescriptor(\PayPeriod.startDate, order: .reverse)])
    private var payPeriods: [PayPeriod]

    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    @State private var selectedPeriod: AnalyticsPeriod = .week
    @State private var showingAddShift = false
    @State private var showingImport = false
    @State private var showingExport = false
    @State private var navigateToHours = false

    private let calculator = PayPeriodCalculator()

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(ShiftProColors.accent)
                }
                .accessibilityLabel("Export Analytics")
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportOptionsView(period: currentPeriod, shifts: periodShifts)
        }
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
        .navigationDestination(isPresented: $navigateToHours) {
            HoursDashboard()
        }
    }

    private var hasAnyData: Bool {
        (analyticsEngine.weeklyMetrics?.shiftCount ?? 0) > 0 ||
        (analyticsEngine.monthlyMetrics?.shiftCount ?? 0) > 0 ||
        (analyticsEngine.yearlyMetrics?.shiftCount ?? 0) > 0
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

    private func action(for insight: AnalyticsInsight) -> (() -> Void)? {
        guard insight.actionLabel != nil else { return nil }

        switch insight.title {
        case "High Overtime", "Premium Rate Shifts":
            return { navigateToHours = true }
        case "Hours Increasing", "Consistent Schedule":
            return nil
        default:
            return nil
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "chart.bar.xaxis",
            title: "No analytics data",
            subtitle: "Complete some shifts to see your analytics and insights",
            actionTitle: "Add Shift",
            action: { showingAddShift = true },
            secondaryActionTitle: "Import Shifts",
            secondaryAction: { showingImport = true }
        )
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
                inlineEmptyState(
                    icon: "calendar.badge.clock",
                    title: "No shifts in this period",
                    subtitle: "Complete some shifts to see metrics"
                )
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShiftProShape(.standard)
    }

    private func inlineEmptyState(icon: String, title: String, subtitle: String? = nil) -> some View {
        VStack(spacing: ShiftProSpacing.small) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(ShiftProColors.inkSubtle)
            Text(title)
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.inkSubtle)
            if let subtitle {
                Text(subtitle)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ShiftProSpacing.medium)
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
        .clipShiftProShape(radius: ShiftProCornerRadius.medium)
    }

    // MARK: - Insights Section
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            Text("Insights")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            if analyticsEngine.insights.isEmpty {
                inlineEmptyState(
                    icon: "lightbulb",
                    title: "No insights yet",
                    subtitle: "Track a few more shifts to unlock personalized insights"
                )
            } else {
                ForEach(analyticsEngine.insights) { insight in
                    InsightCard(insight: insight, action: action(for: insight))
                }
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShiftProShape(.standard)
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
        .clipShiftProShape(.standard)
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
        .clipShiftProShape(.standard)
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
    var action: (() -> Void)?

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

            if let actionLabel = insight.actionLabel {
                Button(actionLabel) {
                    action?()
                }
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.accent)
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surfaceElevated)
        .clipShiftProShape(radius: ShiftProCornerRadius.medium)
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
