import SwiftUI
import StoreKit

/// Premium view using the canonical EntitlementManager system.
/// Note: This view now uses EntitlementManager for subscription state.
/// The legacy PremiumStore is deprecated.
struct PremiumView: View {
    @EnvironmentObject private var entitlementManager: EntitlementManager

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

                VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                    Text("Plans")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    if entitlementManager.products.isEmpty {
                        Text("StoreKit products are unavailable. Try again later.")
                            .font(ShiftProTypography.body)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    } else {
                        ForEach(entitlementManager.products, id: \.id) { product in
                            PremiumProductRow(
                                product: product,
                                isPurchased: entitlementManager.state.tier != .free
                            ) {
                                Task { await entitlementManager.purchase(product) }
                            }
                        }
                    }

                    if let error = entitlementManager.errorMessage {
                        Text(error)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.warning)
                    }
                }
            }
            .padding(ShiftProSpacing.large)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Premium")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Restore") {
                    Task { await entitlementManager.restorePurchases() }
                }
            }
        }
        .task {
            await entitlementManager.loadProducts()
        }
    }

    private var premiumHero: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Upgrade to ShiftPro Premium")
                .font(ShiftProTypography.title)
                .foregroundStyle(ShiftProColors.ink)
            Text("Unlock advanced analytics, custom rotations, and automatic exports for your team.")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
        .padding(ShiftProSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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

private struct PremiumProductRow: View {
    let product: Product
    let isPurchased: Bool
    let purchaseAction: () -> Void

    var body: some View {
        HStack(spacing: ShiftProSpacing.medium) {
            VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                Text(product.displayName)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)
                Text(product.description)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: ShiftProSpacing.extraExtraSmall) {
                Text(product.displayPrice)
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(ShiftProColors.ink)
                Button(isPurchased ? "Active" : "Buy") {
                    purchaseAction()
                }
                .buttonStyle(PressableScaleButtonStyle())
                .disabled(isPurchased)
                .foregroundStyle(isPurchased ? ShiftProColors.success : ShiftProColors.accent)
            }
        }
        .padding(ShiftProSpacing.medium)
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
