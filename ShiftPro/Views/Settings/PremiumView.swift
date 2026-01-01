import SwiftUI

/// Premium features showcase view.
/// This view displays available premium features and their unlock status.
/// All purchasing is routed through PaywallView for a single source of truth.
struct PremiumView: View {
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @State private var showingPaywall = false

    private var isPremium: Bool {
        entitlementManager.state.tier != .free
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                premiumHero

                VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                    Text("Premium Features")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    ForEach(ShiftProFeature.allCases, id: \.self) { feature in
                        PremiumFeatureRow(
                            feature: feature,
                            isUnlocked: entitlementManager.hasAccess(to: feature)
                        )
                    }
                }

                if !isPremium {
                    upgradeButton
                }
            }
            .padding(ShiftProSpacing.large)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Premium")
        .sheet(isPresented: $showingPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
    }

    private var premiumHero: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            if isPremium {
                HStack(spacing: ShiftProSpacing.small) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(ShiftProColors.success)
                    Text("ShiftPro Premium Active")
                        .font(ShiftProTypography.title)
                        .foregroundStyle(ShiftProColors.ink)
                }
                Text("You have access to all premium features.")
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            } else {
                Text("Upgrade to ShiftPro Premium")
                    .font(ShiftProTypography.title)
                    .foregroundStyle(ShiftProColors.ink)
                Text("Unlock advanced analytics, custom rotations, and automatic exports for your team.")
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
        .padding(ShiftProSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var upgradeButton: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack {
                Image(systemName: "star.circle.fill")
                Text("View Upgrade Options")
            }
            .font(ShiftProTypography.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ShiftProSpacing.medium)
            .background(ShiftProColors.accent)
            .foregroundStyle(ShiftProColors.midnight)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .shiftProPressable(scale: 0.98, opacity: 0.96, haptic: .selection)
    }
}

private struct PremiumFeatureRow: View {
    let feature: ShiftProFeature
    let isUnlocked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: ShiftProSpacing.small) {
            Image(systemName: isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                .foregroundStyle(isUnlocked ? ShiftProColors.success : ShiftProColors.accent)

            VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                Text(feature.displayName)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)
                Text(feature.requiredTier.tagline)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
        .padding(ShiftProSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        PremiumView()
            .environmentObject(EntitlementManager())
    }
}
