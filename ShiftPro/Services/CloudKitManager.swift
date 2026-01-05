import CloudKit
import Foundation
import Security

@MainActor
final class CloudKitManager: ObservableObject {
    enum Status: String, Sendable {
        case available
        case noAccount
        case restricted
        case couldNotDetermine
        case temporarilyUnavailable
        case unavailable
    }

    @Published private(set) var status: Status
    private let isCloudKitConfigured: Bool
    private var isMonitoring = false

    init() {
        let hasEntitlement = Self.hasCloudKitEntitlement()
        isCloudKitConfigured = hasEntitlement
        status = hasEntitlement ? .couldNotDetermine : .unavailable
    }

    func refreshStatus() async {
        guard isCloudKitConfigured else {
            status = .unavailable
            return
        }

        // Fetch account status on a background context to avoid potential
        // MainActor conflicts with CloudKit's internal threading
        let fetchedStatus: Status = await withCheckedContinuation { continuation in
            Task.detached {
                do {
                    let accountStatus = try await CKContainer.default().accountStatus()
                    let mappedStatus: Status
                    switch accountStatus {
                    case .available:
                        mappedStatus = .available
                    case .noAccount:
                        mappedStatus = .noAccount
                    case .restricted:
                        mappedStatus = .restricted
                    case .couldNotDetermine:
                        mappedStatus = .couldNotDetermine
                    case .temporarilyUnavailable:
                        mappedStatus = .temporarilyUnavailable
                    @unknown default:
                        mappedStatus = .couldNotDetermine
                    }
                    continuation.resume(returning: mappedStatus)
                } catch {
                    continuation.resume(returning: .couldNotDetermine)
                }
            }
        }

        // Update on MainActor
        status = fetchedStatus
    }

    func startMonitoringAccountChanges() {
        guard isCloudKitConfigured else { return }
        guard !isMonitoring else { return }
        isMonitoring = true

        // Use MainActor.run for the notification observer setup
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountChange),
            name: .CKAccountChanged,
            object: nil
        )
    }

    // @objc methods can be called from any thread by NotificationCenter.
    // Use explicit @MainActor Task to ensure proper isolation.
    @objc private func handleAccountChange() {
        Task { @MainActor [weak self] in
            await self?.refreshStatus()
        }
    }

    // Mark as nonisolated since it only uses thread-safe Security APIs
    // and doesn't access any actor-isolated state
    nonisolated private static func hasCloudKitEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let entitlementKey = "com.apple.developer.icloud-container-identifiers" as CFString
        let entitlement = SecTaskCopyValueForEntitlement(task, entitlementKey, nil)
        if let containers = entitlement as? [String] {
            return !containers.isEmpty
        }
        return entitlement != nil
    }
}
