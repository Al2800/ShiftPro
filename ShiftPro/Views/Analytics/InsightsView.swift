import SwiftUI

/// Full-screen view showing all insights with details.
struct InsightsView: View {
    let insights: [ShiftInsight]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ShiftProSpacing.medium) {
                    if insights.isEmpty {
                        emptyState
                    } else {
                        ForEach(insights) { insight in
                            InsightDetailCard(insight: insight)
                        }
                    }
                }
                .padding(ShiftProSpacing.medium)
            }
            .background(ShiftProColors.background)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: ShiftProSpacing.medium) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 48))
                .foregroundStyle(ShiftProColors.inkSubtle)

            Text("No Insights Yet")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            Text("Complete more shifts to generate personalized insights about your work patterns.")
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.inkSubtle)
                .multilineTextAlignment(.center)
        }
        .padding(.top, ShiftProSpacing.extraLarge)
    }
}

struct InsightDetailCard: View {
    let insight: ShiftInsight
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            // Header
            HStack(spacing: ShiftProSpacing.medium) {
                Image(systemName: insight.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(insightColor)
                    .frame(width: 44, height: 44)
                    .background(insightColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                    HStack {
                        Text(insight.title)
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(ShiftProColors.ink)

                        Spacer()

                        priorityBadge
                    }

                    Text(insight.type.rawValue.capitalized)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
            }

            // Description
            Text(insight.description)
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.inkSubtle)

            // Action (if available)
            if insight.actionable, let action = insight.action {
                Divider()

                VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                    Text("Suggested Action")
                        .font(ShiftProTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(insightColor)

                        Text(action)
                            .font(ShiftProTypography.subheadline)
                            .foregroundStyle(ShiftProColors.ink)
                    }
                }
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var insightColor: Color {
        switch insight.type {
        case .positive: return ShiftProColors.success
        case .warning: return ShiftProColors.warning
        case .info: return ShiftProColors.accent
        case .trend: return ShiftProColors.accentMuted
        }
    }

    private var priorityBadge: some View {
        Group {
            switch insight.priority {
            case .high:
                Text("High")
                    .font(ShiftProTypography.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, ShiftProSpacing.small)
                    .padding(.vertical, ShiftProSpacing.extraExtraSmall)
                    .background(ShiftProColors.danger.opacity(0.1))
                    .foregroundStyle(ShiftProColors.danger)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            case .medium:
                Text("Medium")
                    .font(ShiftProTypography.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, ShiftProSpacing.small)
                    .padding(.vertical, ShiftProSpacing.extraExtraSmall)
                    .background(ShiftProColors.warning.opacity(0.1))
                    .foregroundStyle(ShiftProColors.warning)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            case .low:
                EmptyView()
            }
        }
    }
}

#Preview {
    InsightsView(insights: [
        ShiftInsight(
            id: UUID(),
            type: .warning,
            title: "High Weekly Hours",
            description: "You're at 52 hours this week. Consider taking some rest.",
            priority: .high,
            iconName: "exclamationmark.triangle",
            actionable: true,
            action: "Consider reducing upcoming shifts or taking a day off"
        ),
        ShiftInsight(
            id: UUID(),
            type: .positive,
            title: "Consistent Schedule",
            description: "Your shift lengths are consistent, which helps with planning.",
            priority: .low,
            iconName: "checkmark.circle",
            actionable: false,
            action: nil
        ),
        ShiftInsight(
            id: UUID(),
            type: .info,
            title: "Night Shift Pattern",
            description: "Most of your shifts are during night hours.",
            priority: .medium,
            iconName: "moon.stars",
            actionable: true,
            action: "Maintain consistent sleep schedule even on days off"
        )
    ])
}
