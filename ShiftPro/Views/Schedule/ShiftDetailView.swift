import SwiftUI

struct ShiftDetailView: View {
    let title: String
    let timeRange: String
    let location: String?
    let status: StatusIndicator.Status
    let rateMultiplier: Double
    let rateLabel: String?
    let notes: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                summaryCard

                detailCard

                if let notes, !notes.isEmpty {
                    notesCard(notes)
                }
            }
            .padding(.horizontal, ShiftProSpacing.medium)
            .padding(.vertical, ShiftProSpacing.large)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Shift Details")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text(title)
                .font(ShiftProTypography.title)
                .foregroundStyle(ShiftProColors.ink)

            Text(timeRange)
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.inkSubtle)

            if let locationText = trimmedLocation {
                Text(locationText)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            HStack(spacing: ShiftProSpacing.small) {
                StatusIndicator(status: status)
                RateBadge(multiplier: rateMultiplier)
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Details")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            detailRow(label: "Status", value: status.label)
            detailRow(label: "Rate", value: rateDetailValue)
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var rateDetailValue: String {
        if let label = rateLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return label
        }
        return String(format: "%.1fx", rateMultiplier)
    }

    private var trimmedLocation: String? {
        guard let location else { return nil }
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
            Spacer()
            Text(value)
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.ink)
        }
    }

    private func notesCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Notes")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)
            Text(text)
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.ink)
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        ShiftDetailView(
            title: "Day Shift",
            timeRange: "Today • 7:00 AM - 7:00 PM",
            location: "Main Site",
            status: .scheduled,
            rateMultiplier: 1.5,
            rateLabel: "Bank Holiday",
            notes: "Team briefing at 6:30 AM."
        )
    }
}
