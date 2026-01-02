import EventKit
import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var calendarStatus: PermissionStatus = .notDetermined
    @Published private(set) var notificationStatus: PermissionStatus = .notDetermined

    private let eventStore = EKEventStore()

    func refreshStatuses() async {
        calendarStatus = PermissionStatus(authorizationStatus: EKEventStore.authorizationStatus(for: .event))
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = PermissionStatus(notificationStatus: settings.authorizationStatus)
    }

    func requestCalendarAccess() async {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                let mode = CalendarSyncSettings.load().mode
                if mode == .exportOnly {
                    granted = try await eventStore.requestWriteOnlyAccessToEvents()
                } else {
                    granted = try await eventStore.requestFullAccessToEvents()
                }
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            calendarStatus = PermissionStatus(authorizationStatus: EKEventStore.authorizationStatus(for: .event))
            if !granted {
                calendarStatus = .denied
            }
        } catch {
            calendarStatus = .denied
        }
    }

    func requestNotificationAccess() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            notificationStatus = granted ? .authorized : .denied
        } catch {
            notificationStatus = .denied
        }
    }
}

enum PermissionStatus: String {
    case notDetermined
    case authorized
    case denied
    case restricted
    case writeOnly

    init(authorizationStatus: EKAuthorizationStatus) {
        switch authorizationStatus {
        case .notDetermined:
            self = .notDetermined
        case .authorized, .fullAccess:
            self = .authorized
        case .restricted:
            self = .restricted
        case .writeOnly:
            self = .writeOnly
        case .denied:
            self = .denied
        @unknown default:
            self = .notDetermined
        }
    }

    init(notificationStatus: UNAuthorizationStatus) {
        switch notificationStatus {
        case .notDetermined:
            self = .notDetermined
        case .authorized, .provisional, .ephemeral:
            self = .authorized
        case .denied:
            self = .denied
        @unknown default:
            self = .notDetermined
        }
    }

    var title: String {
        switch self {
        case .notDetermined:
            return "Not requested"
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .writeOnly:
            return "Write Only"
        }
    }

    var color: Color {
        switch self {
        case .authorized:
            return ShiftProColors.success
        case .writeOnly:
            return ShiftProColors.warning
        case .denied:
            return ShiftProColors.danger
        case .restricted:
            return ShiftProColors.warning
        case .notDetermined:
            return ShiftProColors.fog
        }
    }
}
