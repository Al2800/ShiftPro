import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var animateIn = false
    @State private var showingAddShift = false
    @State private var showingLogBreak = false
    @State private var breakMinutesToLog: Int = 15
    @State private var isProcessingAction = false
    @State private var actionError: String?
    @State private var showingActionError = false
    @Query(filter: #Predicate<Shift> { $0.deletedAt == nil }, sort: [SortDescriptor(\Shift.scheduledStart, order: .forward)])
    private var shifts: [Shift]
    @Query(filter: #Predicate<PayPeriod> { $0.deletedAt == nil }, sort: [SortDescriptor(\PayPeriod.startDate, order: .reverse)])
    private var payPeriods: [PayPeriod]
    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    private let calculator = PayPeriodCalculator()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                heroCard
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 16)
                    .animation(AnimationManager.shared.animation(for: .slow), value: animateIn)

                VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                    Text("Upcoming")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    if dashboardShifts.isEmpty {
                        EmptyStateView(
                            icon: "clock.badge.questionmark",
                            title: "No upcoming shifts",
                            subtitle: "Your next scheduled shift will appear here",
                            actionTitle: "Add Shift",
                            action: { showingAddShift = true }
                        )
                    } else {
                        ForEach(dashboardShifts, id: \.id) { shift in
                            ShiftCardView(
                                title: shift.pattern?.name ?? "Shift",
                                timeRange: "\(shift.dateFormatted) • \(shift.timeRangeFormatted)",
                                location: shift.owner?.workplace ?? "Worksite",
                                status: statusIndicator(for: shift),
                                rateMultiplier: shift.rateMultiplier,
                                notes: shift.notes,
                                accessibilityIdentifier: shiftAccessibilityIdentifier(for: shift)
                            )
                        }
                    }
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 12)
                .animation(AnimationManager.shared.animation(for: .standard), value: animateIn)

                VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                    Text("Hours")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    if periodShifts.isEmpty {
                        EmptyStateView(
                            icon: "chart.bar.xaxis",
                            title: "No hours this period",
                            subtitle: "Complete a shift to track your hours"
                        )
                    } else {
                        HoursDisplay(
                            totalHours: summary.totalHours,
                            regularHours: summary.regularHours,
                            overtimeHours: summary.premiumHours
                        )
                    }
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 10)
                .animation(AnimationManager.shared.animation(for: .standard), value: animateIn)

                quickActions
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 8)
                    .animation(AnimationManager.shared.animation(for: .standard), value: animateIn)
            }
            .padding(.horizontal, ShiftProSpacing.medium)
            .padding(.vertical, ShiftProSpacing.large)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(ShiftProColors.accent)
                }
                .accessibilityLabel("Notifications")
            }
        }
        .onAppear {
            guard !animateIn else { return }
            animateIn = true
        }
        .sheet(isPresented: $showingAddShift) {
            ShiftFormView()
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

    private var currentShift: Shift? {
        shifts.first { $0.status == .inProgress }
    }

    private var upcomingShifts: [Shift] {
        let now = Date()
        return shifts.filter { shift in
            shift.scheduledStart >= now && shift.status != .cancelled
        }
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
        if currentShift != nil {
            return "On shift now"
        }
        if upcomingShifts.first != nil {
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

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(ShiftProColors.heroGradient)
                .frame(maxWidth: .infinity)
                .frame(height: 180)

            VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                Text(heroTitle)
                    .font(ShiftProTypography.title)
                    .foregroundStyle(.white)

                Text(heroSubtitle)
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                QuickActionButton(
                    title: heroActionTitle,
                    systemImage: heroActionIcon,
                    action: { Task { await handleStartEndShift() } },
                    accessibilityIdentifier: AccessibilityIdentifiers.dashboardStartShift
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(ShiftProSpacing.large)
        }
        .shadow(color: ShiftProColors.accent.opacity(0.25), radius: 18, x: 0, y: 12)
        .accessibilityIdentifier(AccessibilityIdentifiers.dashboardHeroCard)
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

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            Text("Quick Actions")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            HStack(spacing: ShiftProSpacing.small) {
                QuickActionButton(
                    title: "Log Break",
                    systemImage: "cup.and.saucer.fill",
                    action: { handleLogBreak() },
                    accessibilityIdentifier: AccessibilityIdentifiers.dashboardLogBreak
                )
                .disabled(currentShift == nil)
                .opacity(currentShift == nil ? 0.5 : 1.0)

                QuickActionButton(
                    title: "Add Shift",
                    systemImage: "plus",
                    action: { showingAddShift = true },
                    accessibilityIdentifier: AccessibilityIdentifiers.dashboardAddShift
                )
            }
        }
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
        guard currentShift != nil else { return }
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
            Form {
                Section("Break Duration") {
                    Picker("Minutes", selection: $breakMinutesToLog) {
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("45 minutes").tag(45)
                        Text("60 minutes").tag(60)
                    }
                    .pickerStyle(.wheel)
                }

                if let shift = currentShift {
                    Section("Current Break") {
                        HStack {
                            Text("Already logged")
                            Spacer()
                            Text("\(shift.breakMinutes) min")
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                        HStack {
                            Text("After logging")
                            Spacer()
                            Text("\(shift.breakMinutes + breakMinutesToLog) min")
                                .foregroundStyle(ShiftProColors.accent)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle("Log Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingLogBreak = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        Task { await logBreakMinutes() }
                    }
                    .disabled(isProcessingAction)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
