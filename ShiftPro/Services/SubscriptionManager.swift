import StoreKit

enum ShiftProProductID {
    // Subscription products
    static let premiumMonthly = "com.shiftpro.premium.monthly"
    static let premiumYearly = "com.shiftpro.premium.yearly"
    static let enterpriseMonthly = "com.shiftpro.enterprise.monthly"

    // One-time purchases (legacy/add-ons)
    static let analyticsAddon = "com.shiftpro.pro.analytics"
    static let patternsAddon = "com.shiftpro.pro.patterns"
    static let exportsAddon = "com.shiftpro.pro.exports"

    static let subscriptions = [premiumMonthly, premiumYearly, enterpriseMonthly]
    static let addons = [analyticsAddon, patternsAddon, exportsAddon]
    static let all = subscriptions + addons
}

enum PurchaseOutcome: Equatable {
    case success
    case pending
    case userCancelled
    case failed
}

actor SubscriptionManager {
    static let shared = SubscriptionManager()

    private(set) var products: [Product] = []

    func loadProducts() async throws -> [Product] {
        let loaded = try await Product.products(for: ShiftProProductID.all)
        let sorted = loaded.sorted { $0.price < $1.price }
        products = sorted
        return sorted
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .success
                case .unverified:
                    return .failed
                }
            case .pending:
                return .pending
            case .userCancelled:
                return .userCancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    func currentEntitlements() async -> [Transaction] {
        var transactions: [Transaction] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                transactions.append(transaction)
            }
        }
        return transactions
    }
}
