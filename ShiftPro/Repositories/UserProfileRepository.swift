import Foundation
import SwiftData

@MainActor
final class UserProfileRepository: AbstractRepository {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchActiveProfile() throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try fetch(descriptor).first
    }

    func ensureProfile() throws -> UserProfile {
        if let profile = try fetchActiveProfile() {
            return profile
        }
        return try createProfile()
    }

    func createProfile(
        badgeNumber: String? = nil,
        department: String? = nil,
        rank: String? = nil
    ) throws -> UserProfile {
        let profile = UserProfile(
            badgeNumber: badgeNumber,
            department: department,
            rank: rank
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
