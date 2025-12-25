import EventKit
import Foundation

struct ConflictResolver {
    enum Decision {
        case useShift
        case useEvent
        case conflict
        case noAction
    }

    func resolve(shift: Shift, event: EKEvent, lastSyncDate: Date?) -> Decision {
        let eventModified = event.lastModifiedDate ?? event.creationDate ?? event.startDate ?? Date.distantPast
        let shiftUpdated = shift.updatedAt

        if let lastSyncDate = lastSyncDate {
            let shiftChanged = shiftUpdated > lastSyncDate
            let eventChanged = eventModified > lastSyncDate
            if shiftChanged && eventChanged {
                return .conflict
            }
        }

        if eventModified > shiftUpdated {
            return .useEvent
        }
        if shiftUpdated > eventModified {
            return .useShift
        }
        return .noAction
    }
}
