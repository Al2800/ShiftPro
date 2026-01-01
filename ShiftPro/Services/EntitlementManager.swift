import Foundation
import StoreKit

enum SubscriptionTier: String, Codable, CaseIterable {
    case free
    case premium
    case enterprise

    var rank: Int {
        switch self {
        case .free:
            return 0
        case .premium:
            return 1
        case .enterprise:
            return 2
        }
    }

    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .premium:
            return "Premium"
        case .enterprise:
            return "Enterprise"
        }
    }

    var tagline: String {
        switch self {
        case .free:
            return "Core shift tracking"
        case .premium:
            return "Advanced analytics and sync"
        case .enterprise:
            return "Team-wide insights"
        }
    }
}

enum ShiftProFeature: String, CaseIterable {
    case unlimitedHistory
    case multiplePatterns
    case calendarSync
    case advancedAnalytics
    case fullExport
    case enterpriseReporting

    var requiredTier: SubscriptionTier {
        switch self {
        case .unlimitedHistory, .multiplePatterns, .calendarSync, .advancedAnalytics, .fullExport:
            return .premium
        case .enterpriseReporting:
            return .enterprise
        }
    }

    var displayName: String {
        switch self {
        case .unlimitedHistory:
            return "Unlimited history"
        case .multiplePatterns:
            return "Multiple shift patterns"
        case .calendarSync:
            return "Two-way calendar sync"
        case .advancedAnalytics:
            return "Advanced analytics"
        case .fullExport:
            return "Full exports"
        case .enterpriseReporting:
            return "Enterprise reporting"
        }
    }
}

struct SubscriptionState: Codable, Equatable {
    var tier: SubscriptionTier
    var expirationDate: Date?
    var isInGracePeriod: Bool
    var lastUpdated: Date
}

@MainActor
final class EntitlementManager: ObservableObject {
    @Published private(set) var state: SubscriptionState
    @Published private(set) var products: [Product] = []
    @Published private(set) var lastPurchaseOutcome: PurchaseOutcome?
    @Published var errorMessage: String?

    private let subscriptionManager: SubscriptionManager
    private var updatesTask: Task<Void, Never>?

    private static let cacheKey = "shiftpro.subscription.state"

    init(subscriptionManager: SubscriptionManager = .shared) {
        self.subscriptionManager = subscriptionManager
        if let cached = Self.loadCachedState() {
            state = cached
        } else {
            state = SubscriptionState(tier: .free, expirationDate: nil, isInGracePeriod: false, lastUpdated: Date())
        }

        updatesTask = Task {
            for await result in Transaction.updates {
                if case .verified = result {
                    await refresh()
                }
            }
        }

        Task {
            await refresh()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func hasAccess(to feature: ShiftProFeature) -> Bool {
        state.tier.rank >= feature.requiredTier.rank
    }

    func refresh() async {
        let entitlements = await subscriptionManager.currentEntitlements()
        let updated = ReceiptValidator.subscriptionState(from: entitlements)
        state = updated
        Self.cache(state: updated)
    }

    func loadProducts() async {
        do {
            products = try await subscriptionManager.loadProducts()
        } catch {
            errorMessage = "Unable to load subscription options."
        }
    }

    func purchase(_ product: Product) async {
        let outcome = await subscriptionManager.purchase(product)
        lastPurchaseOutcome = outcome
        switch outcome {
        case .success:
            await refresh()
        case .failed:
            errorMessage = "Purchase failed. Please try again."
        case .pending:
            errorMessage = "Purchase pending approval."
        case .userCancelled:
            errorMessage = nil
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refresh()
        } catch {
            errorMessage = "Unable to restore purchases."
        }
    }

    static func loadCachedState() -> SubscriptionState? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(SubscriptionState.self, from: data)
    }

    static func cache(state: SubscriptionState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
