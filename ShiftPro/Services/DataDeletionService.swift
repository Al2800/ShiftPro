import EventKit
import Foundation
import SwiftData

/// Comprehensive data deletion service for GDPR/CCPA compliance.
/// Handles complete erasure of all user data including SwiftData entities,
/// UserDefaults, Keychain, and cached files.
@MainActor
final class DataDeletionService {
    /// Posted when all data has been deleted and the app should return to onboarding.
    static let dataDeletedNotification = Notification.Name("com.shiftpro.dataDeleted")
    enum DeletionError: LocalizedError {
        case modelContextRequired
        case deletionFailed(underlying: Error)
        case partialFailure(errors: [String])

        var errorDescription: String? {
            switch self {
            case .modelContextRequired:
                return "Model context is required for data deletion"
            case .deletionFailed(let error):
                return "Data deletion failed: \(error.localizedDescription)"
            case .partialFailure(let errors):
                return "Some data could not be deleted: \(errors.joined(separator: ", "))"
            }
        }
    }

    /// Result of a deletion operation with details about what was deleted
    struct DeletionResult {
        let swiftDataEntitiesDeleted: Int
        let userDefaultsKeysCleared: Int
        let keychainItemsCleared: Bool
        let tempFilesCleared: Bool
        let appGroupCleared: Bool
        let calendarDeleted: Bool
        let errors: [String]

        var isComplete: Bool { errors.isEmpty }
    }

    // MARK: - Constants

    private static let appGroupIdentifier = "group.com.shiftpro.shared"

    private static let userDefaultsKeys: [String] = [
        "hasOnboarded",
        "onboardingVersion",
        "selectedCalendarIdentifier",
        "calendarSyncSettings",
        "entitlementCache",
        "cachedWatchData"
    ]

    private static let appGroupKeys: [String] = [
        "currentShift",
        "nextShift",
        "hoursData",
        "widgetData"
    ]

    // MARK: - Public API

    /// Deletes all user data from the app, returning it to onboarding state.
    /// - Parameter modelContext: The SwiftData model context for entity deletion
    /// - Returns: A result describing what was deleted
    static func deleteAllData(modelContext: ModelContext) async throws -> DeletionResult {
        var errors: [String] = []
        var entitiesDeleted = 0

        // 1. Delete all SwiftData entities
        do {
            entitiesDeleted = try await deleteAllSwiftDataEntities(modelContext: modelContext)
        } catch {
            errors.append("SwiftData: \(error.localizedDescription)")
        }

        // 2. Clear UserDefaults
        let userDefaultsCleared = clearUserDefaults()

        // 3. Clear app group UserDefaults
        let appGroupCleared = clearAppGroupDefaults()

        // 4. Clear Keychain (SecureStorage)
        let keychainCleared = clearKeychain()
        if !keychainCleared {
            errors.append("Keychain: Some items could not be deleted")
        }

        // 5. Clear temporary files and caches
        let tempCleared = clearTemporaryFiles()

        // 6. Clear Application Support directory (except the store file which we've cleared)
        clearCachedData()

        // 7. Delete ShiftPro calendar from EventKit (best effort)
        let calendarDeleted = deleteShiftProCalendar()

        let result = DeletionResult(
            swiftDataEntitiesDeleted: entitiesDeleted,
            userDefaultsKeysCleared: userDefaultsCleared,
            keychainItemsCleared: keychainCleared,
            tempFilesCleared: tempCleared,
            appGroupCleared: appGroupCleared,
            calendarDeleted: calendarDeleted,
            errors: errors
        )

        if !result.isComplete {
            throw DeletionError.partialFailure(errors: errors)
        }

        // Notify observers that data has been deleted
        NotificationCenter.default.post(name: dataDeletedNotification, object: nil)

        return result
    }

    // MARK: - SwiftData Deletion

    private static func deleteAllSwiftDataEntities(modelContext: ModelContext) async throws -> Int {
        var totalDeleted = 0

        // Delete in order to respect relationships (children before parents)

        // 1. Delete CalendarEvents (no dependencies)
        let calendarEvents = try modelContext.fetch(FetchDescriptor<CalendarEvent>())
        for event in calendarEvents {
            modelContext.delete(event)
        }
        totalDeleted += calendarEvents.count

        // 2. Delete Shifts
        let shifts = try modelContext.fetch(FetchDescriptor<Shift>())
        for shift in shifts {
            modelContext.delete(shift)
        }
        totalDeleted += shifts.count

        // 3. Delete PayPeriods
        let payPeriods = try modelContext.fetch(FetchDescriptor<PayPeriod>())
        for payPeriod in payPeriods {
            modelContext.delete(payPeriod)
        }
        totalDeleted += payPeriods.count

        // 4. Delete RotationDays
        let rotationDays = try modelContext.fetch(FetchDescriptor<RotationDay>())
        for day in rotationDays {
            modelContext.delete(day)
        }
        totalDeleted += rotationDays.count

        // 5. Delete ShiftPatterns
        let patterns = try modelContext.fetch(FetchDescriptor<ShiftPattern>())
        for pattern in patterns {
            modelContext.delete(pattern)
        }
        totalDeleted += patterns.count

        // 6. Delete PayRulesets
        let rulesets = try modelContext.fetch(FetchDescriptor<PayRuleset>())
        for ruleset in rulesets {
            modelContext.delete(ruleset)
        }
        totalDeleted += rulesets.count

        // 7. Delete NotificationSettings
        let notificationSettings = try modelContext.fetch(FetchDescriptor<NotificationSettings>())
        for settings in notificationSettings {
            modelContext.delete(settings)
        }
        totalDeleted += notificationSettings.count

        // 8. Delete UserProfiles (parent entity, delete last)
        let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
        for profile in profiles {
            modelContext.delete(profile)
        }
        totalDeleted += profiles.count

        // Save all deletions
        try modelContext.save()

        return totalDeleted
    }

    // MARK: - UserDefaults Deletion

    private static func clearUserDefaults() -> Int {
        var clearedCount = 0

        for key in userDefaultsKeys {
            if UserDefaults.standard.object(forKey: key) != nil {
                UserDefaults.standard.removeObject(forKey: key)
                clearedCount += 1
            }
        }

        // Force synchronize
        UserDefaults.standard.synchronize()

        return clearedCount
    }

    private static func clearAppGroupDefaults() -> Bool {
        guard let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return true // No app group configured, consider it cleared
        }

        for key in appGroupKeys {
            appGroupDefaults.removeObject(forKey: key)
        }

        appGroupDefaults.synchronize()
        return true
    }

    // MARK: - Keychain Deletion

    private static func clearKeychain() -> Bool {
        let storage = SecureStorage()
        do {
            try storage.deleteAll()
            return true
        } catch {
            return false
        }
    }

    // MARK: - File System Cleanup

    private static func clearTemporaryFiles() -> Bool {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: nil
            )

            for file in contents {
                try? fileManager.removeItem(at: file)
            }

            return true
        } catch {
            return false
        }
    }

    private static func clearCachedData() {
        let fileManager = FileManager.default

        // Clear Caches directory
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            if let contents = try? fileManager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil) {
                for file in contents {
                    try? fileManager.removeItem(at: file)
                }
            }
        }

        // Clear app group container shared data
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            if let contents = try? fileManager.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil) {
                for file in contents {
                    // Skip Library folder to preserve app group preferences
                    if file.lastPathComponent != "Library" {
                        try? fileManager.removeItem(at: file)
                    }
                }
            }
        }
    }

    // MARK: - EventKit Calendar Deletion

    /// Deletes the ShiftPro calendar from EventKit if it exists.
    /// This is optional and separate from core data deletion since it requires calendar permissions.
    /// - Returns: true if the calendar was deleted or didn't exist, false if deletion failed
    static func deleteShiftProCalendar() -> Bool {
        let eventStore = EKEventStore()
        let calendarIdentifierKey = "selectedCalendarIdentifier"

        guard let identifier = UserDefaults.standard.string(forKey: calendarIdentifierKey),
              let calendar = eventStore.calendar(withIdentifier: identifier) else {
            // No calendar configured, consider it deleted
            return true
        }

        do {
            try eventStore.removeCalendar(calendar, commit: true)
            UserDefaults.standard.removeObject(forKey: calendarIdentifierKey)
            return true
        } catch {
            // Calendar deletion failed, but don't fail the overall operation
            return false
        }
    }
}
