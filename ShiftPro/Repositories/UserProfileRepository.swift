import Foundation
import SwiftData

@MainActor
final class UserProfileRepository: AbstractRepository {
    typealias Model = UserProfile
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    convenience init(context: ModelContext) {
        self.init(modelContext: context)
    }

    func fetchActiveProfile() throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try fetch(descriptor).first
    }

    func fetchPrimary() throws -> UserProfile? {
        try fetchActiveProfile()
    }

    func ensureProfile() throws -> UserProfile {
        if let profile = try fetchActiveProfile() {
            return profile
        }
        return try createProfile()
    }

    func ensurePrimary() throws -> UserProfile {
        try ensureProfile()
    }

    func createProfile(
        employeeId: String? = nil,
        workplace: String? = nil,
        jobTitle: String? = nil
    ) throws -> UserProfile {
        let profile = UserProfile(
            employeeId: employeeId,
            workplace: workplace,
            jobTitle: jobTitle
        )
        insert(profile)
        try save()
        return profile
    }

    func update(_ profile: UserProfile) throws {
        profile.markUpdated()
        try save()
    }
}
