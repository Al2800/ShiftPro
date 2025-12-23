import SwiftUI

struct ShiftCardView: View {
    let title: String
    let timeRange: String
    let location: String
    let status: ShiftUIStatus
    let rateMultiplier: Double
    let notes: String?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.s) {
            HStack(alignment: .top, spacing: ShiftProSpacing.s) {
                VStack(alignment: .leading, spacing: ShiftProSpacing.xxs) {
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

                VStack(alignment: .trailing, spacing: ShiftProSpacing.xs) {
                    StatusIndicator(status: status)
                    RateBadge(multiplier: rateMultiplier)
                }
            }

            if isExpanded, let notes {
                Divider()
                Text(notes)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)
            }

            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: ShiftProSpacing.xxs) {
                    Text(isExpanded ? "Hide details" : "View details")
                        .font(ShiftProTypography.caption)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(ShiftProColors.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(ShiftProSpacing.m)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ShiftProColors.accentMuted, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Shift card")
        .accessibilityValue("\(title), \(timeRange), \(status.rawValue)")
    }
}

#Preview {
    ShiftCardView(
        title: "Day Patrol",
        timeRange: "7:00 AM - 7:00 PM",
        location: "Central Precinct",
        status: .scheduled,
        rateMultiplier: 1.5,
        notes: "Remember body camera check and briefing at 6:30 AM."
    )
    .padding()
    .background(ShiftProColors.background)
}
