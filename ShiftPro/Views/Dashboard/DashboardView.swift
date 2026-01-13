import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateIn = false
    @State private var showingAddShift = false
    @State private var showingPatternBuilder = false
    @State private var showingLogBreak = false
    @State private var breakMinutesToLog: Int = 15
    @State private var isProcessingAction = false
    @State private var actionError: String?
    @State private var showingActionError = false
    @State private var showingNotifications = false
    @Query(filter: #Predicate<Shift> { $0.deletedAt == nil }, sort: [SortDescriptor(\Shift.scheduledStart, order: .forward)])
    private var shifts: [Shift]
    @Query(filter: #Predicate<PayPeriod> { $0.deletedAt == nil }, sort: [SortDescriptor(\PayPeriod.startDate, order: .reverse)])
    private var payPeriods: [PayPeriod]
    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    private let calculator = PayPeriodCalculator()

    var body: some View {
        ZStack {
            // Premium animated background
            AnimatedMeshBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                    // Premium branding header
                    premiumHeader
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : -10)

                    // Premium hero card
                    premiumHeroSection
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateIn)

                    // Hours & earnings section
                    hoursSection
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 16)
                        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)

                    // Upcoming shifts section
                    upcomingSection
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 12)
                        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateIn)

                    // Overtime shifts section
                    overtimeSection
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 10)
                        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: animateIn)

                    // Quick actions
                    premiumQuickActions
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 8)
                        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateIn)
                }
                .padding(.horizontal, ShiftProSpacing.medium)
                .padding(.top, ShiftProSpacing.large)
                .padding(.bottom, ShiftProSpacing.tabBarPadding)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
            ToolbarItem(placement: .topBarTrailing) {
                PremiumIconButton(icon: "bell.badge", style: .secondary) {
                    showingNotifications = true
                }
                .accessibilityLabel("Notifications")
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NavigationStack {
                NotificationSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingNotifications = false
                            }
                        }
                    }
            }
        }
        .onAppear {
            guard !animateIn else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateIn = true
            }
        }
        .sheet(isPresented: $showingAddShift) {
            ShiftFormView()
        }
        .sheet(isPresented: $showingPatternBuilder) {
            SimplePatternBuilderView()
        }
        .sheet(isPresented: $showingLogBreak) {
            logBreakSheet
        }
        .alert("Error", isPresented: $showingActionError) {
            Button("OK") { }
        } message: {
            Text(actionError ?? "An error occurred")
        }
        .disabled(isProcessingAction)
    }

    // MARK: - Premium Header

    private var premiumHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("Shift")
                        .foregroundStyle(ShiftProColors.ink)
                    Text("Pro")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.35, green: 0.55, blue: 0.98),
                                    Color(red: 0.55, green: 0.40, blue: 0.92)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(greetingText)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            Spacer()
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    // MARK: - Premium Hero Section

    @ViewBuilder
    private var premiumHeroSection: some View {
        if let shift = currentShift {
            PremiumHeroCard(
                title: "On Shift Now",
                subtitle: elapsedTimeDescription(for: shift),
                badge: "In Progress",
                estimatedPay: heroPayEstimate,
                actionTitle: isProcessingAction ? "..." : "End Shift",
                actionIcon: "stop.fill",
                isLoading: isProcessingAction,
                style: .success,
                breakInfo: .init(
                    currentMinutes: shift.breakMinutes,
                    quickOptions: [5, 15, 30]
                ),
                action: { Task { await handleStartEndShift() } },
                onBreakTap: { minutes in
                    Task { await logQuickBreak(minutes: minutes, for: shift) }
                }
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.dashboardHeroCard)
        } else if let nextShift = upcomingShifts.first {
            PremiumHeroCard(
                title: heroTitle,
                subtitle: heroSubtitle,
                estimatedPay: heroPayEstimate,
                actionTitle: isProcessingAction ? "..." : "Start Shift",
                actionIcon: "play.fill",
                isLoading: isProcessingAction,
                style: .primary,
                action: { Task { await handleStartEndShift() } }
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.dashboardHeroCard)
        } else {
            // Empty state hero - guide users to create a pattern first
            VStack(spacing: ShiftProSpacing.medium) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(ShiftProColors.accent.opacity(0.6))

                Text("Welcome to ShiftPro")
                    .font(ShiftProTypography.title)
                    .foregroundStyle(ShiftProColors.ink)

                Text("Set up your work pattern to automatically schedule your shifts")
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(ShiftProColors.inkSubtle)
                    .multilineTextAlignment(.center)

                VStack(spacing: ShiftProSpacing.small) {
                    // Primary action - Create pattern
                    PremiumButton(
                        title: "Create Work Pattern",
                        icon: "repeat.circle.fill",
                        style: .primary
                    ) {
                        showingPatternBuilder = true
                    }

                    // Secondary action - Add single shift
                    Button {
                        showingAddShift = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 14, weight: .medium))
                            Text("Add a single shift instead")
                                .font(ShiftProTypography.caption)
                        }
                        .foregroundStyle(ShiftProColors.accent)
                    }
                    .padding(.top, ShiftProSpacing.extraSmall)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(ShiftProSpacing.extraLarge)
            .glassMorphism(intensity: 0.8, cornerRadius: 28)
        }
    }

    private func elapsedTimeDescription(for shift: Shift) -> String {
        guard let start = shift.actualStart else { return "Just started" }
        let elapsed = Date().timeIntervalSince(start)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60

        if hours > 0 {
            return "Started \(hours)h \(minutes)m ago"
        } else {
            return "Started \(minutes) minutes ago"
        }
    }

    // MARK: - Hours Section

    @ViewBuilder
    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            SectionHeader.withIcon("This Period", icon: "chart.bar.fill")

            if periodShifts.isEmpty {
                EmptyStateView(
                    icon: "chart.bar.xaxis",
                    title: "No hours yet",
                    subtitle: "Complete a shift to track your hours",
                    actionTitle: "Add Shift",
                    action: { showingAddShift = true }
                )
            } else {
                // Earnings highlight
                if let pay = estimatedPay, pay > 0 {
                    EarningsHighlightCard(
                        amount: pay,
                        label: "Estimated Earnings",
                        subtitle: periodLabel
                    )
                }

                // Stats grid
                HStack(spacing: ShiftProSpacing.small) {
                    PremiumStatCard(
                        title: "Total Hours",
                        value: summary.totalHours,
                        unit: "hrs",
                        icon: "clock.fill",
                        trend: hoursTrend.map { .init(delta: $0, label: "vs last period") },
                        showRing: true,
                        ringProgress: min(summary.totalHours / 40.0, 1.0)
                    )
                }

                // Mini stats
                StatGrid(stats: [
                    ("Regular", String(format: "%.1f hrs", summary.regularHours), "sun.max.fill", ShiftProColors.accent),
                    ("Overtime", String(format: "%.1f hrs", summary.premiumHours), "flame.fill", ShiftProColors.warning),
                    ("Shifts", "\(periodShifts.count)", "calendar", ShiftProColors.success),
                    ("Avg/Shift", avgHoursPerShift, "chart.line.uptrend.xyaxis", ShiftProColors.inkSubtle)
                ])
            }
        }
    }

    private var periodLabel: String {
        let type = profile?.payPeriodType ?? .biweekly
        switch type {
        case .weekly: return "This week"
        case .biweekly: return "This pay period"
        case .monthly: return "This month"
        }
    }

    private var avgHoursPerShift: String {
        guard !periodShifts.isEmpty else { return "0 hrs" }
        let avg = summary.totalHours / Double(periodShifts.count)
        return String(format: "%.1f hrs", avg)
    }

    // MARK: - Upcoming Section

    @ViewBuilder
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            HStack {
                SectionHeader.withIcon("Upcoming", icon: "calendar.badge.clock")

                Spacer()

                if !upcomingShifts.isEmpty {
                    Button {
                        NotificationCenter.default.post(name: .switchToScheduleTab, object: nil)
                    } label: {
                        HStack(spacing: 4) {
                            Text("See all")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.accent)
                    }
                    .accessibilityIdentifier("dashboard.seeAllUpcoming")
                }
            }

            if dashboardShifts.isEmpty && currentShift == nil {
                // Already handled in hero section
                EmptyView()
            } else {
                ForEach(Array(dashboardShifts.filter { $0.id != currentShift?.id }.prefix(3).enumerated()), id: \.element.id) { index, shift in
                    PremiumShiftRow(
                        shift: shift,
                        profile: profile,
                        onTap: {
                            NotificationCenter.default.post(name: .switchToScheduleTab, object: nil)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
    }

    // MARK: - Overtime Section

    @ViewBuilder
    private var overtimeSection: some View {
        if !upcomingOvertimeShifts.isEmpty {
            VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                SectionHeader.withIcon("Overtime", icon: "flame.fill")

                ForEach(upcomingOvertimeShifts.prefix(3), id: \.id) { shift in
                    overtimeShiftRow(shift: shift)
                }
            }
        }
    }

    private func overtimeShiftRow(shift: Shift) -> some View {
        HStack(spacing: ShiftProSpacing.medium) {
            // Rate multiplier badge
            Text(String(format: "%.1fx", shift.rateMultiplier))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(ShiftProColors.warning)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(shift.scheduledStart.relativeFormatted)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(ShiftProColors.ink)

                Text(shift.timeRangeFormatted)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            Spacer()

            if let pay = estimatedPayLabel(for: shift) {
                Text(pay)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(ShiftProColors.warning)
            }
        }
        .padding(.horizontal, ShiftProSpacing.medium)
        .padding(.vertical, ShiftProSpacing.small + 2)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ShiftProColors.warning.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(ShiftProColors.warning.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture {
            NotificationCenter.default.post(name: .switchToScheduleTab, object: nil)
        }
    }

    // MARK: - Quick Actions

    private var premiumQuickActions: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            SectionHeader.withIcon("Quick Actions", icon: "bolt.fill")

            HStack(spacing: ShiftProSpacing.small) {
                PremiumButton(
                    title: "Add Shift",
                    icon: "plus",
                    style: .primary,
                    fullWidth: true
                ) {
                    showingAddShift = true
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.dashboardAddShift)

                PremiumButton(
                    title: "Schedule",
                    icon: "calendar",
                    style: .secondary,
                    fullWidth: true
                ) {
                    NotificationCenter.default.post(name: .switchToScheduleTab, object: nil)
                }
                .accessibilityIdentifier("dashboard.viewSchedule")
            }

            if currentShift != nil {
                PremiumButton(
                    title: "Log Break",
                    icon: "cup.and.saucer",
                    style: .ghost,
                    fullWidth: true
                ) {
                    handleLogBreak()
                }
                .accessibilityIdentifier("dashboard.logBreak")
            }
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

    /// Previous pay period for trend comparison
    private var previousPeriod: PayPeriod {
        let periodType = profile?.payPeriodType ?? .biweekly
        let daysToSubtract: Int
        switch periodType {
        case .weekly:
            daysToSubtract = 7
        case .biweekly:
            daysToSubtract = 14
        case .monthly:
            daysToSubtract = 30
        }
        let previousDate = Calendar.current.date(
            byAdding: .day,
            value: -daysToSubtract,
            to: currentPeriod.startDate
        ) ?? currentPeriod.startDate
        return calculator.period(for: previousDate, type: periodType, referenceDate: profile?.startDate)
    }

    private var previousPeriodShifts: [Shift] {
        calculator.shifts(in: previousPeriod, from: shifts)
    }

    private var previousSummary: HoursCalculator.PeriodSummary {
        calculator.summary(for: previousPeriodShifts, baseRateCents: profile?.baseRateCents)
    }

    /// Delta in hours vs previous period (positive = more hours this period)
    private var hoursTrend: Double? {
        guard !previousPeriodShifts.isEmpty else { return nil }
        return summary.totalHours - previousSummary.totalHours
    }

    /// Estimated pay for current period
    private var estimatedPay: Double? {
        guard let cents = summary.estimatedPayCents, cents > 0 else { return nil }
        return Double(cents) / 100.0
    }

    private var currentShift: Shift? {
        shifts.first { $0.status == .inProgress }
    }

    private var upcomingShifts: [Shift] {
        let now = Date()
        return shifts.filter { shift in
            shift.scheduledStart >= now && shift.status != .cancelled
        }
    }

    private var upcomingOvertimeShifts: [Shift] {
        upcomingShifts.filter { $0.rateMultiplier >= 1.3 }
    }

    private var dashboardShifts: [Shift] {
        var items: [Shift] = []
        if let currentShift {
            items.append(currentShift)
        }
        let future = upcomingShifts.filter { $0.id != currentShift?.id }
        items.append(contentsOf: future.prefix(2))
        return items
    }

    private var heroTitle: String {
        if let _ = currentShift {
            return "On shift now"
        }
        if !upcomingShifts.isEmpty {
            return "Next shift"
        }
        return "No upcoming shifts"
    }

    private var heroSubtitle: String {
        if let currentShift {
            if let remaining = timeRemaining(until: currentShift.effectiveEnd) {
                return "Ends in \(remaining)"
            }
            return "Ends at \(currentShift.effectiveEnd.shiftTimeFormatted)"
        }
        if let next = upcomingShifts.first {
            if let remaining = timeRemaining(until: next.scheduledStart) {
                return "Starts in \(remaining)"
            }
            return "\(next.scheduledStart.relativeFormatted) • \(next.timeRangeFormatted)"
        }
        return "Add your next shift to get started."
    }

    private var heroActionTitle: String {
        currentShift == nil ? "Start Shift" : "End Shift"
    }

    private var heroActionIcon: String {
        currentShift == nil ? "play.fill" : "stop.fill"
    }

    /// Projected earnings for the hero card shift (current or next)
    private var heroPayEstimate: String? {
        guard let baseRateCents = profile?.baseRateCents, baseRateCents > 0 else { return nil }

        let shift: Shift?
        if let current = currentShift {
            shift = current
        } else {
            shift = upcomingShifts.first
        }

        guard let shift else { return nil }

        return estimatedPayLabel(for: shift)
    }

    /// Projected earnings for a specific shift
    private func estimatedPayLabel(for shift: Shift) -> String? {
        guard let baseRateCents = profile?.baseRateCents, baseRateCents > 0 else { return nil }

        // Calculate estimated paid minutes (scheduled duration minus break)
        let estimatedPaidMinutes = max(0, shift.scheduledDurationMinutes - shift.breakMinutes)
        let hours = Double(estimatedPaidMinutes) / 60.0
        let earnings = hours * shift.rateMultiplier * Double(baseRateCents) / 100.0

        // Format as currency
        return CurrencyFormatter.format(earnings)
    }


    private func logQuickBreak(minutes: Int, for shift: Shift) async {
        isProcessingAction = true
        defer { isProcessingAction = false }

        let manager = await ShiftManager(context: modelContext)
        do {
            let newBreakMinutes = shift.breakMinutes + minutes
            try await manager.updateShift(shift, breakMinutes: newBreakMinutes)
        } catch {
            actionError = error.localizedDescription
            showingActionError = true
        }
    }

    private func timeRemaining(until date: Date) -> String? {
        guard date > Date() else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: Date(), to: date)
    }

    private func statusIndicator(for shift: Shift) -> StatusIndicator.Status {
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

    private func shiftAccessibilityIdentifier(for shift: Shift) -> String? {
        if shift.id == currentShift?.id {
            return AccessibilityIdentifiers.dashboardActiveShift
        }
        if shift.id == upcomingShifts.first?.id {
            return AccessibilityIdentifiers.dashboardUpcomingShift
        }
        return nil
    }


    // MARK: - Action Handlers

    private func handleStartEndShift() async {
        isProcessingAction = true
        defer { isProcessingAction = false }

        let manager = await ShiftManager(context: modelContext)
        do {
            try await manager.toggleCurrentShift()
        } catch {
            actionError = error.localizedDescription
            showingActionError = true
        }
    }

    private func handleLogBreak() {
        guard let _ = currentShift else { return }
        breakMinutesToLog = 15
        showingLogBreak = true
    }

    private func logBreakMinutes() async {
        guard let shift = currentShift else { return }

        isProcessingAction = true
        defer { isProcessingAction = false }

        let manager = await ShiftManager(context: modelContext)
        do {
            let newBreakMinutes = shift.breakMinutes + breakMinutesToLog
            try await manager.updateShift(shift, breakMinutes: newBreakMinutes)
            showingLogBreak = false
        } catch {
            actionError = error.localizedDescription
            showingActionError = true
        }
    }

    // MARK: - Log Break Sheet

    private var logBreakSheet: some View {
        NavigationStack {
            VStack(spacing: ShiftProSpacing.large) {
                // Quick break buttons
                VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                    Text("Quick Add")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                        .textCase(.uppercase)

                    HStack(spacing: ShiftProSpacing.small) {
                        ForEach([5, 15, 30, 60], id: \.self) { minutes in
                            Button {
                                breakMinutesToLog = minutes
                                Task { await logBreakMinutes() }
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(minutes)")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                    Text("min")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, ShiftProSpacing.medium)
                                .background(ShiftProColors.surface)
                                .foregroundStyle(ShiftProColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .shiftProPressable(scale: 0.96, opacity: 0.9, haptic: .impactMedium)
                            .disabled(isProcessingAction)
                        }
                    }
                }
                .padding(.horizontal, ShiftProSpacing.medium)

                Divider()
                    .padding(.horizontal, ShiftProSpacing.medium)

                // Custom duration picker
                VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                    Text("Custom Duration")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                        .textCase(.uppercase)
                        .padding(.horizontal, ShiftProSpacing.medium)

                    Picker("Minutes", selection: $breakMinutesToLog) {
                        ForEach([5, 10, 15, 20, 25, 30, 45, 60], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                // Current break status
                if let shift = currentShift {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Already logged")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                            Text("\(shift.breakMinutes) min")
                                .font(ShiftProTypography.headline)
                                .foregroundStyle(ShiftProColors.ink)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(ShiftProColors.inkSubtle)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("After logging")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                            Text("\(shift.breakMinutes + breakMinutesToLog) min")
                                .font(ShiftProTypography.headline)
                                .foregroundStyle(ShiftProColors.accent)
                        }
                    }
                    .padding(ShiftProSpacing.medium)
                    .background(ShiftProColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, ShiftProSpacing.medium)
                }

                Spacer()

                // Log button for custom duration
                Button {
                    Task { await logBreakMinutes() }
                } label: {
                    Text(isProcessingAction ? "Logging..." : "Log \(breakMinutesToLog) Minutes")
                        .font(ShiftProTypography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ShiftProSpacing.medium)
                        .background(ShiftProColors.accent)
                        .foregroundStyle(ShiftProColors.midnight)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .shiftProPressable(scale: 0.98, opacity: 0.96, haptic: .selection)
                .disabled(isProcessingAction)
                .padding(.horizontal, ShiftProSpacing.medium)
                .padding(.bottom, ShiftProSpacing.medium)
            }
            .padding(.top, ShiftProSpacing.medium)
            .background(ShiftProColors.background)
            .navigationTitle("Log Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingLogBreak = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let switchToScheduleTab = Notification.Name("switchToScheduleTab")
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
