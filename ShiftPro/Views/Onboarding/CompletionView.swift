import SwiftUI

struct CompletionView: View {
    let data: OnboardingData
    let skippedSteps: Set<OnboardingStep>
    let onAddShift: () -> Void
    let onGoToDashboard: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                configuredItemsSection

                if hasSkippedSteps {
                    skippedItemsSection
                }

                settingsReminder

                ctaButtons
            }
            .padding(ShiftProSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(ShiftProColors.steel)
            )
            .padding(.horizontal, ShiftProSpacing.large)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(ShiftProColors.success)

            Text("You're All Set!")
                .font(ShiftProTypography.title)
                .foregroundStyle(Color.white)

            Text("Your personalized settings are ready. Start tracking your shifts now.")
                .font(ShiftProTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ShiftProColors.fog)
        }
    }

    // MARK: - Configured Items

    private var configuredItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Setup")
                .font(ShiftProTypography.headline)
                .foregroundStyle(Color.white)

            VStack(alignment: .leading, spacing: 8) {
                if !data.workplace.isEmpty {
                    configuredRow(icon: "building.2", label: "Workplace", value: data.workplace)
                }
                if !data.jobTitle.isEmpty {
                    configuredRow(icon: "person.badge.shield.checkmark", label: "Job Title", value: data.jobTitle)
                }
                configuredRow(icon: "calendar", label: "Pay Period", value: data.payPeriod.title)
                configuredRow(icon: "clock.arrow.2.circlepath", label: "Shift Pattern", value: data.selectedPattern.title)
                configuredRow(
                    icon: "dollarsign.circle",
                    label: "Base Rate",
                    value: String(format: "$%.2f/hr", data.baseRate)
                )
                if data.wantsCalendarSync {
                    configuredRow(icon: "calendar.badge.checkmark", label: "Calendar Sync", value: "Enabled")
                }
                if data.wantsNotifications {
                    configuredRow(icon: "bell.badge", label: "Notifications", value: "Enabled")
                }
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ShiftProColors.card)
        )
    }

    private func configuredRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(ShiftProColors.success)
                .frame(width: 24)

            Text(label)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.fog)

            Spacer()

            Text(value)
                .font(ShiftProTypography.body)
                .foregroundStyle(Color.white)
                .lineLimit(1)
        }
    }

    // MARK: - Skipped Items

    private var hasSkippedSteps: Bool {
        !skippedSteps.isEmpty
    }

    private var skippedItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(ShiftProColors.warning)
                Text("Skipped for Now")
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(Color.white)
            }

            ForEach(Array(skippedSteps), id: \.self) { step in
                HStack(spacing: 12) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(ShiftProColors.fog)
                        .frame(width: 24)

                    Text(step.title)
                        .font(ShiftProTypography.body)
                        .foregroundStyle(ShiftProColors.fog)

                    Spacer()
                }
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ShiftProColors.card.opacity(0.6))
        )
    }

    // MARK: - Settings Reminder

    private var settingsReminder: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape")
                .foregroundStyle(ShiftProColors.accent)

            Text("You can adjust any of these settings later in the Settings tab.")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.fog)
        }
        .padding(.horizontal, ShiftProSpacing.small)
    }

    // MARK: - CTAs

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            Button(action: onAddShift) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Shift")
                }
                .font(ShiftProTypography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ShiftProColors.accent)
                )
                .foregroundStyle(ShiftProColors.midnight)
            }
            .accessibilityIdentifier("completion.addShift")

            Button(action: onGoToDashboard) {
                Text("Go to Dashboard")
                    .font(ShiftProTypography.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ShiftProColors.fog.opacity(0.5), lineWidth: 1)
                    )
                    .foregroundStyle(ShiftProColors.fog)
            }
            .accessibilityIdentifier("completion.dashboard")
        }
    }
}

#Preview {
    CompletionView(
        data: OnboardingData(),
        skippedSteps: [.permissions, .calendar],
        onAddShift: {},
        onGoToDashboard: {}
    )
    .padding()
    .background(ShiftProColors.heroGradient)
}
