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

                if viewMode == .week {
                    calendarStrip
                } else {
                    monthGrid
                }

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
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: ShiftProSpacing.small) {
                    Button {
                        navigate(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(ShiftProColors.accent)
                    }
                    .accessibilityLabel("Previous week")

                    Button {
                        withAnimation {
                            selectedDate = Date()
                        }
                    } label: {
                        Text("Today")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.accent)
                    }
                    .accessibilityLabel("Go to today")

                    Button {
                        navigate(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(ShiftProColors.accent)
                    }
                    .accessibilityLabel("Next week")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    pendingDate = selectedDate
                    showingDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .foregroundStyle(ShiftProColors.accent)
                }
                .accessibilityLabel("Jump to date")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingPatterns = true
                } label: {
                    Image(systemName: "repeat")
                        .foregroundStyle(ShiftProColors.accent)
                }
                .accessibilityLabel("Shift patterns")
                .accessibilityIdentifier("schedule.patterns")
            }

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
            VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                HStack {
                    if isInProgress {
                        Circle()
                            .fill(ShiftProColors.success)
                            .frame(width: 8, height: 8)
                    }
                    Text(isInProgress ? "In Progress" : (calendar.isDateInToday(selectedDate) ? "Today's Shift" : sectionTitle))
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(statusColor)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ShiftProColors.fog)
                }

                Text(shift.pattern?.name ?? "Shift")
                    .font(ShiftProTypography.title)
                    .foregroundStyle(.white)

                HStack(spacing: ShiftProSpacing.medium) {
                    Label(shift.timeRangeFormatted, systemImage: "clock")
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(.white.opacity(0.9))

                    if let location = shift.locationDisplay, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(ShiftProTypography.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                if shift.rateMultiplier > 1.0 {
                    Text(shift.rateLabel ?? String(format: "%.1fx", shift.rateMultiplier))
                        .font(ShiftProTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ShiftProColors.midnight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(ShiftProColors.warning))
                }
            }
            .padding(ShiftProSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        isInProgress
                            ? LinearGradient(colors: [ShiftProColors.success, ShiftProColors.success.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : ShiftProColors.heroGradient
                    )
            )
            .shadow(color: statusColor.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.primaryShiftBanner")
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
            Text(currentMonthName)
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.inkSubtle)

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

    private var calendarStrip: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack(spacing: ShiftProSpacing.small) {
                ForEach(weekDates, id: \.self) { date in
                    calendarDayCell(for: date)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = date
                            }
                        }
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.scheduleCalendarStrip)
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: ShiftProSpacing.extraSmall), count: 7)
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
                        monthDayCell(for: date)
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

    private func calendarDayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasShifts = shifts.contains { calendar.isDate($0.scheduledStart, inSameDayAs: date) }

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
            if hasShifts {
                Circle()
                    .fill(isSelected ? .white : ShiftProColors.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ShiftProSpacing.extraSmall)
        .background(
            isSelected ? ShiftProColors.accent : (isToday ? ShiftProColors.accentMuted : ShiftProColors.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isToday && !isSelected ? ShiftProColors.accent : .clear, lineWidth: 2)
        )
    }

    private func monthDayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasShifts = shifts.contains { calendar.isDate($0.scheduledStart, inSameDayAs: date) }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"

        return VStack(spacing: 4) {
            Text(dateFormatter.string(from: date))
                .font(ShiftProTypography.caption)
                .foregroundStyle(isSelected ? .white : ShiftProColors.ink)

            if hasShifts {
                Circle()
                    .fill(isSelected ? .white : ShiftProColors.accent)
                    .frame(width: 5, height: 5)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .padding(.vertical, 6)
        .background(isSelected ? ShiftProColors.accent : ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isToday && !isSelected ? ShiftProColors.accent : .clear, lineWidth: 2)
        )
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
