import Foundation
import SwiftData

@MainActor
final class ShiftRepository: AbstractRepository {
    typealias Model = Shift
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    convenience init(context: ModelContext) {
        self.init(modelContext: context)
    }

    func fetchShifts(
        in dateRange: DateInterval,
        includeDeleted: Bool = false
    ) throws -> [Shift] {
        let predicate = #Predicate<Shift> { shift in
            shift.scheduledStart >= dateRange.start && shift.scheduledStart <= dateRange.end
        }
        var descriptor = FetchDescriptor<Shift>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.scheduledStart, order: .forward)]
        let results = try fetch(descriptor)
        if includeDeleted {
            return results
        }
        return results.filter { $0.deletedAt == nil }
    }

    func fetchUpcoming(limit: Int = 10) throws -> [Shift] {
        let now = Date()
        let predicate = #Predicate<Shift> { shift in
            shift.scheduledStart >= now && shift.deletedAt == nil
        }
        var descriptor = FetchDescriptor<Shift>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.scheduledStart, order: .forward)]
        descriptor.fetchLimit = limit
        return try fetch(descriptor)
    }

    func fetchToday() throws -> [Shift] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        return try fetchShifts(in: DateInterval(start: startOfDay, end: endOfDay))
    }

    func fetchRange(from startDate: Date, to endDate: Date) throws -> [Shift] {
        try fetchShifts(in: DateInterval(start: startDate, end: endDate))
    }

    func fetch(id: UUID) throws -> Shift? {
        let targetID = id
        let predicate = #Predicate<Shift> { shift in
            shift.id == targetID
        }
        var descriptor = FetchDescriptor<Shift>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }

    func add(_ shift: Shift) throws {
        insert(shift)
        try save()
    }

    func createShift(
        scheduledStart: Date,
        scheduledEnd: Date,
        owner: UserProfile?
    ) throws -> Shift {
        let shift = Shift(
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            owner: owner
        )
        insert(shift)
        try save()
        return shift
    }

    func update(_ shift: Shift) throws {
        shift.markUpdated()
        try save()
    }

    func softDelete(_ shift: Shift) throws {
        shift.deletedAt = Date()
        shift.markUpdated()
        try save()
    }
}
