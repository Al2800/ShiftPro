import EventKit
import SwiftData
import SwiftUI

/// Shows calendar sync conflicts and allows user resolution
struct CalendarConflictsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<CalendarEvent> { $0.syncStateRaw == CalendarSyncState.conflictDetected.rawValue },
        sort: [SortDescriptor(\CalendarEvent.lastSyncDate, order: .reverse)]
    )
    private var conflicts: [CalendarEvent]

    @State private var isResolving = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var eventDetails: [UUID: EventDetails] = [:]

    private let eventStore = EKEventStore()

    var body: some View {
        List {
            if conflicts.isEmpty {
                Section {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "No Conflicts",
                        subtitle: "Your shifts and calendar are in sync"
                    )
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    Text("These shifts have been modified in both ShiftPro and your calendar since the last sync. Choose which version to keep.")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
                .listRowBackground(Color.clear)

                ForEach(conflicts, id: \.id) { conflict in
                    if let shift = conflict.shift {
                        conflictRow(conflict: conflict, shift: shift)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sync Conflicts")
        .task {
            await loadEventDetails()
        }
        .disabled(isResolving)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }

    // MARK: - Conflict Row

    private func conflictRow(conflict: CalendarEvent, shift: Shift) -> some View {
        Section {
            VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                // Shift version
                VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(ShiftProColors.accent)
                        Text("ShiftPro Version")
                            .font(ShiftProTypography.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shift.dateFormatted)
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                            Text(shift.timeRangeFormatted)
                                .font(ShiftProTypography.body)
                        }
                        Spacer()
                        Text("Updated \(shift.updatedAt.relativeFormatted)")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
                .padding(ShiftProSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ShiftProColors.accent.opacity(0.1))
                )

                // Calendar version
                VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(ShiftProColors.success)
                        Text("Calendar Version")
                            .font(ShiftProTypography.subheadline)
                            .fontWeight(.medium)
                    }

                    if let details = eventDetails[conflict.id] {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(details.dateFormatted)
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                                Text(details.timeRangeFormatted)
                                    .font(ShiftProTypography.body)
                            }
                            Spacer()
                            if let modified = details.lastModified {
                                Text("Updated \(modified.relativeFormatted)")
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                            }
                        }
                    } else {
                        Text("Unable to load calendar event")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.warning)
                    }
                }
                .padding(ShiftProSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ShiftProColors.success.opacity(0.1))
                )

                // Resolution buttons
                HStack(spacing: ShiftProSpacing.small) {
                    Button {
                        Task { await resolveConflict(conflict, keepShift: true) }
                    } label: {
                        HStack {
                            Image(systemName: "clock.badge.checkmark")
                            Text("Keep Shift")
                        }
                        .font(ShiftProTypography.callout)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ShiftProSpacing.small)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ShiftProColors.accent)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("conflict.keepShift.\(conflict.id)")

                    Button {
                        Task { await resolveConflict(conflict, keepShift: false) }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Use Calendar")
                        }
                        .font(ShiftProTypography.callout)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ShiftProSpacing.small)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ShiftProColors.success)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("conflict.useCalendar.\(conflict.id)")
                }
            }
            .padding(.vertical, ShiftProSpacing.small)
        } header: {
            if let pattern = shift.pattern {
                Text(pattern.name)
            } else {
                Text("Shift")
            }
        }
    }

    // MARK: - Event Loading

    private func loadEventDetails() async {
        for conflict in conflicts {
            guard !conflict.eventIdentifier.isEmpty else { continue }
            if let event = eventStore.event(withIdentifier: conflict.eventIdentifier) {
                let details = EventDetails(
                    startDate: event.startDate,
                    endDate: event.endDate,
                    lastModified: event.lastModifiedDate
                )
                eventDetails[conflict.id] = details
            }
        }
    }

    // MARK: - Resolution

    private func resolveConflict(_ conflict: CalendarEvent, keepShift: Bool) async {
        guard let shift = conflict.shift else { return }

        isResolving = true
        defer { isResolving = false }

        do {
            if keepShift {
                // Push shift data to calendar
                try await updateCalendarFromShift(conflict: conflict, shift: shift)
            } else {
                // Pull calendar data to shift
                try await updateShiftFromCalendar(conflict: conflict, shift: shift)
            }

            conflict.markSynced()
            try modelContext.save()
            eventDetails.removeValue(forKey: conflict.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func updateCalendarFromShift(conflict: CalendarEvent, shift: Shift) async throws {
        guard !conflict.eventIdentifier.isEmpty,
              let event = eventStore.event(withIdentifier: conflict.eventIdentifier) else {
            throw DataError.notFound
        }

        let settings = CalendarSyncSettings.load()
        guard let calendarId = UserDefaults.standard.string(forKey: "ShiftPro.CalendarIdentifier"),
              let calendar = eventStore.calendar(withIdentifier: calendarId) else {
            throw DataError.invalidState("Calendar not configured")
        }

        EventMapper.apply(
            shift: shift,
            to: event,
            calendar: calendar,
            includeAlarms: settings.includeAlarms,
            alarmOffsetMinutes: settings.alarmOffsetMinutes
        )

        try eventStore.save(event, span: .thisEvent)
        conflict.lastEventModified = event.lastModifiedDate
    }

    private func updateShiftFromCalendar(conflict: CalendarEvent, shift: Shift) async throws {
        guard !conflict.eventIdentifier.isEmpty,
              let event = eventStore.event(withIdentifier: conflict.eventIdentifier) else {
            throw DataError.notFound
        }

        EventMapper.updateShift(shift, from: event)

        let calculator = HoursCalculator()
        calculator.updateCalculatedFields(for: shift)

        conflict.lastEventModified = event.lastModifiedDate
    }
}

// MARK: - Event Details

private struct EventDetails {
    let startDate: Date
    let endDate: Date
    let lastModified: Date?

    var dateFormatted: String {
        startDate.formatted(date: .abbreviated, time: .omitted)
    }

    var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

#Preview {
    NavigationStack {
        CalendarConflictsView()
    }
}
