import Foundation
import SwiftData

/// Repository for managing ShiftPattern entities
final class PatternRepository: AbstractRepository {
    typealias ModelType = ShiftPattern

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Fetches all active (non-deleted) patterns
    func fetchActive() throws -> [ShiftPattern] {
        let predicate = #Predicate<ShiftPattern> { pattern in
            pattern.deletedAt == nil && pattern.isActive
        }
        return try fetch(predicate: predicate, sortBy: [ShiftPattern.byNameAscending])
    }

    /// Fetches patterns for a specific user
    func fetchForUser(_ profile: UserProfile) throws -> [ShiftPattern] {
        let profileId = profile.id
        let predicate = #Predicate<ShiftPattern> { pattern in
            pattern.deletedAt == nil && pattern.owner?.id == profileId
        }
        return try fetch(predicate: predicate, sortBy: [ShiftPattern.byNameAscending])
    }

    /// Fetches active patterns for a specific user
    func fetchActiveForUser(_ profile: UserProfile) throws -> [ShiftPattern] {
        let profileId = profile.id
        let predicate = #Predicate<ShiftPattern> { pattern in
            pattern.deletedAt == nil && pattern.isActive && pattern.owner?.id == profileId
        }
        return try fetch(predicate: predicate, sortBy: [ShiftPattern.byNameAscending])
    }

    /// Creates and saves a new pattern
    func add(_ pattern: ShiftPattern) throws {
        insert(pattern)
        try save()
    }

    /// Updates a pattern
    func update(_ pattern: ShiftPattern) throws {
        // Pattern is already tracked, just save
        try save()
    }

    /// Soft deletes a pattern
    func softDelete(_ pattern: ShiftPattern) throws {
        pattern.softDelete()
        try save()
    }

    /// Restores a soft-deleted pattern
    func restore(_ pattern: ShiftPattern) throws {
        pattern.restore()
        try save()
    }

    /// Toggles the active state of a pattern
    func toggleActive(_ pattern: ShiftPattern) throws {
        pattern.isActive.toggle()
        try save()
    }

    /// Duplicates a pattern with a new name
    func duplicate(_ pattern: ShiftPattern, newName: String) throws -> ShiftPattern {
        let newPattern = ShiftPattern(
            name: newName,
            notes: pattern.notes,
            scheduleType: pattern.scheduleType,
            startMinuteOfDay: pattern.startMinuteOfDay,
            durationMinutes: pattern.durationMinutes,
            daysOfWeekMask: pattern.daysOfWeekMask,
            cycleStartDate: pattern.cycleStartDate,
            isActive: true,
            colorHex: pattern.colorHex,
            isSystem: false
        )
        newPattern.owner = pattern.owner

        // Copy rotation days for cycling patterns
        if pattern.scheduleType == .cycling {
            for day in pattern.rotationDays {
                let newDay = RotationDay(
                    index: day.index,
                    isWorkDay: day.isWorkDay,
                    shiftName: day.shiftName,
                    startMinuteOfDay: day.startMinuteOfDay,
                    durationMinutes: day.durationMinutes
                )
                newDay.pattern = newPattern
                context.insert(newDay)
            }
        }

        insert(newPattern)
        try save()
        return newPattern
    }
}
