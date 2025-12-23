import Foundation
import SwiftData

/// Tracks the synchronization state between a Shift and an iOS Calendar event.
/// Stores EventKit identifiers for maintaining the link.
@Model
final class CalendarEvent {
    // MARK: - Primary Key
    @Attribute(.unique) var id: UUID

    // MARK: - EventKit Identifiers
    /// The EventKit event identifier (EKEvent.eventIdentifier)
    var eventIdentifier: String

    /// The calendar identifier where the event is stored
    var calendarIdentifier: String

    // MARK: - Sync Tracking
    /// Last known modification date of the calendar event
    var lastEventModified: Date?

    /// When we last synced this event
    var lastSyncDate: Date

    /// Raw value for CalendarSyncState enum
    var syncStateRaw: Int16

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var shift: Shift?

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        eventIdentifier: String,
        calendarIdentifier: String,
        lastEventModified: Date? = nil,
        lastSyncDate: Date = Date(),
        syncState: CalendarSyncState = .synced,
        shift: Shift? = nil
    ) {
        self.id = id
        self.eventIdentifier = eventIdentifier
        self.calendarIdentifier = calendarIdentifier
        self.lastEventModified = lastEventModified
        self.lastSyncDate = lastSyncDate
        self.syncStateRaw = syncState.rawValue
        self.shift = shift
    }
}

// MARK: - Computed Properties
extension CalendarEvent {
    /// The sync state enum value
    var syncState: CalendarSyncState {
        get { CalendarSyncState(rawValue: syncStateRaw) ?? .localOnly }
        set { syncStateRaw = newValue.rawValue }
    }

    /// Whether this event is successfully synced
    var isSynced: Bool {
        syncState == .synced
    }

    /// Whether this event needs to be updated
    var needsUpdate: Bool {
        syncState == .needsUpdate
    }

    /// Whether sync has failed
    var syncFailed: Bool {
        syncState == .failed
    }

    /// Whether a conflict was detected
    var hasConflict: Bool {
        syncState == .conflictDetected
    }

    /// Time since last sync
    var timeSinceLastSync: TimeInterval {
        Date().timeIntervalSince(lastSyncDate)
    }

    /// Human-readable sync status
    var syncStatusDescription: String {
        switch syncState {
        case .localOnly:
            return "Not synced to calendar"
        case .synced:
            return "In sync"
        case .needsUpdate:
            return "Pending sync"
        case .failed:
            return "Sync failed"
        case .conflictDetected:
            return "Conflict detected"
        }
    }

    /// Deep link URL for opening the event in Calendar app
    var calendarDeepLink: URL? {
        // Format: calshow:<timestamp>
        guard let shift = shift else { return nil }
        let timestamp = shift.scheduledStart.timeIntervalSinceReferenceDate
        return URL(string: "calshow:\(timestamp)")
    }
}

// MARK: - Convenience Methods
extension CalendarEvent {
    /// Marks the event as synced
    func markSynced(eventModified: Date? = nil) {
        syncState = .synced
        lastSyncDate = Date()
        if let modified = eventModified {
            lastEventModified = modified
        }
    }

    /// Marks the event as needing update
    func markNeedsUpdate() {
        syncState = .needsUpdate
    }

    /// Marks the sync as failed
    func markFailed() {
        syncState = .failed
        lastSyncDate = Date()
    }

    /// Marks a conflict for manual resolution
    func markConflict() {
        syncState = .conflictDetected
        lastSyncDate = Date()
    }

    /// Resets sync state to local only
    func resetToLocalOnly() {
        syncState = .localOnly
        lastEventModified = nil
    }

    /// Updates the event identifier (after recreation)
    func updateEventIdentifier(_ newIdentifier: String) {
        eventIdentifier = newIdentifier
        lastSyncDate = Date()
    }

    /// Checks if the calendar event might have been modified externally
    func mightHaveExternalChanges(currentEventModified: Date) -> Bool {
        guard let lastModified = lastEventModified else { return true }
        return currentEventModified > lastModified
    }
}

// MARK: - Factory Methods
extension CalendarEvent {
    /// Creates a new calendar event link for a shift
    static func createLink(
        for shift: Shift,
        eventIdentifier: String,
        calendarIdentifier: String
    ) -> CalendarEvent {
        CalendarEvent(
            eventIdentifier: eventIdentifier,
            calendarIdentifier: calendarIdentifier,
            lastSyncDate: Date(),
            syncState: .synced,
            shift: shift
        )
    }

    /// Creates a placeholder for a pending sync
    static func pendingSync(
        for shift: Shift,
        calendarIdentifier: String
    ) -> CalendarEvent {
        CalendarEvent(
            eventIdentifier: "", // Will be set after sync
            calendarIdentifier: calendarIdentifier,
            syncState: .needsUpdate,
            shift: shift
        )
    }
}
