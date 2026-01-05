import CloudKit
import Foundation

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

    // Check if CloudKit is configured by looking for iCloud container identifiers
    // in the app's entitlements via the embedded provisioning profile or Info.plist
    nonisolated private static func hasCloudKitEntitlement() -> Bool {
        // Check if the app has CloudKit container identifiers configured
        // by checking the ubiquity container identifiers in Info.plist
        if let containers = Bundle.main.object(forInfoDictionaryKey: "NSUbiquitousContainers") as? [String: Any],
           !containers.isEmpty {
            return true
        }

        // Also check for legacy iCloud container identifiers
        if let containerID = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.icloud-container-identifiers") as? [String],
           !containerID.isEmpty {
            return true
        }

        // Fallback: assume CloudKit is available and let errors be handled gracefully
        // This allows the app to work in development/simulator where entitlements may not be present
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
