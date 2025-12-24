import SwiftUI

struct CalendarSettingsView: View {
    @StateObject private var permissions = CalendarPermissions()
    @State private var settings = CalendarSyncSettings.load()

    var body: some View {
        List {
            Section("Sync") {
                Toggle("Enable Calendar Sync", isOn: $settings.isEnabled)
                Picker("Sync Mode", selection: $settings.mode) {
                    ForEach(CalendarSyncMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .disabled(!settings.isEnabled)
            }

            Section("Alerts") {
                Toggle("Add Event Alerts", isOn: $settings.includeAlarms)
                    .disabled(!settings.isEnabled)

                Stepper(
                    value: $settings.alarmOffsetMinutes,
                    in: 5...120,
                    step: 5
                ) {
                    Text("Alert \(settings.alarmOffsetMinutes) min before")
                }
                .disabled(!settings.isEnabled || !settings.includeAlarms)
            }

            Section("Permissions") {
                HStack {
                    Text("Calendar Access")
                    Spacer()
                    Text(permissions.statusLabel)
                        .foregroundStyle(statusColor)
                        .font(ShiftProTypography.caption)
                }

                Button("Request Access") {
                    Task {
                        _ = await permissions.requestAccess()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Calendar")
        .onAppear {
            permissions.refresh()
        }
        .onChange(of: settings) { newValue in
            newValue.save()
        }
    }

    private var statusColor: Color {
        switch permissions.status {
        case .authorized, .fullAccess:
            return ShiftProColors.success
        case .denied:
            return ShiftProColors.danger
        case .restricted:
            return ShiftProColors.warning
        case .notDetermined:
            return ShiftProColors.textSecondary
        case .writeOnly:
            return ShiftProColors.warning
        @unknown default:
            return ShiftProColors.textSecondary
        }
    }
}

#Preview {
    NavigationStack {
        CalendarSettingsView()
    }
}
