import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                header

                featureList

                if entitlementManager.products.isEmpty {
                    placeholderCards
                } else {
                    productCards
                }

                restoreSection
            }
            .padding(.horizontal, ShiftProSpacing.medium)
            .padding(.vertical, ShiftProSpacing.large)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Upgrade")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            await entitlementManager.loadProducts()
        }
        .alert(
            "Notice",
            isPresented: Binding(
                get: { entitlementManager.errorMessage != nil },
                set: { _ in entitlementManager.errorMessage = nil }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(entitlementManager.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Unlock ShiftPro Premium")
                .font(ShiftProTypography.title)
                .foregroundStyle(ShiftProColors.ink)

            Text("Upgrade for advanced analytics, calendar sync, and full exports.")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Premium features")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            ForEach(ShiftProFeature.allCases, id: \.self) { feature in
                HStack(spacing: ShiftProSpacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ShiftProColors.success)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.displayName)
                            .font(ShiftProTypography.body)
                            .foregroundStyle(ShiftProColors.ink)
                        Text(feature.requiredTier.displayName)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var productCards: some View {
        VStack(spacing: ShiftProSpacing.medium) {
            ForEach(entitlementManager.products, id: \.id) { product in
                PaywallProductCard(product: product) {
                    Task { await entitlementManager.purchase(product) }
                }
            }
        }
    }

    private var placeholderCards: some View {
        VStack(spacing: ShiftProSpacing.medium) {
            PaywallPlaceholderCard(title: "Premium")
            PaywallPlaceholderCard(title: "Enterprise")
        }
    }

    private var restoreSection: some View {
        VStack(spacing: ShiftProSpacing.small) {
            Button("Restore Purchases") {
                Task { await entitlementManager.restorePurchases() }
            }
            .font(ShiftProTypography.subheadline)

            Text("Subscriptions auto-renew unless canceled 24 hours before renewal.")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PaywallProductCard: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)
                    Text(product.description)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(ShiftProColors.accent)
            }

            Button("Continue") {
                action()
            }
            .font(ShiftProTypography.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(ShiftProColors.accent)
            .foregroundStyle(ShiftProColors.midnight)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shiftProPressable(scale: 0.98, opacity: 0.96, haptic: .selection)
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct PaywallPlaceholderCard: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text(title)
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            ShimmerView(cornerRadius: 12)
                .frame(height: 14)

            ShimmerView(cornerRadius: 12)
                .frame(height: 36)
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        PaywallView()
            .environmentObject(EntitlementManager())
    }
}
