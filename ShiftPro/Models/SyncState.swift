import Foundation

/// User-configurable calendar sync mode.
enum CalendarSyncMode: String, CaseIterable, Codable, Sendable {
    case exportOnly
    case twoWay

    var displayName: String {
        switch self {
        case .exportOnly:
            return "Export Only"
        case .twoWay:
            return "Two-Way Sync"
        }
    }
}

/// Persisted settings for calendar synchronization.
struct CalendarSyncSettings: Codable, Sendable, Equatable {
    var isEnabled: Bool
    var mode: CalendarSyncMode
    var includeAlarms: Bool
    var alarmOffsetMinutes: Int
    var lastSyncedAt: Date?
    var twoWaySyncConfirmed: Bool

    static let storageKey = "ShiftPro.CalendarSyncSettings"

    static let defaults = CalendarSyncSettings(
        isEnabled: true,
        mode: .exportOnly,
        includeAlarms: true,
        alarmOffsetMinutes: 30,
        lastSyncedAt: nil,
        twoWaySyncConfirmed: false
    )

    static func load() -> CalendarSyncSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(CalendarSyncSettings.self, from: data) else {
            return defaults
        }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: CalendarSyncSettings.storageKey)
    }

    mutating func markSynced() {
        lastSyncedAt = Date()
        save()
    }
}
