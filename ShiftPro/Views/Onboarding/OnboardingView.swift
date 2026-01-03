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

            HStack(spacing: 4) {
                if !manager.step.requirementLabel.isEmpty {
                    Text(manager.step.requirementLabel)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.fog)
                    Text("•")
                        .foregroundStyle(ShiftProColors.fog.opacity(0.5))
                }
                Text(stepCountLabel)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.fog)
            }

            ProgressView(value: manager.progress)
                .tint(ShiftProColors.accent)
                .padding(.horizontal, ShiftProSpacing.large)
                .accessibilityIdentifier("onboarding.progress")
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("\(currentStepNumber) of \(totalSteps) steps completed")
        }
    }

    private var currentStepNumber: Int {
        manager.step.index + 1
    }

    private var totalSteps: Int {
        OnboardingStep.allCases.count
    }

    private var stepCountLabel: String {
        "Step \(currentStepNumber) of \(totalSteps)"
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

                HStack(spacing: 20) {
                    // Back button - always visible, disabled on first step
                    Button {
                        manager.back()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Back")
                        }
                        .font(ShiftProTypography.callout)
                        .foregroundStyle(manager.step == .welcome ? ShiftProColors.fog.opacity(0.4) : ShiftProColors.fog)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(ShiftProColors.fog.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(manager.step == .welcome)
                    .accessibilityIdentifier("onboarding.back")
                    .accessibilityHint(manager.step == .welcome ? "You are on the first step" : "Go to the previous step")

                    // Skip button - shown for skippable steps and value preview
                    if manager.step.isSkippable || manager.step == .valuePreview {
                        Button {
                            if manager.step == .valuePreview {
                                manager.next()
                            } else {
                                manager.skip()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(manager.step == .valuePreview ? "Skip preview" : "Skip for now")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .font(ShiftProTypography.callout)
                            .foregroundStyle(ShiftProColors.fog)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .stroke(ShiftProColors.fog.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .accessibilityIdentifier(manager.step == .valuePreview ? "onboarding.skipPreview" : "onboarding.skip")
                        .accessibilityHint("Skip this optional step")
                    }
                }

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
