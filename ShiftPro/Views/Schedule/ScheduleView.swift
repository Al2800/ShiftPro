import SwiftData
import SwiftUI

struct ScheduleView: View {
    private enum ViewMode: String, CaseIterable, Identifiable {
        case week
        case month

        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    private enum DayViewMode: String, CaseIterable, Identifiable {
        case list
        case timeline

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .timeline: return "calendar.day.timeline.left"
            }
        }
        var label: String {
            switch self {
            case .list: return "List"
            case .timeline: return "Timeline"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<Shift> { $0.deletedAt == nil }, sort: [SortDescriptor(\Shift.scheduledStart, order: .forward)])
    private var shifts: [Shift]
    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    @State private var selectedDate = Date()
    @State private var showingAddShift = false
    @State private var testShiftID: UUID?
    @State private var viewMode: ViewMode = .week
    @State private var dayViewMode: DayViewMode = .list
    @State private var showingDatePicker = false
    @State private var pendingDate = Date()
    @AppStorage("showAddShiftAfterOnboarding") private var showAddShiftAfterOnboarding = false
    @State private var editingShift: Shift?
    @State private var showingPatterns = false
    @State private var selectedPatternForAdd: ShiftPattern?

    @Query(
        filter: #Predicate<ShiftPattern> { $0.deletedAt == nil && $0.isActive },
        sort: [SortDescriptor(\ShiftPattern.name, order: .forward)]
    )
    private var activePatterns: [ShiftPattern]

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            // Premium animated background
            AnimatedMeshBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                    // Calendar header and grid FIRST - this is the core feature
                    premiumCalendarHeader
                        .padding(.top, ShiftProSpacing.small)

                    premiumCalendarContent

                    // Shift banner below calendar
                    if let primaryShift = primaryShiftForSelectedDate {
                        premiumActiveShiftBanner(shift: primaryShift)
                            .padding(.top, ShiftProSpacing.small)
                    }

                    VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(ShiftProColors.accent)
                                Text(sectionTitle)
                                    .font(ShiftProTypography.headline)
                                    .foregroundStyle(ShiftProColors.ink)
                            }

                            Spacer()

                            // Day view mode toggle
                            Picker("View", selection: $dayViewMode) {
                                ForEach(DayViewMode.allCases) { mode in
                                    Image(systemName: mode.icon)
                                        .tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                            .accessibilityLabel("Day view mode")
                        }

                        if shiftsForSelectedDate.isEmpty {
                            premiumEmptyState
                        } else if dayViewMode == .timeline {
                            DayTimelineView(
                                shifts: shiftsForSelectedDate,
                                selectedDate: selectedDate,
                                onShiftTapped: { shift in
                                    editingShift = shift
                                }
                            )
                            .frame(height: 500)
                        } else {
                            ForEach(shiftsForSelectedDate, id: \.id) { shift in
                                SwipeableShiftRow(
                                    shift: shift,
                                    profile: profile,
                                    onEdit: { editingShift = shift },
                                    onDelete: { softDeleteShift(shift) },
                                    onOvertime: { addOvertimeHour(to: shift) }
                                ) {
                                    ShiftDetailView(
                                        title: shift.displayTitle,
                                        timeRange: "\(shift.dateFormatted) • \(shift.timeRangeFormatted)",
                                        location: shift.locationDisplay,
                                        status: statusIndicator(for: shift),
                                        rateMultiplier: shift.rateMultiplier,
                                        rateLabel: shift.rateLabel,
                                        notes: shift.notes
                                    )
                                }
                            }
                        }
                    }

                    #if DEBUG
                    if UITestSupport.isUITesting {
                        testControls
                    }
                    #endif
                }
                .padding(.horizontal, ShiftProSpacing.medium)
                .padding(.top, ShiftProSpacing.large)
                .padding(.bottom, ShiftProSpacing.tabBarPadding)
            }
        }
        .navigationTitle("Schedule")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !activePatterns.isEmpty {
                        Section("From Pattern") {
                            ForEach(activePatterns, id: \.id) { pattern in
                                Button {
                                    selectedPatternForAdd = pattern
                                } label: {
                                    Label(pattern.name, systemImage: "repeat")
                                }
                            }
                        }
                    }

                    Section("Patterns") {
                        Button {
                            showingPatterns = true
                        } label: {
                            Label("Pattern Library", systemImage: "repeat")
                        }
                    }

                    Button {
                        showingAddShift = true
                    } label: {
                        Label("Custom Shift", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ShiftProColors.accent)
                }
                .accessibilityLabel("Add shift")
                .accessibilityIdentifier(AccessibilityIdentifiers.scheduleAddShift)
            }
        }
        .sheet(isPresented: $showingAddShift) {
            ShiftFormView(prefillDate: selectedDate)
        }
        .sheet(item: $selectedPatternForAdd) { pattern in
            ShiftFormView(prefillPattern: pattern, prefillDate: selectedDate)
        }
        .sheet(item: $editingShift) { shift in
            ShiftFormView(shift: shift)
        }
        .navigationDestination(isPresented: $showingPatterns) {
            PatternLibraryView()
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Select date",
                        selection: $pendingDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                }
                .navigationTitle("Jump to Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            selectedDate = pendingDate
                            showingDatePicker = false
                        }
                    }
                }
            }
        }
        .onAppear {
            // Show add shift form if user chose to add their first shift after onboarding
            if showAddShiftAfterOnboarding {
                showAddShiftAfterOnboarding = false
                showingAddShift = true
            }
        }
    }

    private var profile: UserProfile? {
        profiles.first
    }

    private var weekDates: [Date] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    private var sectionTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    private var shiftsForSelectedDate: [Shift] {
        shifts.filter { shift in
            calendar.isDate(shift.scheduledStart, inSameDayAs: selectedDate)
        }
    }

    private func shifts(for date: Date) -> [Shift] {
        shifts
            .filter { calendar.isDate($0.scheduledStart, inSameDayAs: date) }
            .sorted(by: { $0.scheduledStart < $1.scheduledStart })
    }

    /// Primary shift for selected date - prioritizes in-progress, then upcoming, then any
    private var primaryShiftForSelectedDate: Shift? {
        let dayShifts = shiftsForSelectedDate
        // First, check for in-progress shift
        if let inProgress = dayShifts.first(where: { $0.status == .inProgress }) {
            return inProgress
        }
        // Then check for upcoming shift
        let now = Date()
        if let upcoming = dayShifts.first(where: { $0.scheduledStart > now && $0.status == .scheduled }) {
            return upcoming
        }
        // Otherwise return the first shift
        return dayShifts.first
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

    private func navigate(by value: Int) {
        let animation: Animation? = reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)
        withAnimation(animation) {
            let component: Calendar.Component = viewMode == .month ? .month : .weekOfYear
            if let newDate = calendar.date(byAdding: component, value: value, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }

    private func softDeleteShift(_ shift: Shift) {
        Task { @MainActor in
            let repository = ShiftRepository(context: modelContext)
            try? repository.softDelete(shift)
        }
    }

    private func addOvertimeHour(to shift: Shift) {
        Task { @MainActor in
            let updatedEnd = calendar.date(byAdding: .hour, value: 1, to: shift.scheduledEnd) ?? shift.scheduledEnd
            let paidMinutes = shift.paidMinutes > 0
                ? shift.paidMinutes
                : max(0, shift.effectiveDurationMinutes - shift.breakMinutes)
            let currentPremium = shift.premiumMinutes > 0
                ? shift.premiumMinutes
                : (shift.rateMultiplier > 1.0 ? paidMinutes : 0)
            shift.premiumMinutes = max(0, currentPremium + 60)

            let rate = max(shift.rateMultiplier, 1.5)
            let label = (shift.rateLabel?.isEmpty == false) ? shift.rateLabel : "Overtime"

            let manager = ShiftManager(context: modelContext)
            try? await manager.updateShift(
                shift,
                scheduledEnd: updatedEnd,
                rateMultiplier: rate,
                rateLabel: label
            )
        }
    }

    @ViewBuilder
    private func activeShiftBanner(shift: Shift) -> some View {
        let isInProgress = shift.status == .inProgress
        let statusColor = isInProgress ? ShiftProColors.success : ShiftProColors.accent
        let statusText = isInProgress ? "In Progress" : (calendar.isDateInToday(selectedDate) ? "Today's Shift" : sectionTitle)
        let estimatedPay = estimatedPayLabel(for: shift)

        NavigationLink {
            ShiftDetailView(
                title: shift.displayTitle,
                timeRange: "\(shift.dateFormatted) • \(shift.timeRangeFormatted)",
                location: shift.locationDisplay,
                status: statusIndicator(for: shift),
                rateMultiplier: shift.rateMultiplier,
                rateLabel: shift.rateLabel,
                notes: shift.notes
            )
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(statusColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                    HStack {
                        if isInProgress {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                        }
                        Text(statusText)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(statusColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }

                    Text(shift.displayTitle)
                        .font(ShiftProTypography.title)
                        .foregroundStyle(ShiftProColors.ink)

                    Text(timeDisplay(for: shift))
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    HStack(spacing: ShiftProSpacing.medium) {
                        if let location = shift.locationDisplay, !location.isEmpty {
                            Label(location, systemImage: "mappin")
                                .font(ShiftProTypography.subheadline)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }

                        if let estimatedPay {
                            Label("Est. \(estimatedPay)", systemImage: CurrencyFormatter.currencySymbolIconName)
                                .font(ShiftProTypography.subheadline)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                    }

                    if isInProgress {
                        ShiftProgressBar(
                            progress: shiftProgress(for: shift),
                            remaining: remainingTimeLabel(for: shift),
                            tint: statusColor
                        )
                    }
                }
                .padding(ShiftProSpacing.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ShiftProColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            .shadow(color: statusColor.opacity(0.12), radius: 18, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.primaryShiftBanner")
        .simultaneousGesture(
            TapGesture().onEnded {
                HapticManager.fire(.impactLight, enabled: !reduceMotion)
            }
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(
            reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8),
            value: primaryShiftForSelectedDate?.id
        )
    }

    private func timeDisplay(for shift: Shift) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: shift.effectiveStart)
        let end = formatter.string(from: shift.effectiveEnd)
        return "\(start) → \(end)"
    }

    private func estimatedPayLabel(for shift: Shift) -> String? {
        guard let baseRateCents = profile?.baseRateCents, baseRateCents > 0 else { return nil }
        let paidMinutes = shift.paidMinutes > 0 ? shift.paidMinutes : max(0, shift.effectiveDurationMinutes - shift.breakMinutes)
        guard paidMinutes > 0 else { return nil }
        let hours = Double(paidMinutes) / 60.0
        let pay = hours * Double(baseRateCents) / 100.0 * shift.rateMultiplier
        guard pay > 0 else { return nil }
        return currencyFormatter.string(from: NSNumber(value: pay))
    }

    private func shiftProgress(for shift: Shift) -> Double {
        let start = shift.effectiveStart
        let end = shift.effectiveEnd
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let elapsed = max(0, min(Date().timeIntervalSince(start), total))
        return elapsed / total
    }

    private func remainingTimeLabel(for shift: Shift) -> String {
        let remaining = max(0, shift.effectiveEnd.timeIntervalSince(Date()))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: remaining) ?? "0m"
    }

    private var currencyFormatter: NumberFormatter {
        CurrencyFormatter.shared
    }

    private struct ShiftProgressBar: View {
        let progress: Double
        let remaining: String
        let tint: Color

        var body: some View {
            VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(tint.opacity(0.15))
                            .frame(height: 6)
                        Capsule()
                            .fill(tint)
                            .frame(width: max(0, min(1, progress)) * proxy.size.width, height: 6)
                    }
                }
                .frame(height: 6)
                Text("\(remaining) remaining")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
    }

    // MARK: - Premium Empty State

    private var premiumEmptyState: some View {
        VStack(spacing: ShiftProSpacing.large) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(ShiftProColors.accent.opacity(0.6))

            Text("No shifts scheduled")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            Text(activePatterns.isEmpty
                ? "Tap below to add your first shift for this day"
                : "Add a shift from a pattern or create a custom one")
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.inkSubtle)
                .multilineTextAlignment(.center)

            VStack(spacing: ShiftProSpacing.small) {
                PremiumButton(
                    title: "Add Shift",
                    icon: "plus",
                    style: .primary
                ) {
                    showingAddShift = true
                }

                if let defaultPattern = activePatterns.first {
                    PremiumButton(
                        title: "Add from \(defaultPattern.name)",
                        icon: "repeat",
                        style: .ghost
                    ) {
                        selectedPatternForAdd = defaultPattern
                    }
                    .accessibilityIdentifier("schedule.addFromPattern")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ShiftProSpacing.extraLarge)
        .glassMorphism(intensity: 0.6, cornerRadius: 24)
    }

    private var emptyState: some View {
        premiumEmptyState
    }

    // MARK: - Premium Calendar Header

    private var premiumCalendarHeader: some View {
        VStack(spacing: ShiftProSpacing.small) {
            // Row 1: Month title with navigation
            HStack {
                Button {
                    navigate(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ShiftProColors.ink)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(ShiftProColors.surface)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                }
                .scalePress(0.92)

                Spacer()

                Button {
                    pendingDate = selectedDate
                    showingDatePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Text(currentMonthName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(ShiftProColors.ink)
                }
                .scalePress(0.96)
                .accessibilityLabel("Jump to date")

                Spacer()

                Button {
                    navigate(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ShiftProColors.ink)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(ShiftProColors.surface)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                }
                .scalePress(0.92)
            }

            // Row 2: Today button and view mode picker
            HStack {
                Button {
                    goToToday()
                } label: {
                    Text("Today")
                        .font(ShiftProTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(ShiftProColors.accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            Capsule()
                                .fill(ShiftProColors.accent.opacity(0.12))
                        )
                }
                .scalePress(0.96)

                Spacer()

                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .onChange(of: viewMode) { _, _ in
                    HapticManager.fire(.selection, enabled: !reduceMotion)
                }
            }
        }
    }

    private var calendarHeader: some View {
        premiumCalendarHeader
    }

    // MARK: - Premium Calendar Content

    private var premiumCalendarContent: some View {
        Group {
            if viewMode == .week {
                premiumCalendarStrip
            } else {
                premiumMonthGrid
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
            value: viewMode
        )
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    handleSwipe(value)
                }
        )
        .onTapGesture(count: 2) {
            goToToday()
        }
        .accessibilityAction(named: "Previous") {
            navigate(by: -1)
        }
        .accessibilityAction(named: "Next") {
            navigate(by: 1)
        }
        .accessibilityAction(named: "Today") {
            goToToday()
        }
    }

    private var calendarContent: some View {
        premiumCalendarContent
    }

    // MARK: - Compact Shift Banner

    @ViewBuilder
    private func premiumActiveShiftBanner(shift: Shift) -> some View {
        let isInProgress = shift.status == .inProgress
        let isOvertime = shift.rateMultiplier >= 1.3
        let overtimePay = isOvertime ? estimatedPayLabel(for: shift) : nil

        HStack(spacing: ShiftProSpacing.medium) {
            // Time icon
            Image(systemName: isInProgress ? "clock.badge.checkmark" : "clock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isInProgress ? ShiftProColors.success : ShiftProColors.accent)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill((isInProgress ? ShiftProColors.success : ShiftProColors.accent).opacity(0.15))
                )

            // Time display
            VStack(alignment: .leading, spacing: 2) {
                Text(shift.timeRangeFormatted)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(ShiftProColors.ink)

                if isInProgress {
                    Text("In Progress")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.success)
                }
            }

            Spacer()

            // Only show pay badge for overtime shifts
            if let pay = overtimePay {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(pay)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ShiftProColors.warning)
                    Text(String(format: "%.1fx", shift.rateMultiplier))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ShiftProColors.warning.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(ShiftProColors.warning.opacity(0.12))
                )
            }
        }
        .padding(.horizontal, ShiftProSpacing.medium)
        .padding(.vertical, ShiftProSpacing.small + 4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ShiftProColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isInProgress ? ShiftProColors.success.opacity(0.3) : Color.white.opacity(0.06),
                            lineWidth: isInProgress ? 1.5 : 1
                        )
                )
        )
        .accessibilityIdentifier("schedule.primaryShiftBanner")
        .transition(.asymmetric(
            insertion: .scale(scale: 0.98).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(
            reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8),
            value: primaryShiftForSelectedDate?.id
        )
    }

    // MARK: - Premium Calendar Strip

    private var premiumCalendarStrip: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: ShiftProSpacing.extraSmall), count: 7)

        return VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            // Weekday headers for week view too
            HStack(spacing: ShiftProSpacing.extraSmall) {
                ForEach(calendar.shortStandaloneWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(ShiftProTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            LazyVGrid(columns: columns, spacing: ShiftProSpacing.small) {
                ForEach(weekDates, id: \.self) { date in
                    premiumDayCell(for: date, shifts: shifts(for: date))
                        .onTapGesture {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) {
                                selectedDate = date
                            }
                            HapticManager.fire(.selection, enabled: !reduceMotion)
                        }
                }
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ShiftProColors.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .accessibilityIdentifier(AccessibilityIdentifiers.scheduleCalendarStrip)
    }

    private func premiumDayCell(for date: Date, shifts dayShifts: [Shift]) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasShifts = !dayShifts.isEmpty
        let firstShift = dayShifts.first

        // Get shift code and its color (uses rotation day's shift name for cycling patterns)
        let shiftCode = firstShift?.displayCode ?? "W"
        let shiftColor = firstShift?.displayColor ?? ShiftProColors.accent

        return VStack(spacing: 4) {
            // Today indicator - use a subtle dot above the date number
            // (weekday header row already provides day-of-week context)
            if isToday && !isSelected {
                Circle()
                    .fill(ShiftProColors.accent)
                    .frame(width: 6, height: 6)
                    .padding(.bottom, 2)
            } else {
                // Spacer to maintain consistent layout (header provides weekday)
                Color.clear.frame(height: 8)
            }

            // Date number
            Text(date.dayString)
                .font(.system(size: 16, weight: isToday ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : (isToday ? ShiftProColors.accent : ShiftProColors.ink))

            // Shift code badge - the star
            if hasShifts {
                Text(shiftCode)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? .white : shiftColor)
                    .frame(width: 32, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? .white.opacity(0.2) : shiftColor.opacity(0.15))
                    )

                if dayShifts.count > 1 {
                    Text("+\(dayShifts.count - 1)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : shiftColor.opacity(0.7))
                }
            } else {
                Color.clear.frame(height: 28)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? shiftColor : (isToday ? ShiftProColors.accent.opacity(0.12) : ShiftProColors.surface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isToday && !isSelected ? ShiftProColors.accent.opacity(0.5) : .clear, lineWidth: 2)
        )
        .shadow(color: isSelected ? ShiftProColors.accent.opacity(0.3) : (isToday ? ShiftProColors.accent.opacity(0.15) : Color.black.opacity(0.1)), radius: isSelected ? 12 : (isToday ? 8 : 4), x: 0, y: isSelected ? 6 : (isToday ? 4 : 2))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .contentShape(Rectangle())
        .accessibilityLabel(dayAccessibilityLabel(for: date, shifts: dayShifts))
    }

    // MARK: - Premium Month Grid

    private var premiumMonthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: ShiftProSpacing.extraSmall), count: 7)
        let shiftsByDay = Dictionary(grouping: shifts) { shift in
            calendar.startOfDay(for: shift.scheduledStart)
        }

        return VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack(spacing: ShiftProSpacing.extraSmall) {
                ForEach(calendar.shortStandaloneWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(ShiftProTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            LazyVGrid(columns: columns, spacing: ShiftProSpacing.extraSmall) {
                ForEach(monthDates.indices, id: \.self) { index in
                    if let date = monthDates[index] {
                        let dayKey = calendar.startOfDay(for: date)
                        let dayShifts = shiftsByDay[dayKey] ?? []
                        premiumMonthDayCell(for: date, shifts: dayShifts)
                            .onTapGesture {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) {
                                    selectedDate = date
                                }
                                HapticManager.fire(.selection, enabled: !reduceMotion)
                            }
                    } else {
                        Color.clear
                            .frame(height: 54)
                    }
                }
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ShiftProColors.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func premiumMonthDayCell(for date: Date, shifts dayShifts: [Shift]) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasShifts = !dayShifts.isEmpty
        let firstShift = dayShifts.first

        // Get shift code and its color (uses rotation day's shift name for cycling patterns)
        let shiftCode = firstShift?.displayCode ?? "W"
        let shiftColor = firstShift?.displayColor ?? ShiftProColors.inkSubtle

        return VStack(spacing: 2) {
            // Date number - bold for today
            Text(date.dayString)
                .font(.system(size: 11, weight: isToday ? .bold : .medium, design: .rounded))
                .foregroundStyle(
                    isSelected ? .white.opacity(0.9) :
                    (isToday ? ShiftProColors.accent : ShiftProColors.inkSubtle)
                )

            // Shift code letter - the hero element
            if hasShifts {
                Text(shiftCode)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? .white : shiftColor)

                // Multiple shifts indicator
                if dayShifts.count > 1 {
                    Text("+\(dayShifts.count - 1)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : shiftColor.opacity(0.6))
                }
            } else if isToday && !isSelected {
                // Today indicator dot when no shifts
                Circle()
                    .fill(ShiftProColors.accent)
                    .frame(width: 6, height: 6)
            } else {
                // Empty day - subtle dot
                Text("·")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(ShiftProColors.inkSubtle.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hasShifts ? shiftColor : ShiftProColors.accent)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ShiftProColors.accent.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(ShiftProColors.accent.opacity(0.5), lineWidth: 2)
                        )
                }
            }
        )
        .contentShape(Rectangle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel(dayAccessibilityLabel(for: date, shifts: dayShifts))
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        guard abs(horizontal) > abs(vertical), abs(horizontal) > 40 else { return }
        navigate(by: horizontal < 0 ? 1 : -1)
    }

    private func goToToday() {
        let animation: Animation? = reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)
        withAnimation(animation) {
            selectedDate = Date()
        }
        HapticManager.fire(.selection, enabled: !reduceMotion)
    }

    private var calendarStrip: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: ShiftProSpacing.extraSmall), count: 7)

        return LazyVGrid(columns: columns, spacing: ShiftProSpacing.small) {
            ForEach(weekDates, id: \.self) { date in
                calendarDayCell(for: date, shifts: shifts(for: date))
                    .onTapGesture {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedDate = date
                        }
                        HapticManager.fire(.selection, enabled: !reduceMotion)
                    }
                    .shiftProHoverLift()
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.scheduleCalendarStrip)
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: ShiftProSpacing.extraSmall), count: 7)
        let shiftsByDay = Dictionary(grouping: shifts) { shift in
            calendar.startOfDay(for: shift.scheduledStart)
        }

        return VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack(spacing: ShiftProSpacing.extraSmall) {
                ForEach(calendar.shortStandaloneWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: ShiftProSpacing.extraSmall) {
                ForEach(monthDates.indices, id: \.self) { index in
                    if let date = monthDates[index] {
                        let dayKey = calendar.startOfDay(for: date)
                        let dayShifts = shiftsByDay[dayKey] ?? []
                        monthDayCell(for: date, shifts: dayShifts)
                            .onTapGesture {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) {
                                    selectedDate = date
                                }
                                HapticManager.fire(.selection, enabled: !reduceMotion)
                            }
                            .shiftProHoverLift()
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
        }
    }

    private var monthDates: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let daysRange = calendar.range(of: .day, in: .month, for: selectedDate) else {
            return []
        }

        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var dates: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in daysRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                dates.append(date)
            }
        }
        return dates
    }

    private func calendarDayCell(for date: Date, shifts dayShifts: [Shift]) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasShifts = !dayShifts.isEmpty
        let previewShift = dayShifts.first

        return VStack(spacing: ShiftProSpacing.extraExtraSmall) {
            Text(date.shortWeekdayString)
                .font(ShiftProTypography.caption)
                .foregroundStyle(isSelected ? .white : ShiftProColors.inkSubtle)
            Text(date.dayString)
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(isSelected ? .white : ShiftProColors.ink)

            if let previewShift {
                ShiftPreviewPill(shift: previewShift, compact: true)
            }

            if dayShifts.count > 1 {
                Text("+\(dayShifts.count - 1)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : ShiftProColors.accent)
            } else if hasShifts {
                Circle()
                    .fill(isSelected ? .white : ShiftProColors.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ShiftProSpacing.small)
        .padding(.horizontal, ShiftProSpacing.extraExtraSmall)
        .background(
            isSelected ? ShiftProColors.accent : (isToday ? ShiftProColors.accentMuted : ShiftProColors.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isToday && !isSelected ? ShiftProColors.accent : .clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .accessibilityLabel(dayAccessibilityLabel(for: date, shifts: dayShifts))
    }

    private func dayAccessibilityLabel(for date: Date, shifts dayShifts: [Shift]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let base = formatter.string(from: date)
        guard !dayShifts.isEmpty else { return base }
        if dayShifts.count == 1, let shift = dayShifts.first {
            return "\(base), \(shift.timeRangeFormatted)"
        }
        return "\(base), \(dayShifts.count) shifts"
    }

    private func monthDayCell(for date: Date, shifts dayShifts: [Shift]) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasShifts = !dayShifts.isEmpty

        let barColor = isSelected ? Color.white : shiftStatusColor(for: dayShifts)
        let firstShift = dayShifts.first

        return VStack(spacing: 2) {
            Text(date.dayString)
                .font(ShiftProTypography.caption)
                .foregroundStyle(isSelected ? .white : ShiftProColors.ink)

            if hasShifts, let shift = firstShift {
                // Show shift time icon based on time of day
                Image(systemName: shiftTimeIcon(for: shift))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(barColor)

                // Show shift count or time
                if dayShifts.count > 1 {
                    Text("\(dayShifts.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : ShiftProColors.accent)
                } else {
                    Text(shortTimeLabel(for: shift))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : ShiftProColors.inkSubtle)
                }
            } else {
                Color.clear
                    .frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(.vertical, ShiftProSpacing.extraSmall)
        .background(isSelected ? ShiftProColors.accent : ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isToday && !isSelected ? ShiftProColors.accent : .clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .accessibilityLabel(dayAccessibilityLabel(for: date, shifts: dayShifts))
    }

    /// Returns an icon based on shift start time (morning/afternoon/evening/night)
    private func shiftTimeIcon(for shift: Shift) -> String {
        let hour = calendar.component(.hour, from: shift.scheduledStart)
        switch hour {
        case 5..<12:
            return "sunrise.fill"
        case 12..<17:
            return "sun.max.fill"
        case 17..<21:
            return "sunset.fill"
        default:
            return "moon.fill"
        }
    }

    /// Returns a short time label like "9a" or "2p"
    private func shortTimeLabel(for shift: Shift) -> String {
        let hour = calendar.component(.hour, from: shift.scheduledStart)
        let isPM = hour >= 12
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour)\(isPM ? "p" : "a")"
    }

    /// Returns the color for a shift - prioritizes pattern color, then falls back to green default
    private func shiftColor(for shift: Shift) -> Color {
        // Use pattern's custom color if available
        if let pattern = shift.pattern, !pattern.colorHex.isEmpty {
            return Color(hex: pattern.colorHex) ?? ShiftProColors.success
        }
        // Default to green for shift days (user can customize via pattern)
        switch shift.status {
        case .inProgress: return ShiftProColors.success
        case .scheduled: return ShiftProColors.success  // Green default makes calendar pop
        case .cancelled: return ShiftProColors.danger
        case .completed: return ShiftProColors.success.opacity(0.7)
        }
    }

    private func shiftStatusColor(for dayShifts: [Shift]) -> Color {
        // Use first shift's pattern color if available
        if let firstShift = dayShifts.first {
            return shiftColor(for: firstShift)
        }
        return ShiftProColors.inkSubtle
    }


    #if DEBUG
    private var testControls: some View {
        VStack(spacing: ShiftProSpacing.extraSmall) {
            Button("Seed Shift") {
                Task { @MainActor in seedTestShift() }
            }
            .accessibilityIdentifier("test.shift.seed")

            Button("Edit Shift") {
                Task { @MainActor in editTestShift() }
            }
            .accessibilityIdentifier("test.shift.edit")

            Button("Delete Shift") {
                Task { @MainActor in deleteTestShift() }
            }
            .accessibilityIdentifier("test.shift.delete")
        }
        .font(ShiftProTypography.caption)
        .foregroundStyle(ShiftProColors.accent)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, ShiftProSpacing.medium)
    }

    @MainActor
    private func seedTestShift() {
        let repository = ShiftRepository(context: modelContext)
        let profileRepository = UserProfileRepository(context: modelContext)
        let calendar = Calendar.current

        for shift in shifts {
            try? repository.softDelete(shift)
        }

        guard let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()),
              let end = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) else {
            return
        }

        let owner = try? profileRepository.ensurePrimary()
        let shift = Shift(
            scheduledStart: start,
            scheduledEnd: end,
            breakMinutes: 30,
            notes: "UI Test Shift",
            owner: owner
        )
        try? repository.add(shift)
        testShiftID = shift.id
    }

    @MainActor
    private func editTestShift() {
        let repository = ShiftRepository(context: modelContext)
        let calendar = Calendar.current

        let shift: Shift?
        if let testShiftID {
            shift = try? repository.fetch(id: testShiftID)
        } else {
            shift = shifts.first
        }

        guard let shift else { return }

        if let updatedEnd = calendar.date(byAdding: .hour, value: 2, to: shift.scheduledEnd) {
            shift.scheduledEnd = updatedEnd
        }
        shift.notes = "UI Test Shift (Edited)"
        try? repository.update(shift)
        testShiftID = shift.id
    }

    @MainActor
    private func deleteTestShift() {
        let repository = ShiftRepository(context: modelContext)

        let shift: Shift?
        if let testShiftID {
            shift = try? repository.fetch(id: testShiftID)
        } else {
            shift = shifts.first
        }

        guard let shift else { return }
        try? repository.softDelete(shift)
        testShiftID = nil
    }
    #endif
}

// MARK: - Swipeable Shift Row

private struct SwipeableShiftRow<Destination: View>: View {
    let shift: Shift
    let profile: UserProfile?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onOvertime: () -> Void
    @ViewBuilder let destination: () -> Destination

    @State private var offset: CGFloat = 0
    @State private var showingActions = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let actionWidth: CGFloat = 80
    private let deleteThreshold: CGFloat = -160

    var body: some View {
        ZStack(alignment: .trailing) {
            // Action buttons revealed on swipe
            HStack(spacing: 0) {
                Spacer()

                Button(action: onEdit) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth, height: 80)
                    .background(ShiftProColors.accent)
                }

                Button(action: onDelete) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Delete")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth, height: 80)
                    .background(ShiftProColors.danger)
                }
            }

            // Main content
            NavigationLink(destination: destination) {
                PremiumShiftRow(
                    shift: shift,
                    profile: profile,
                    onTap: nil
                )
            }
            .buttonStyle(.plain)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        if translation < 0 {
                            offset = translation
                        } else if showingActions {
                            offset = -actionWidth * 2 + translation
                        }
                    }
                    .onEnded { value in
                        let animation: Animation = reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.7)
                        withAnimation(animation) {
                            if value.translation.width < deleteThreshold {
                                // Full swipe to delete
                                onDelete()
                                offset = 0
                                showingActions = false
                            } else if value.translation.width < -actionWidth {
                                // Show actions
                                offset = -actionWidth * 2
                                showingActions = true
                            } else {
                                // Reset
                                offset = 0
                                showingActions = false
                            }
                        }
                    }
            )
            .contextMenu {
                Button(action: onOvertime) {
                    Label("Add 1h Overtime", systemImage: "clock.badge.plus")
                }

                Button(action: onEdit) {
                    Label("Edit Shift", systemImage: "pencil")
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete Shift", systemImage: "trash")
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        ScheduleView()
    }
}
