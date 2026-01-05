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
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                // Prominent shift banner at top
                if let primaryShift = primaryShiftForSelectedDate {
                    activeShiftBanner(shift: primaryShift)
                }

                calendarHeader

                calendarContent

                VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                    HStack {
                        Text(sectionTitle)
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(ShiftProColors.ink)

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
                        emptyState
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
                            NavigationLink {
                                ShiftDetailView(
                                    title: shift.pattern?.name ?? "Shift",
                                    timeRange: "\(shift.dateFormatted) • \(shift.timeRangeFormatted)",
                                    location: shift.locationDisplay,
                                    status: statusIndicator(for: shift),
                                    rateMultiplier: shift.rateMultiplier,
                                    rateLabel: shift.rateLabel,
                                    notes: shift.notes
                                )
                            } label: {
                                ShiftCardView(
                                    title: shift.pattern?.name ?? "Shift",
                                    timeRange: shift.timeRangeFormatted,
                                    location: shift.locationDisplay,
                                    status: statusIndicator(for: shift),
                                    rateMultiplier: shift.rateMultiplier,
                                    notes: shift.notes
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    editingShift = shift
                                } label: {
                                    Label("Edit Shift", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    softDeleteShift(shift)
                                } label: {
                                    Label("Delete Shift", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    softDeleteShift(shift)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    editingShift = shift
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(ShiftProColors.accent)
                            }
                            .accessibilityAction(named: "Edit") {
                                editingShift = shift
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
            .padding(.vertical, ShiftProSpacing.large)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
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
        withAnimation {
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

    @ViewBuilder
    private func activeShiftBanner(shift: Shift) -> some View {
        let isInProgress = shift.status == .inProgress
        let statusColor = isInProgress ? ShiftProColors.success : ShiftProColors.accent
        let statusText = isInProgress ? "In Progress" : (calendar.isDateInToday(selectedDate) ? "Today's Shift" : sectionTitle)
        let estimatedPay = estimatedPayLabel(for: shift)

        NavigationLink {
            ShiftDetailView(
                title: shift.pattern?.name ?? "Shift",
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

                    Text(shift.pattern?.name ?? "Shift")
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
                            Label("Est. \(estimatedPay)", systemImage: "dollarsign.circle")
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
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: primaryShiftForSelectedDate?.id)
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if let code = Locale.current.currency?.identifier {
            formatter.currencyCode = code
        }
        return formatter
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

    private var emptyState: some View {
        VStack(spacing: ShiftProSpacing.medium) {
            EmptyStateView(
                icon: "calendar.badge.plus",
                title: "No shifts scheduled",
                subtitle: activePatterns.isEmpty
                    ? "Tap below to add your first shift for this day"
                    : "Add a shift from a pattern or create a custom one",
                actionTitle: "Add Shift",
                action: { showingAddShift = true }
            )

            if let defaultPattern = activePatterns.first {
                Button {
                    selectedPatternForAdd = defaultPattern
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "repeat")
                            .font(.system(size: 12))
                        Text("Add from \(defaultPattern.name)")
                            .font(ShiftProTypography.subheadline)
                    }
                    .foregroundStyle(ShiftProColors.accent)
                }
                .accessibilityIdentifier("schedule.addFromPattern")
            }
        }
    }

    private var calendarHeader: some View {
        HStack(spacing: ShiftProSpacing.small) {
            Button {
                pendingDate = selectedDate
                showingDatePicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(currentMonthName)
                        .font(ShiftProTypography.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(ShiftProColors.inkSubtle)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(ShiftProColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Jump to date")

            Spacer()

            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
    }

    private var calendarContent: some View {
        Group {
            if viewMode == .week {
                calendarStrip
            } else {
                monthGrid
            }
        }
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

    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        guard abs(horizontal) > abs(vertical), abs(horizontal) > 40 else { return }
        navigate(by: horizontal < 0 ? 1 : -1)
    }

    private func goToToday() {
        withAnimation {
            selectedDate = Date()
        }
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
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = date
                                }
                            }
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

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"

        return VStack(spacing: ShiftProSpacing.extraExtraSmall) {
            Text(dayFormatter.string(from: date))
                .font(ShiftProTypography.caption)
                .foregroundStyle(isSelected ? .white : ShiftProColors.inkSubtle)
            Text(dateFormatter.string(from: date))
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"

        let barScale = shiftBarScale(for: dayShifts.count)
        let barHeight = shiftBarHeight(for: dayShifts.count)
        let barColor = isSelected ? Color.white : shiftStatusColor(for: dayShifts)

        return VStack(spacing: ShiftProSpacing.extraExtraSmall) {
            Text(dateFormatter.string(from: date))
                .font(ShiftProTypography.caption)
                .foregroundStyle(isSelected ? .white : ShiftProColors.ink)

            if hasShifts {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(barColor)
                    .frame(height: barHeight)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: barScale, y: 1, anchor: .center)
                    .padding(.horizontal, 6)
            } else {
                Color.clear
                    .frame(height: barHeight)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42)
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

    private func shiftStatusColor(for dayShifts: [Shift]) -> Color {
        if dayShifts.contains(where: { $0.status == .inProgress }) {
            return ShiftProColors.success
        }
        if dayShifts.contains(where: { $0.status == .scheduled }) {
            return ShiftProColors.accent
        }
        if dayShifts.contains(where: { $0.status == .cancelled }) {
            return ShiftProColors.danger
        }
        return ShiftProColors.inkSubtle
    }

    private func shiftBarScale(for count: Int) -> CGFloat {
        switch count {
        case 0:
            return 0
        case 1:
            return 0.6
        case 2:
            return 0.8
        default:
            return 1.0
        }
    }

    private func shiftBarHeight(for count: Int) -> CGFloat {
        switch count {
        case 2:
            return 4
        case 3...:
            return 5
        default:
            return 3
        }
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

#Preview {
    NavigationStack {
        ScheduleView()
    }
}
