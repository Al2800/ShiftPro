import Foundation
import SwiftData

@MainActor
protocol AbstractRepository {
    associatedtype Model: PersistentModel

    var modelContext: ModelContext { get }

    func fetch(_ descriptor: FetchDescriptor<Model>) throws -> [Model]
    func insert(_ model: Model)
    func delete(_ model: Model)
    func save() throws
}

@MainActor
extension AbstractRepository {
    func fetch(_ descriptor: FetchDescriptor<Model>) throws -> [Model] {
        try modelContext.fetch(descriptor)
    }

    func fetch(predicate: Predicate<Model>?, sortBy: [SortDescriptor<Model>]) throws -> [Model] {
        let descriptor = FetchDescriptor<Model>(predicate: predicate, sortBy: sortBy)
        return try modelContext.fetch(descriptor)
    }

    func insert(_ model: Model) {
        modelContext.insert(model)
    }

    func delete(_ model: Model) {
        modelContext.delete(model)
    }

    func save() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }
}
