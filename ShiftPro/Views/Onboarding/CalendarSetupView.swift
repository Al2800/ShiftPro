import SwiftUI

struct CalendarSetupView: View {
    @EnvironmentObject var permissionManager: PermissionManager
    @Binding var wantsCalendarSync: Bool

    private var calendarButtonTitle: String {
        permissionManager.calendarStatus == .notDetermined
            ? "Grant Calendar Access"
            : "Change Calendar Access"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Calendar Sync")
                .font(ShiftProTypography.title)
                .foregroundStyle(Color.white)

            Text("Keep shifts visible in your system calendar. You control which events are shared.")
                .font(ShiftProTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ShiftProColors.fog)
                .padding(.horizontal, ShiftProSpacing.large)

            Toggle("Enable Calendar Sync", isOn: $wantsCalendarSync)
                .tint(ShiftProColors.accent)
                .foregroundStyle(Color.white)
                .padding(.horizontal, ShiftProSpacing.large)

            Button(action: {
                Task { await permissionManager.requestCalendarAccess() }
            }) {
                Text(calendarButtonTitle)
                    .font(ShiftProTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ShiftProColors.accent)
                    )
                    .foregroundStyle(ShiftProColors.midnight)
            }
            .disabled(!wantsCalendarSync)
            .opacity(wantsCalendarSync ? 1 : 0.5)
            .shiftProPressable()

            Text("Status: \(permissionManager.calendarStatus.title)")
                .font(ShiftProTypography.caption)
                .foregroundStyle(permissionManager.calendarStatus.color)
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
}

#Preview {
    CalendarSetupView(wantsCalendarSync: .constant(true))
        .environmentObject(PermissionManager())
        .padding()
        .background(ShiftProColors.heroGradient)
}
