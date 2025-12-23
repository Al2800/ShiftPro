import Foundation

// MARK: - DEPRECATED
// Use ShiftProFeature (in EntitlementManager.swift) for feature access checks.
// Use ShiftProProductID (in SubscriptionManager.swift) for product identifiers.
// This file is retained for reference during migration.

@available(*, deprecated, message: "Use ShiftProFeature instead")
enum PremiumEntitlement: String, CaseIterable, Hashable {
    case advancedAnalytics
    case unlimitedPatterns
    case smartExports
    case calendarSync
    case premiumWidgets
    case teamRoster
    case premiumSubscription
}

struct PremiumFeature: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let entitlements: Set<PremiumEntitlement>
}

enum PremiumCatalog {
    static let products: [PremiumFeature] = [
        PremiumFeature(
            id: "com.shiftpro.premium.monthly",
            title: "ShiftPro Premium Monthly",
            description: "Unlock premium analytics, advanced patterns, and priority sync.",
            entitlements: [.premiumSubscription, .advancedAnalytics, .unlimitedPatterns, .smartExports, .premiumWidgets]
        ),
        PremiumFeature(
            id: "com.shiftpro.premium.yearly",
            title: "ShiftPro Premium Yearly",
            description: "Best value for teams with analytics, export automation, and widgets.",
            entitlements: [.premiumSubscription, .advancedAnalytics, .unlimitedPatterns, .smartExports, .premiumWidgets]
        ),
        PremiumFeature(
            id: "com.shiftpro.pro.analytics",
            title: "Advanced Analytics Pack",
            description: "Trend insights, overtime risk forecasting, and export automation.",
            entitlements: [.advancedAnalytics, .smartExports]
        ),
        PremiumFeature(
            id: "com.shiftpro.pro.patterns",
            title: "Unlimited Patterns",
            description: "Build custom rotations and multi-week rosters without limits.",
            entitlements: [.unlimitedPatterns]
        ),
        PremiumFeature(
            id: "com.shiftpro.pro.exports",
            title: "Smart Export Suite",
            description: "One-tap PDF, CSV, and calendar sharing with officer notes.",
            entitlements: [.smartExports]
        )
    ]

    static let productIDs = products.map { $0.id }
}
