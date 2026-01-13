import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var secondaryActionTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var surfaceLevel: ShiftProSurfaceLevel = .standard

    var body: some View {
        VStack(spacing: ShiftProSpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(ShiftProColors.inkSubtle)

            VStack(spacing: ShiftProSpacing.extraExtraSmall) {
                Text(title)
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(ShiftProColors.ink)

                Text(subtitle)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
                    .multilineTextAlignment(.center)
            }

            if actionTitle != nil || secondaryActionTitle != nil {
                VStack(spacing: ShiftProSpacing.extraSmall) {
                    if let actionTitle, let action {
                        Button(actionTitle) {
                            action()
                        }
                        .font(ShiftProTypography.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ShiftProSpacing.small)
                        .background(ShiftProColors.accent)
                        .foregroundStyle(ShiftProColors.midnight)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shiftProPressable(scale: 0.98, opacity: 0.96, haptic: .selection)
                    }

                    if let secondaryActionTitle, let secondaryAction {
                        Button(secondaryActionTitle) {
                            secondaryAction()
                        }
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .shiftProSurface(surfaceLevel)
    }
}

#Preview {
    EmptyStateView(
        icon: "calendar.badge.plus",
        title: "No shifts yet",
        subtitle: "Add your first shift to see analytics and pay.",
        actionTitle: "Add Shift",
        action: { }
    )
    .padding()
    .background(ShiftProColors.background)
}
