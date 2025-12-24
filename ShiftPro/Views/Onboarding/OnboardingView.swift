import SwiftUI

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager()
    @StateObject private var permissionManager = PermissionManager()

    let onFinish: () -> Void

    var body: some View {
        ZStack {
            ShiftProColors.heroGradient
                .ignoresSafeArea()

            VStack(spacing: ShiftProSpacing.large) {
                progressHeader

                currentStepView

                navigationControls
            }
            .padding(.vertical, ShiftProSpacing.extraLarge)
        }
        .environmentObject(permissionManager)
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text(manager.step.title)
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.fog)

            ProgressView(value: manager.progress)
                .tint(ShiftProColors.accent)
                .padding(.horizontal, ShiftProSpacing.large)
                .accessibilityIdentifier("onboarding.progress")
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch manager.step {
        case .welcome:
            WelcomeView()
        case .permissions:
            PermissionsView(
                wantsCalendarSync: $manager.data.wantsCalendarSync,
                wantsNotifications: $manager.data.wantsNotifications
            )
        case .profile:
            ProfileSetupView(data: $manager.data)
        case .payPeriod:
            PayPeriodSetupView(data: $manager.data)
        case .pattern:
            PatternDiscoveryView(data: $manager.data)
        case .calendar:
            CalendarSetupView(wantsCalendarSync: $manager.data.wantsCalendarSync)
        case .completion:
            CompletionView(data: manager.data)
        }
    }

    private var navigationControls: some View {
        VStack(spacing: 12) {
            Button(action: primaryAction) {
                Text(primaryButtonTitle)
                    .font(ShiftProTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(ShiftProColors.accent)
                    )
                    .foregroundStyle(ShiftProColors.midnight)
            }
            .padding(.horizontal, ShiftProSpacing.large)
            .accessibilityIdentifier("onboarding.primary")

            HStack(spacing: 16) {
                Button("Back") { manager.back() }
                    .disabled(manager.step == .welcome)
                    .accessibilityIdentifier("onboarding.back")

                if manager.step.isSkippable {
                    Button("Skip for now") { manager.skip() }
                        .accessibilityIdentifier("onboarding.skip")
                }
            }
            .font(ShiftProTypography.caption)
            .foregroundStyle(ShiftProColors.fog)
        }
    }

    private var primaryButtonTitle: String {
        manager.step == .completion ? "Start Using ShiftPro" : "Continue"
    }

    private func primaryAction() {
        if manager.step == .completion {
            onFinish()
        } else {
            manager.next()
        }
    }
}

#Preview {
    OnboardingView(onFinish: { })
}
