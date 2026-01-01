import EventKit
import SwiftUI

struct CalendarSettingsView: View {
    @StateObject private var permissionManager = PermissionManager()
    @State private var settings = CalendarSyncSettings.load()
    @State private var showTwoWaySyncConfirmation = false
    @State private var calendars: [EKCalendar] = []
    @State private var selectedCalendarIdentifier: String = ""

    private let eventStore = EKEventStore()
    private let calendarIdentifierKey = "ShiftPro.CalendarIdentifier"

    private var isAuthorized: Bool {
        permissionManager.calendarStatus == .authorized
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Calendar Access")
                    Spacer()
                    Text(permissionManager.calendarStatus.title)
                        .foregroundStyle(statusColor)
                        .font(ShiftProTypography.caption)
                }

                if !isAuthorized {
                    Button("Request Access") {
                        Task {
                            _ = await permissionManager.requestCalendarAccess()
                        }
                    }
                }

                if let lastSync = settings.lastSyncedAt {
                    HStack {
                        Text("Last Synced")
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            } header: {
                Text("Status")
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
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .disabled(!isAuthorized)
                }
            } header: {
                Text("Sync Settings")
            } footer: {
                if !isAuthorized {
                    Text("Grant calendar permission above to enable sync.")
                        .foregroundStyle(ShiftProColors.warning)
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
        }
        .onChange(of: settings) { _, newValue in
            newValue.save()
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
    }

    private var statusColor: Color {
        permissionManager.calendarStatus.color
    }
}

#Preview {
    NavigationStack {
        CalendarSettingsView()
    }
}
