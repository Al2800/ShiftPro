import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("Profile") {
                settingRow(icon: "person.crop.circle", title: "Officer Profile", detail: "Central Precinct")
                settingRow(icon: "shield", title: "Badge Number", detail: "#2741")
            }

            Section("Preferences") {
                settingRow(icon: "calendar", title: "Default Pattern", detail: "4-on / 2-off")
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    settingRow(icon: "bell", title: "Notifications", detail: "Schedule & alerts")
                }
            }

            Section("Account") {
                settingRow(icon: "icloud", title: "iCloud Sync", detail: "Not connected")
                settingRow(icon: "lock.shield", title: "Privacy", detail: "Face ID")
            }

            Section("Subscription") {
                NavigationLink {
                    SubscriptionSettingsView()
                } label: {
                    settingRow(icon: "star.circle", title: "Subscription", detail: "Manage plan")
                }
                .accessibilityIdentifier("settings.subscription")
            }

            Section("Integrations") {
                NavigationLink {
                    CalendarSettingsView()
                } label: {
                    settingRow(icon: "calendar.badge.clock", title: "Calendar Settings", detail: "Sync & permissions")
                }
            }

            Section("Premium") {
                NavigationLink {
                    PremiumView()
                } label: {
                    settingRow(icon: "star.circle", title: "ShiftPro Premium", detail: "Unlock advanced features")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
    }

    private func settingRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: ShiftProSpacing.medium) {
            Image(systemName: icon)
                .foregroundStyle(ShiftProColors.accent)
            VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                Text(title)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)
                Text(detail)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
        .padding(.vertical, ShiftProSpacing.extraExtraSmall)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
