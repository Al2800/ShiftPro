import SwiftUI

struct ShiftCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let timeRange: String
    let location: String
    let status: StatusIndicator.Status
    let rateMultiplier: Double
    let notes: String?
    var accessibilityIdentifier: String?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack(alignment: .top, spacing: ShiftProSpacing.small) {
                VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                    Text(title)
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    Text(timeRange)
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    Text(location)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: ShiftProSpacing.extraSmall) {
                    StatusIndicator(status: status)
                    RateBadge(multiplier: rateMultiplier)
                }
            }

            if isExpanded, let notes {
                Divider()
                Text(notes)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)
                    .transition(ShiftProTransitions.cardExpand)
            }

            Button {
                withAnimation(AnimationManager.animation(.standard, reduceMotion: reduceMotion)) {
                    isExpanded.toggle()
                }
                HapticManager.fire(.selection, enabled: !reduceMotion)
            } label: {
                HStack(spacing: ShiftProSpacing.extraExtraSmall) {
                    Text(isExpanded ? "Hide details" : "View details")
                        .font(ShiftProTypography.caption)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(ShiftProColors.accent)
            }
            .buttonStyle(.plain)
            .shiftProPressable(scale: 0.98, opacity: 0.96, haptic: nil)
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ShiftProColors.accentMuted, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Shift card")
        .accessibilityValue("\(title), \(timeRange), \(status.rawValue)")
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

#Preview {
    ShiftCardView(
        title: "Day Shift",
        timeRange: "7:00 AM - 7:00 PM",
        location: "Main Site",
        status: .scheduled,
        rateMultiplier: 1.5,
        notes: "Team briefing at 6:30 AM."
    )
    .padding()
    .background(ShiftProColors.background)
}
