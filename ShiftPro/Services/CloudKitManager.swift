import CloudKit
import Foundation

@MainActor
final class CloudKitManager: ObservableObject {
    enum Status: String {
        case available
        case noAccount
        case restricted
        case couldNotDetermine
        case temporarilyUnavailable
    }

    @Published private(set) var status: Status = .couldNotDetermine

    func refreshStatus() async {
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
}
