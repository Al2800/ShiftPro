import Foundation
import StoreKit

enum ReceiptValidator {
    static func subscriptionState(from transactions: [Transaction], now: Date = Date()) -> SubscriptionState {
        let active = transactions
            .filter { $0.revocationDate == nil }
            .filter { $0.expirationDate == nil || $0.expirationDate ?? now > now }

        let activeTier = active
            .map { Self.tier(for: $0.productID) }
            .max(by: { (a: SubscriptionTier, b: SubscriptionTier) in a.rank < b.rank }) ?? .free

        let expiration = active
            .filter { Self.tier(for: $0.productID) == activeTier }
            .compactMap(
                \Transaction.expirationDate
            )
            .sorted(by: >)
            .first

        return SubscriptionState(
            tier: activeTier,
            expirationDate: expiration,
            isInGracePeriod: false,
            lastUpdated: now
        )
    }

    private static func tier(for productID: String) -> SubscriptionTier {
        switch productID {
        case ShiftProProductID.enterpriseMonthly:
            return .enterprise
        case ShiftProProductID.premiumMonthly,
             ShiftProProductID.premiumYearly,
             ShiftProProductID.analyticsAddon,
             ShiftProProductID.patternsAddon,
             ShiftProProductID.exportsAddon:
            return .premium
        default:
            return .free
        }
    }
}
