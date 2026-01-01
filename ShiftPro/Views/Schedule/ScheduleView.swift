import SwiftData
import SwiftUI

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Shift> { $0.deletedAt == nil }, sort: [SortDescriptor(\Shift.scheduledStart, order: .forward)])
    private var shifts: [Shift]
    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    @State private var selectedDate = Date()
    @State private var showingAddShift = false
    @State private var testShiftID: UUID?

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                calendarStrip

                VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                    Text(sectionTitle)
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    if shiftsForSelectedDate.isEmpty {
                        emptyState
                    } else {
                        ForEach(shiftsForSelectedDate, id: \.id) { shift in
                            NavigationLink {
                                ShiftDetailView(
                                    title: shift.pattern?.name ?? "Shift",
                                    timeRange: "\(shift.dateFormatted) • \(shift.timeRangeFormatted)",
                                    location: profile?.workplace ?? "Worksite",
                                    status: statusIndicator(for: shift),
                                    rateMultiplier: shift.rateMultiplier,
                                    notes: shift.notes
                                )
                            } label: {
                                ShiftCardView(
                                    title: shift.pattern?.name ?? "Shift",
                                    timeRange: shift.timeRangeFormatted,
                                    location: profile?.workplace ?? "Worksite",
                                    status: statusIndicator(for: shift),
                                    rateMultiplier: shift.rateMultiplier,
                                    notes: shift.notes
                                )
                            }
                            .buttonStyle(.plain)
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
                        navigateWeek(by: -1)
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
                        navigateWeek(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(ShiftProColors.accent)
                    }
                    .accessibilityLabel("Next week")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddShift = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ShiftProColors.accent)
                }
                .accessibilityLabel("Add shift")
                .accessibilityIdentifier(AccessibilityIdentifiers.scheduleAddShift)
            }
        }
        .sheet(isPresented: $showingAddShift) {
            ShiftFormView()
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

    private func navigateWeek(by weeks: Int) {
        withAnimation {
            if let newDate = calendar.date(byAdding: .weekOfYear, value: weeks, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "calendar.badge.plus",
            title: "No shifts scheduled",
            subtitle: "Tap below to add your first shift for this day",
            actionTitle: "Add Shift",
            action: { showingAddShift = true }
        )
    }

    private var calendarStrip: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text(currentMonthName)
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.inkSubtle)

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

    #if DEBUG
    private var testControls: some View {
        VStack(spacing: ShiftProSpacing.extraSmall) {
            Button("Seed Shift") {
                seedTestShift()
            }
            .accessibilityIdentifier("test.shift.seed")

            Button("Edit Shift") {
                editTestShift()
            }
            .accessibilityIdentifier("test.shift.edit")

            Button("Delete Shift") {
                deleteTestShift()
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
