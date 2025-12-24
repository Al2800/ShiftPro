import SwiftUI

struct QuickActionButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let systemImage: String
    let action: () -> Void
    var accessibilityIdentifier: String? = nil

    var body: some View {
        Button(action: {
            HapticManager.fire(.impactLight, enabled: !reduceMotion)
            action()
        }) {
            HStack(spacing: ShiftProSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(ShiftProTypography.subheadline)
            }
            .foregroundStyle(ShiftProColors.ink)
            .padding(.horizontal, ShiftProSpacing.m)
            .padding(.vertical, ShiftProSpacing.s)
            .background(ShiftProColors.accentMuted)
            .clipShape(Capsule())
            .shadow(color: ShiftProColors.accent.opacity(0.2), radius: 12, x: 0, y: 6)
        }
        .shiftProPressable(scale: 0.97, opacity: 0.94, haptic: nil)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

#Preview {
    QuickActionButton(title: "Start Shift", systemImage: "play.fill") {}
        .padding()
        .background(ShiftProColors.background)
}
