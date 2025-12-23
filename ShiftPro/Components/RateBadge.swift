import SwiftUI

struct RateBadge: View {
    let multiplier: Double

    private var badgeColor: Color {
        switch multiplier {
        case 2.0...:
            return ShiftProColor.danger
        case 1.5...:
            return ShiftProColor.warning
        case 1.3...:
            return ShiftProColor.accent
        default:
            return ShiftProColor.success
        }
    }

    var body: some View {
        Text(String(format: "%.1fx", multiplier))
            .font(ShiftProTypography.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, ShiftProSpacing.small)
            .padding(.vertical, ShiftProSpacing.xSmall)
            .background(
                Capsule(style: .continuous)
                    .fill(badgeColor)
            )
            .accessibilityLabel("Rate multiplier \(multiplier)")
    }
}

#Preview {
    VStack(spacing: ShiftProSpacing.small) {
        RateBadge(multiplier: 1.0)
        RateBadge(multiplier: 1.3)
        RateBadge(multiplier: 1.5)
        RateBadge(multiplier: 2.0)
    }
    .padding()
    .background(ShiftProColor.background)
}
