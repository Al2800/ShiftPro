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
                settingRow(icon: "bell", title: "Notifications", detail: "Enabled")
            }

            Section("Account") {
                settingRow(icon: "icloud", title: "iCloud Sync", detail: "Not connected")
                settingRow(icon: "lock.shield", title: "Privacy", detail: "Face ID")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
    }

    private func settingRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: ShiftProSpacing.m) {
            Image(systemName: icon)
                .foregroundStyle(ShiftProColors.accent)
            VStack(alignment: .leading, spacing: ShiftProSpacing.xxs) {
                Text(title)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)
                Text(detail)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
        .padding(.vertical, ShiftProSpacing.xxs)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
