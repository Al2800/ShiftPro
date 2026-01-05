import CloudKit
import Foundation
import Security

@MainActor
final class CloudKitManager: ObservableObject {
    enum Status: String {
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

        do {
            let accountStatus = try await CKContainer.default().accountStatus()
            switch accountStatus {
            case .available:
                status = .available
            case .noAccount:
                status = .noAccount
            case .restricted:
                status = .restricted
            case .couldNotDetermine:
                status = .couldNotDetermine
            case .temporarilyUnavailable:
                status = .temporarilyUnavailable
            @unknown default:
                status = .couldNotDetermine
            }
        } catch {
            status = .couldNotDetermine
        }
    }

    func startMonitoringAccountChanges() {
        guard isCloudKitConfigured else { return }
        guard !isMonitoring else { return }
        isMonitoring = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountChange),
            name: .CKAccountChanged,
            object: nil
        )
    }

    @objc private func handleAccountChange() {
        Task {
            await refreshStatus()
        }
    }

    private static func hasCloudKitEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let entitlementKey = "com.apple.developer.icloud-container-identifiers" as CFString
        let entitlement = SecTaskCopyValueForEntitlement(task, entitlementKey, nil)
        if let containers = entitlement as? [String] {
            return !containers.isEmpty
        }
        return entitlement != nil
    }
}
