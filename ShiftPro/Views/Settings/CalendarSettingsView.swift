import EventKit
import SwiftData
import SwiftUI

struct CalendarSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var permissionManager = PermissionManager()
    @Query(filter: #Predicate<CalendarEvent> { $0.syncStateRaw == CalendarSyncState.conflictDetected.rawValue })
    private var conflicts: [CalendarEvent]
    @State private var settings = CalendarSyncSettings.load()
    @State private var showTwoWaySyncConfirmation = false
    @State private var calendars: [EKCalendar] = []
    @State private var selectedCalendarIdentifier: String = ""
    @State private var isSyncing = false
    @State private var showSyncError = false
    @State private var syncErrorMessage: String?

    private let eventStore = EKEventStore()
    private let calendarIdentifierKey = "ShiftPro.CalendarIdentifier"

    private var isAuthorized: Bool {
        switch settings.mode {
        case .twoWay:
            return permissionManager.calendarStatus == .authorized
        case .exportOnly:
            return permissionManager.calendarStatus == .authorized || permissionManager.calendarStatus == .writeOnly
        }
    }

    private var canSyncNow: Bool {
        settings.isEnabled && isAuthorized && !isSyncing
    }

    var body: some View {
        List {
            if !conflicts.isEmpty {
                Section {
                    NavigationLink {
                        CalendarConflictsView()
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ShiftProColors.warning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(conflicts.count) Sync Conflict\(conflicts.count == 1 ? "" : "s")")
                                    .font(ShiftProTypography.body)
                                Text("Resolve to continue syncing")
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                            }
                            Spacer()
                        }
                    }
                    .accessibilityIdentifier("calendarSettings.conflicts")
                } header: {
                    Text("Attention Required")
                }
            }

            Section {
                HStack {
                    Text("Calendar Access")
                    Spacer()
                    Text(permissionLevelDisplay)
                        .foregroundStyle(statusColor)
                        .font(ShiftProTypography.caption)
                }

                if permissionManager.calendarStatus == .writeOnly {
                    HStack(spacing: ShiftProSpacing.small) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(ShiftProColors.warning)
                        Text("Write-only access allows exporting shifts to your calendar, but two-way sync requires full access.")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }

                if !isAuthorized || permissionManager.calendarStatus == .writeOnly {
                    if permissionManager.calendarStatus == .notDetermined {
                        Button("Request Access") {
                            Task {
                                await permissionManager.requestCalendarAccess()
                                await permissionManager.refreshStatuses()
                                loadCalendars()
                            }
                        }
                    } else {
                        Button {
                            openSystemSettings()
                        } label: {
                            HStack {
                                Text(permissionManager.calendarStatus == .writeOnly ? "Upgrade to Full Access" : "Open Settings")
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 12))
                            }
                        }
                        .foregroundStyle(ShiftProColors.accent)
                    }
                }

                HStack {
                    Text("Sync Status")
                    Spacer()
                    Text(settings.isEnabled ? "Enabled" : "Off")
                        .foregroundStyle(settings.isEnabled ? ShiftProColors.success : ShiftProColors.inkSubtle)
                        .font(ShiftProTypography.caption)
                }

                HStack {
                    Text("Calendar")
                    Spacer()
                    Text(selectedCalendarTitle)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }

                HStack {
                    Text("Last Synced")
                    Spacer()
                    if let lastSync = settings.lastSyncedAt {
                        Text(lastSync, style: .relative)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    } else {
                        Text("Never")
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }

                Button(action: { Task { await performSync() } }) {
                    HStack {
                        Text("Sync Now")
                        Spacer()
                        if isSyncing {
                            ProgressView()
                        }
                    }
                }
                .disabled(!canSyncNow)
            } header: {
                Text("Status")
            } footer: {
                if !settings.isEnabled {
                    Text("Enable calendar sync below to run a manual sync.")
                        .foregroundStyle(ShiftProColors.inkSubtle)
                } else if !isAuthorized {
                    Text("Calendar access is required to sync now.")
                        .foregroundStyle(ShiftProColors.warning)
                }
            }

            Section {
                Toggle("Enable Calendar Sync", isOn: $settings.isEnabled)
                    .disabled(!isAuthorized)

                if settings.isEnabled {
                    if isAuthorized {
                        if calendars.isEmpty {
                            Text("No calendars available.")
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        } else {
                            Picker("Calendar", selection: $selectedCalendarIdentifier) {
                                ForEach(calendars, id: \.calendarIdentifier) { calendar in
                                    Text(calendar.title).tag(calendar.calendarIdentifier)
                                }
                            }
                        }
                    } else {
                        Text("Grant permission to choose a calendar.")
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }

                    Picker("Sync Mode", selection: Binding(
                        get: { settings.mode },
                        set: { newMode in
                            if newMode == .twoWay && !settings.twoWaySyncConfirmed {
                                showTwoWaySyncConfirmation = true
                            } else {
                                settings.mode = newMode
                            }
                        }
                    )) {
                        ForEach(CalendarSyncMode.allCases, id: \.self) { mode in
                            if mode == .twoWay && permissionManager.calendarStatus == .writeOnly {
                                Text("\(mode.displayName) (Requires Full Access)").tag(mode)
                            } else {
                                Text(mode.displayName).tag(mode)
                            }
                        }
                    }
                    .disabled(!isAuthorized || (permissionManager.calendarStatus == .writeOnly && settings.mode != .exportOnly))

                    if permissionManager.calendarStatus == .writeOnly && settings.mode == .exportOnly {
                        Text("Two-way sync is disabled because you have write-only access. Upgrade to full access in Settings to enable it.")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.warning)
                    }
                }
            } header: {
                Text("Sync Settings")
            } footer: {
                if !isAuthorized {
                    Text("Grant calendar permission above to enable sync.")
                        .foregroundStyle(ShiftProColors.warning)
                } else if permissionManager.calendarStatus == .writeOnly {
                    Text("With write-only access, only export mode is available. To enable two-way sync, grant full calendar access in iOS Settings > Privacy & Security > Calendars > ShiftPro.")
                        .foregroundStyle(ShiftProColors.inkSubtle)
                } else if settings.mode == .twoWay {
                    Text("Two-way sync allows calendar changes to update your shifts. Changes made in your calendar app will be reflected in ShiftPro.")
                        .foregroundStyle(ShiftProColors.inkSubtle)
                } else {
                    Text("Export only pushes shift changes to your calendar without importing calendar changes.")
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
            }

            Section {
                Toggle("Add Event Alerts", isOn: $settings.includeAlarms)
                    .disabled(!settings.isEnabled || !isAuthorized)

                if settings.includeAlarms {
                    Stepper(
                        value: $settings.alarmOffsetMinutes,
                        in: 5...120,
                        step: 5
                    ) {
                        Text("Alert \(settings.alarmOffsetMinutes) min before")
                    }
                    .disabled(!settings.isEnabled || !isAuthorized)
                }
            } header: {
                Text("Alerts")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Calendar")
        .task {
            await permissionManager.refreshStatuses()
            loadCalendars()
        }
        .onChange(of: settings) { _, newValue in
            newValue.save()
        }
        .onChange(of: selectedCalendarIdentifier) { newValue in
            guard !newValue.isEmpty else { return }
            UserDefaults.standard.set(newValue, forKey: calendarIdentifierKey)
        }
        .confirmationDialog(
            "Enable Two-Way Sync?",
            isPresented: $showTwoWaySyncConfirmation,
            titleVisibility: .visible
        ) {
            Button("Enable Two-Way Sync") {
                settings.mode = .twoWay
                settings.twoWaySyncConfirmed = true
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("Two-way sync allows changes made in your calendar app to update your shifts in ShiftPro. This means editing or deleting events in your calendar will affect your shift records.\n\nAre you sure you want to enable this?")
        }
        .alert("Sync Failed", isPresented: $showSyncError) {
            Button("OK", role: .cancel) {
                showSyncError = false
                syncErrorMessage = nil
            }
        } message: {
            Text(syncErrorMessage ?? "Unable to sync your calendar right now.")
        }
    }

    private func loadCalendars() {
        guard isAuthorized else {
            calendars = []
            return
        }
        calendars = eventStore.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let knownIdentifiers = Set(calendars.map(\.calendarIdentifier))
        if selectedCalendarIdentifier.isEmpty || !knownIdentifiers.contains(selectedCalendarIdentifier) {
            selectedCalendarIdentifier = UserDefaults.standard.string(forKey: calendarIdentifierKey)
                ?? eventStore.defaultCalendarForNewEvents?.calendarIdentifier
                ?? calendars.first?.calendarIdentifier
                ?? ""
        }
    }

    private var selectedCalendarTitle: String {
        guard !selectedCalendarIdentifier.isEmpty else { return "Default" }
        if let match = calendars.first(where: { $0.calendarIdentifier == selectedCalendarIdentifier }) {
            return match.title
        }
        return "Default"
    }

    private var statusColor: Color {
        permissionManager.calendarStatus.color
    }

    private var permissionLevelDisplay: String {
        switch permissionManager.calendarStatus {
        case .authorized:
            return "Full Access"
        case .writeOnly:
            return "Write Only"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Requested"
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    @MainActor
    private func performSync() async {
        guard settings.isEnabled else {
            syncErrorMessage = "Turn on calendar sync to run a manual sync."
            showSyncError = true
            return
        }
        guard isAuthorized else {
            syncErrorMessage = "Calendar access is required. Enable access in Settings > Privacy & Security > Calendars."
            showSyncError = true
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let now = Date()
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -60, to: now) ?? now
        let end = calendar.date(byAdding: .day, value: 120, to: now) ?? now

        let service = CalendarIntegrationService(context: modelContext)

        do {
            try await service.syncShifts(in: DateInterval(start: start, end: end))
            settings = CalendarSyncSettings.load()
        } catch {
            syncErrorMessage = syncErrorText(for: error)
            showSyncError = true
        }
    }

    private func syncErrorText(for error: Error) -> String {
        if let dataError = error as? DataError {
            switch dataError {
            case .permissionDenied:
                return "Calendar access is required. Enable access in Settings > Privacy & Security > Calendars."
            case .cloudUnavailable:
                return "iCloud is unavailable. Try again later or check your iCloud settings."
            case .invalidState(let message):
                return message
            default:
                return dataError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}

#Preview {
    NavigationStack {
        CalendarSettingsView()
    }
}
