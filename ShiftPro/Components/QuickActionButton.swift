import SwiftUI

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        .accessibilityLabel(title)
    }
}

#Preview {
    QuickActionButton(title: "Start Shift", systemImage: "play.fill") {}
        .padding()
        .background(ShiftProColors.background)
}
