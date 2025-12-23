import Foundation
import UserNotifications

@MainActor
final class NotificationPermissions: ObservableObject {
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined

    func refresh() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            status = settings.authorizationStatus
        }
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound, .timeSensitive])
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            status = settings.authorizationStatus
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
        case .denied:
            return "Denied"
        case .authorized:
            return "Granted"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Temporary"
        @unknown default:
            return "Unknown"
        }
    }
}
