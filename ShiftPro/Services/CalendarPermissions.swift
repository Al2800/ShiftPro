import EventKit
import Foundation

@MainActor
final class CalendarPermissions: ObservableObject {
    @Published private(set) var status: EKAuthorizationStatus

    private let eventStore = EKEventStore()

    init() {
        status = EKEventStore.authorizationStatus(for: .event)
    }

    var isAuthorized: Bool {
        switch status {
        case .authorized, .fullAccess:
            return true
        default:
            return false
        }
    }

    func refresh() {
        status = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
                status = granted ? .fullAccess : .denied
            } else {
                granted = try await eventStore.requestAccess(to: .event)
                status = granted ? .authorized : .denied
            }
            return granted
        } catch {
            status = .denied
            return false
        }
    }

    var statusLabel: String {
        switch status {
        case .notDetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized, .fullAccess:
            return "Granted"
        case .writeOnly:
            return "Write Only"
        @unknown default:
            return "Unknown"
        }
    }
}
