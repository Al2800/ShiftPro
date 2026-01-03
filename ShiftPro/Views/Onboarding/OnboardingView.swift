import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var manager = OnboardingManager()
    @StateObject private var permissionManager = PermissionManager()
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var saveError: String?
    @AppStorage("showAddShiftAfterOnboarding") private var showAddShiftAfterOnboarding = false

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
        .alert("Unable to Save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {
                showSaveError = false
                saveError = nil
            }
        } message: {
            Text(saveError ?? "An unknown error occurred.")
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text(manager.step.title)
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.fog)

            if !manager.step.requirementLabel.isEmpty {
                Text(manager.step.requirementLabel)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.fog)
            }

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
        case .valuePreview:
            ValuePreviewView()
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
            CompletionView(
                data: manager.data,
                skippedSteps: manager.skippedSteps,
                onAddShift: { completeOnboarding(navigateToAddShift: true) },
                onGoToDashboard: { completeOnboarding(navigateToAddShift: false) }
            )
        }
    }

    @ViewBuilder
    private var navigationControls: some View {
        // Hide standard navigation on completion step since CompletionView has its own CTAs
        if manager.step != .completion {
            VStack(spacing: 12) {
                Button(action: primaryAction) {
                    Text(isSaving ? "Saving..." : primaryButtonTitle)
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
                .disabled(isSaving || !manager.canProceed)

                HStack(spacing: 16) {
                    Button("Back") { manager.back() }
                        .disabled(manager.step == .welcome)
                        .accessibilityIdentifier("onboarding.back")

                    if manager.step.isSkippable {
                        Button("Skip for now") { manager.skip() }
                            .accessibilityIdentifier("onboarding.skip")
                    } else if manager.step == .valuePreview {
                        Button("Skip preview") { manager.next() }
                            .accessibilityIdentifier("onboarding.skipPreview")
                    }
                }
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.fog)

                if let message = manager.validationMessage {
                    Text(message)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.warning)
                }
            }
        }
    }

    private var primaryButtonTitle: String {
        "Continue"
    }

    private func primaryAction() {
        manager.next()
    }

    private func completeOnboarding(navigateToAddShift: Bool) {
        guard !isSaving else { return }
        isSaving = true
        do {
            try manager.persist(context: modelContext)
            isSaving = false
            showAddShiftAfterOnboarding = navigateToAddShift
            onFinish()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
            showSaveError = true
        }
    }
}

#Preview {
    OnboardingView(onFinish: { })
}
