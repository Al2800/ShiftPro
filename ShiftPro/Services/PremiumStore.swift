import Foundation
import StoreKit

// MARK: - DEPRECATED
// This class is superseded by EntitlementManager + SubscriptionManager.
// Use EntitlementManager for all subscription state management.
// Product IDs are now defined in ShiftProProductID (SubscriptionManager.swift).
// This file is retained for reference during migration but should not be used.

@available(*, deprecated, message: "Use EntitlementManager instead")
@MainActor
final class PremiumStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var entitlements: Set<PremiumEntitlement> = []
    @Published private(set) var lastErrorMessage: String?
    @Published var isLoading = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
        Task {
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: PremiumCatalog.productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Unable to load premium products."
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await handle(transaction)
                    await transaction.finish()
                    return true
                }
                lastErrorMessage = "Purchase could not be verified."
                return false
            case .pending:
                lastErrorMessage = "Purchase is pending approval."
                return false
            case .userCancelled:
                lastErrorMessage = nil
                return false
            @unknown default:
                lastErrorMessage = "Purchase failed."
                return false
            }
        } catch {
            lastErrorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = "Restore failed. Check your Apple ID and try again."
        }
    }

    func hasEntitlement(_ entitlement: PremiumEntitlement) -> Bool {
        entitlements.contains(entitlement)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await verification in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = verification {
                    await self.handle(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    private func refreshEntitlements() async {
        var updatedProductIDs = Set<String>()

        for await verification in Transaction.currentEntitlements {
            if case .verified(let transaction) = verification {
                updatedProductIDs.insert(transaction.productID)
            }
        }

        purchasedProductIDs = updatedProductIDs
        entitlements = updatedProductIDs.reduce(into: Set<PremiumEntitlement>()) { result, productID in
            result.formUnion(entitlementsForProduct(productID))
        }
    }

    private func handle(_ transaction: Transaction) async {
        purchasedProductIDs.insert(transaction.productID)
        entitlements.formUnion(entitlementsForProduct(transaction.productID))
    }

    private func entitlementsForProduct(_ productID: String) -> Set<PremiumEntitlement> {
        PremiumCatalog.products.first { $0.id == productID }?.entitlements ?? []
    }
}
