import SwiftUI
import UIKit

struct PermissionsView: View {
    @EnvironmentObject var permissionManager: PermissionManager
    @Environment(\.openURL) private var openURL
    @Binding var wantsCalendarSync: Bool
    @Binding var wantsNotifications: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Permissions")
                .font(ShiftProTypography.title)
                .foregroundStyle(Color.white)

            Text("Enable what you need now. You can continue without granting access and turn features on later in Settings.")
                .font(ShiftProTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ShiftProColors.fog)
                .padding(.horizontal, ShiftProSpacing.large)

            permissionCard(
                title: "Calendar Access",
                description: "Export shifts to your iOS calendar. We request write-only access by default.",
                benefit: "See your work schedule alongside personal plans.",
                status: permissionManager.calendarStatus,
                toggleOn: $wantsCalendarSync,
                actionTitle: "Allow Calendar"
            ) {
                Task { await permissionManager.requestCalendarAccess() }
            }

            permissionCard(
                title: "Notifications",
                description: "Get reminders before shifts start.",
                benefit: "Stay on time with alerts you can customize later.",
                status: permissionManager.notificationStatus,
                toggleOn: $wantsNotifications,
                actionTitle: "Allow Notifications"
            ) {
                Task { await permissionManager.requestNotificationAccess() }
            }

            Button("Manage Permissions in Settings") {
                openSettings()
            }
            .font(ShiftProTypography.caption)
            .foregroundStyle(ShiftProColors.accent)
            .accessibilityLabel("Open Settings")
        }
        .padding(ShiftProSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ShiftProColors.steel)
        )
        .padding(.horizontal, ShiftProSpacing.large)
        .task {
            await permissionManager.refreshStatuses()
        }
    }

    private func permissionCard(
        title: String,
        description: String,
        benefit: String,
        status: PermissionStatus,
        toggleOn: Binding<Bool>,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(Color.white)
                Spacer()
                Text(status.title)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(status.color)
            }

            Text(description)
                .font(ShiftProTypography.callout)
                .foregroundStyle(ShiftProColors.fog)

            Text(benefit)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.fog.opacity(0.9))

            Toggle("Enable", isOn: toggleOn)
                .tint(ShiftProColors.accent)
                .foregroundStyle(Color.white)

            Button(action: action) {
                Text(actionTitle)
                    .font(ShiftProTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ShiftProColors.accent)
                    )
                    .foregroundStyle(ShiftProColors.midnight)
            }
            .disabled(!toggleOn.wrappedValue)
            .opacity(toggleOn.wrappedValue ? 1 : 0.5)
        }
        .padding(ShiftProSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ShiftProColors.card)
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    PermissionsView(
        wantsCalendarSync: .constant(true),
        wantsNotifications: .constant(true)
    )
    .environmentObject(PermissionManager())
    .padding()
    .background(ShiftProColors.heroGradient)
}
