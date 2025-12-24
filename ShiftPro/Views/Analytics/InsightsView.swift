import SwiftUI

/// Full-screen view showing all insights with details.
struct InsightsView: View {
    let insights: [ShiftInsight]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if insights.isEmpty {
                        emptyState
                    } else {
                        ForEach(insights) { insight in
                            InsightDetailCard(insight: insight)
                        }
                    }
                }
                .padding()
            }
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
        VStack(spacing: 16) {
            Image(systemName: "lightbulb.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No Insights Yet")
                .font(.headline)
            
            Text("Complete more shifts to generate personalized insights about your work patterns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
}

struct InsightDetailCard: View {
    let insight: ShiftInsight
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: insight.iconName)
                    .font(.title2)
                    .foregroundStyle(insightColor)
                    .frame(width: 44, height: 44)
                    .background(insightColor.opacity(0.1))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(insight.title)
                            .font(.headline)
                        
                        Spacer()
                        
                        priorityBadge
                    }
                    
                    Text(insight.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Description
            Text(insight.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Action (if available)
            if insight.actionable, let action = insight.action {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Action")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(insightColor)
                        
                        Text(action)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var insightColor: Color {
        switch insight.type {
        case .positive: return .green
        case .warning: return .orange
        case .info: return .blue
        case .trend: return .purple
        }
    }
    
    private var priorityBadge: some View {
        Group {
            switch insight.priority {
            case .high:
                Text("High")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .cornerRadius(4)
            case .medium:
                Text("Medium")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.1))
                    .foregroundStyle(.orange)
                    .cornerRadius(4)
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
