import Combine
import Foundation

/// Manages privacy settings, consent, and audit trail for law enforcement compliance
@MainActor
final class PrivacyManager: ObservableObject {
    enum PrivacyOption: String, Codable, CaseIterable {
        case cloudSync
        case crashReporting
        case usageAnalytics
        case locationServices

        var displayName: String {
            switch self {
            case .cloudSync:
                return "iCloud Sync"
            case .crashReporting:
                return "Crash Reports"
            case .usageAnalytics:
                return "Usage Analytics"
            case .locationServices:
                return "Location Services"
            }
        }

        var description: String {
            switch self {
            case .cloudSync:
                return "Sync your shift data across devices using iCloud. " +
                       "Data remains encrypted and private to your account."
            case .crashReporting:
                return "Send anonymous crash reports to help improve app stability. " +
                       "No personal shift data is included."
            case .usageAnalytics:
                return "Share anonymous usage patterns to help improve the app. " +
                       "No shift details or personal information is collected."
            case .locationServices:
                return "Enable location-based features like automatic shift detection " +
                       "and geofencing (future feature)."
            }
        }
    }

    struct AuditEntry: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let eventType: AuditEventType
        let description: String
        let userIdentifier: String?

        init(type: AuditEventType, description: String, userIdentifier: String? = nil) {
            self.id = UUID()
            self.timestamp = Date()
            self.eventType = type
            self.description = description
            self.userIdentifier = userIdentifier
        }
    }

    enum AuditEventType: String, Codable {
        case authenticationAttempt
        case authenticationSuccess
        case authenticationFailure
        case dataExport
        case dataImport
        case dataDelete
        case privacySettingChanged
        case securitySettingChanged
        case sensitiveDataAccess
    }

    @Published private(set) var privacySettings: [PrivacyOption: Bool] = [:]
    @Published private(set) var auditTrail: [AuditEntry] = []

    private let storage: SecureStorage
    private let maxAuditEntries = 1000
    private let privacySettingsKey = "privacy.settings"
    private let auditTrailKey = "privacy.auditTrail"

    init(storage: SecureStorage = SecureStorage()) {
        self.storage = storage
        loadSettings()
    }

    // MARK: - Privacy Settings

    func isEnabled(_ option: PrivacyOption) -> Bool {
        privacySettings[option] ?? false
    }

    func setEnabled(_ option: PrivacyOption, enabled: Bool) throws {
        let previousValue = privacySettings[option] ?? false

        privacySettings[option] = enabled
        try saveSettings()

        // Audit trail
        try logAudit(
            type: .privacySettingChanged,
            description: "\(option.displayName) changed from \(previousValue) to \(enabled)"
        )
    }

    // MARK: - Audit Trail

    func logAudit(type: AuditEventType, description: String, userIdentifier: String? = nil) throws {
        let entry = AuditEntry(type: type, description: description, userIdentifier: userIdentifier)

        auditTrail.insert(entry, at: 0)

        // Limit audit trail size
        if auditTrail.count > maxAuditEntries {
            auditTrail = Array(auditTrail.prefix(maxAuditEntries))
        }

        try saveAuditTrail()
    }

    func getAuditTrail(limit: Int? = nil, type: AuditEventType? = nil) -> [AuditEntry] {
        var entries = auditTrail

        if let type = type {
            entries = entries.filter { $0.eventType == type }
        }

        if let limit = limit {
            entries = Array(entries.prefix(limit))
        }

        return entries
    }

    func clearAuditTrail() throws {
        try logAudit(type: .dataDelete, description: "Audit trail cleared by user")
        auditTrail = []
        try saveAuditTrail()
    }

    // MARK: - Data Retention

    func exportAuditTrail() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(auditTrail)
    }

    func exportPrivacyReport() throws -> Data {
        let report = PrivacyReport(
            generatedAt: Date(),
            privacySettings: privacySettings,
            auditTrailCount: auditTrail.count,
            recentAudit: Array(auditTrail.prefix(100))
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    // MARK: - GDPR / CCPA Compliance

    func deleteAllUserData() throws {
        try logAudit(type: .dataDelete, description: "User requested full data deletion (GDPR/CCPA)")

        // Clear privacy settings
        privacySettings.removeAll()
        try saveSettings()

        // Clear audit trail
        auditTrail.removeAll()
        try saveAuditTrail()
    }

    // MARK: - Persistence

    private func loadSettings() {
        if let settings: [String: Bool] = try? storage.load(forKey: privacySettingsKey) {
            privacySettings = settings.reduce(into: [:]) { result, pair in
                if let option = PrivacyOption(rawValue: pair.key) {
                    result[option] = pair.value
                }
            }
        } else {
            // Default settings - conservative approach for law enforcement
            privacySettings = [
                .cloudSync: true,  // Enable iCloud by default for multi-device support
                .crashReporting: false,  // Conservative default
                .usageAnalytics: false,  // Conservative default
                .locationServices: false
            ]
        }

        if let entries: [AuditEntry] = try? storage.load(forKey: auditTrailKey) {
            auditTrail = entries
        }
    }

    private func saveSettings() throws {
        let settingsDict = privacySettings.reduce(into: [:]) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        try storage.save(settingsDict, forKey: privacySettingsKey)
    }

    private func saveAuditTrail() throws {
        try storage.save(auditTrail, forKey: auditTrailKey)
    }
}

// MARK: - Supporting Types

struct PrivacyReport: Codable {
    let generatedAt: Date
    let privacySettings: [PrivacyManager.PrivacyOption: Bool]
    let auditTrailCount: Int
    let recentAudit: [PrivacyManager.AuditEntry]
}
