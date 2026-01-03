import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\NotificationSettings.createdAt, order: .forward)])
    private var settingsList: [NotificationSettings]

    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    @Query(filter: #Predicate<Shift> { $0.deletedAt == nil }, sort: [SortDescriptor(\Shift.scheduledStart, order: .forward)])
    private var shifts: [Shift]

    @StateObject private var permissionManager = PermissionManager()
    @State private var isScheduling = false

    var body: some View {
        Group {
            if let settings = settingsList.first {
                NotificationSettingsForm(
                    settings: settings,
                    permissionManager: permissionManager,
                    shifts: shifts,
                    isScheduling: $isScheduling,
                    context: context
                )
            } else {
                ProgressView("Loading settings...")
            }
        }
        .navigationTitle("Notifications")
        .task {
            await permissionManager.refreshStatuses()
            ensureSettings()
        }
    }

    private func ensureSettings() {
        guard settingsList.isEmpty else { return }
        let settings = NotificationSettings(owner: profiles.first)
        context.insert(settings)
    }
}

private struct NotificationSettingsForm: View {
    @Bindable var settings: NotificationSettings
    @ObservedObject var permissionManager: PermissionManager
    let shifts: [Shift]
    @Binding var isScheduling: Bool
    let context: ModelContext

    @State private var isSendingTest = false
    @State private var testSentAt: Date?
    @State private var testError: String?

    private var isAuthorized: Bool {
        permissionManager.notificationStatus == .authorized
    }

    private var nextUpcomingShift: Shift? {
        let now = Date()
        return shifts.first { $0.scheduledStart > now && $0.status != .cancelled }
    }

    private var nextReminderPreview: String? {
        guard settings.shiftStartReminderEnabled, let shift = nextUpcomingShift else { return nil }
        let reminderDate = shift.scheduledStart.addingTimeInterval(-Double(settings.shiftStartReminderMinutes) * 60)
        if reminderDate <= Date() {
            return "Next reminder: when shift starts"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "Next reminder: \(formatter.string(from: reminderDate))"
    }

    var body: some View {
        Form {
            Section("Status") {
                HStack {
                    Text("Permission")
                    Spacer()
                    Text(permissionManager.notificationStatus.title)
                        .foregroundStyle(permissionManager.notificationStatus.color)
                }

                if !isAuthorized {
                    Button("Request Access") {
                        Task {
                            _ = await permissionManager.requestNotificationAccess()
                            await permissionManager.refreshStatuses()
                        }
                    }
                }

                if let lastScheduled = settings.lastScheduledAt {
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(lastScheduled, style: .relative)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            }

            if isAuthorized {
                Section {
                    Button {
                        sendTestNotification()
                    } label: {
                        HStack {
                            if isSendingTest {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Sending...")
                            } else {
                                Image(systemName: "bell.badge")
                                    .foregroundStyle(ShiftProColors.accent)
                                Text("Send Test Notification")
                            }
                        }
                    }
                    .disabled(isSendingTest)

                    if let testSentAt {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ShiftProColors.success)
                            Text("Test sent")
                            Spacer()
                            Text(testSentAt, style: .relative)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                    }

                    if let testError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ShiftProColors.warning)
                            Text(testError)
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                    }

                    if let preview = nextReminderPreview {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(ShiftProColors.inkSubtle)
                            Text(preview)
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                    }
                } header: {
                    Text("Test")
                } footer: {
                    Text("A notification will appear in a few seconds. Make sure your device isn't in Do Not Disturb mode.")
                }
            }

            Section {
                Toggle("Start reminders", isOn: $settings.shiftStartReminderEnabled)
                    .disabled(!isAuthorized)

                if settings.shiftStartReminderEnabled {
                    Picker("Reminder lead time", selection: $settings.shiftStartReminderMinutes) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }
                    .disabled(!isAuthorized)
                }

                Toggle("End-of-shift summary", isOn: $settings.shiftEndSummaryEnabled)
                    .disabled(!isAuthorized)
            } header: {
                Text("Shift Reminders")
            } footer: {
                if isAuthorized && settings.shiftStartReminderEnabled {
                    Text("Reminders fire \(settings.shiftStartReminderMinutes) minutes before shift start.")
                        .foregroundStyle(ShiftProColors.inkSubtle)
                } else if !isAuthorized {
                    Text("Grant notification permission above to enable reminders.")
                        .foregroundStyle(ShiftProColors.warning)
                }
            }

            Section("Overtime") {
                Toggle("Overtime warnings", isOn: $settings.overtimeWarningEnabled)
                    .disabled(!isAuthorized)

                if settings.overtimeWarningEnabled {
                    Stepper(value: $settings.overtimeWarningThresholdHours, in: 20...80, step: 1) {
                        Text("Warn at \(Int(settings.overtimeWarningThresholdHours)) hours")
                    }
                    .disabled(!isAuthorized)
                }
            }

            Section("Weekly Summary") {
                Toggle("Weekly recap", isOn: $settings.weeklySummaryEnabled)
                    .disabled(!isAuthorized)
            }

            Section("Quiet Hours") {
                DatePicker(
                    "Quiet hours start",
                    selection: quietHoursBinding(isStart: true),
                    displayedComponents: .hourAndMinute
                )
                .disabled(!isAuthorized)

                DatePicker(
                    "Quiet hours end",
                    selection: quietHoursBinding(isStart: false),
                    displayedComponents: .hourAndMinute
                )
                .disabled(!isAuthorized)
            }

            Section {
                Button(isScheduling ? "Scheduling..." : "Reschedule Notifications") {
                    Task {
                        isScheduling = true
                        let upcoming = shifts.filter { $0.scheduledStart > Date() }
                        let scheduler = NotificationScheduler()
                        let center = UNUserNotificationCenter.current()
                        let requests = scheduler.requests(for: upcoming, settings: settings, now: Date())
                        center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier))
                        for request in requests {
                            try? await center.add(request)
                        }
                        settings.lastScheduledAt = Date()
                        settings.markUpdated()
                        isScheduling = false
                    }
                }
                .disabled(isScheduling || !isAuthorized)
            } footer: {
                if isAuthorized {
                    Text("Changes apply to future shifts. Notifications respect system Focus and quiet hours.")
                } else {
                    Text("Enable notification permission to schedule reminders for your shifts.")
                        .foregroundStyle(ShiftProColors.warning)
                }
            }
        }
    }

    private func sendTestNotification() {
        isSendingTest = true
        testError = nil

        Task {
            do {
                let content = UNMutableNotificationContent()
                content.title = "ShiftPro Test"
                content.body = "Notifications are working! You'll receive reminders before your shifts."
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "test-notification-\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )

                try await UNUserNotificationCenter.current().add(request)

                await MainActor.run {
                    testSentAt = Date()
                    isSendingTest = false
                }
            } catch {
                await MainActor.run {
                    testError = error.localizedDescription
                    isSendingTest = false
                }
            }
        }
    }

    private func quietHoursBinding(isStart: Bool) -> Binding<Date> {
        Binding(
            get: {
                let minutes = isStart ? settings.quietHoursStartMinutes : settings.quietHoursEndMinutes
                return DateMath.date(for: Date(), atMinute: minutes)
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                if isStart {
                    settings.quietHoursStartMinutes = minutes
                } else {
                    settings.quietHoursEndMinutes = minutes
                }
                settings.markUpdated()
            }
        )
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
    .modelContainer(ModelContainerFactory.unsafePreviewContainer())
}
