import SwiftUI

struct SubscriptionSettingsView: View {
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @Environment(\.openURL) private var openURL

    private let termsURL = URL(string: "https://shiftpro.app/terms")
    private let privacyURL = URL(string: "https://shiftpro.app/privacy")

    var body: some View {
        List {
            Section("Current Plan") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entitlementManager.state.tier.displayName)
                            .font(ShiftProTypography.headline)
                        Text(entitlementManager.state.tier.tagline)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                    Spacer()
                    if let expiration = entitlementManager.state.expirationDate {
                        Text(expiration, style: .date)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            }

            Section("Upgrade") {
                NavigationLink {
                    PaywallView()
                } label: {
                    Text("View subscription options")
                }
            }

            Section("Manage") {
                Button("Restore Purchases") {
                    Task { await entitlementManager.restorePurchases() }
                }

                Button("Manage Subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                }
            }

            Section("Legal") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("""
                        Payment will be charged to your Apple ID account at confirmation \
                        of purchase. Subscriptions automatically renew unless canceled at \
                        least 24 hours before the end of the current period.
                        """)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    Text("Manage or cancel anytime in App Store settings.")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    HStack(spacing: 12) {
                        if let termsURL {
                            Link("Terms of Use", destination: termsURL)
                        }
                        if let privacyURL {
                            Link("Privacy Policy", destination: privacyURL)
                        }
                    }
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.accent)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Subscription")
        .task {
            await entitlementManager.refresh()
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
}

#Preview {
    NavigationStack {
        SubscriptionSettingsView()
            .environmentObject(EntitlementManager())
    }
}
