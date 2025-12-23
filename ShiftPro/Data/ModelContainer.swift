import Foundation
import SwiftData

enum ModelContainerFactory {
    static func makeContainer(
        cloudSyncEnabled: Bool = true,
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            let storeURL = try storeLocationURL()
            let database: ModelConfiguration.CloudKitDatabase? = cloudSyncEnabled ? .automatic : nil
            configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: database)
        }

        do {
            return try ModelContainer(
                for: UserProfile.self,
                ShiftPattern.self,
                RotationDay.self,
                Shift.self,
                PayPeriod.self,
                PayRuleset.self,
                CalendarEvent.self,
                NotificationSettings.self,
                configurations: configuration
            )
        } catch {
            if cloudSyncEnabled && !inMemory {
                let fallback = ModelConfiguration(url: try storeLocationURL(), cloudKitDatabase: nil)
                return try ModelContainer(
                    for: UserProfile.self,
                    ShiftPattern.self,
                    RotationDay.self,
                    Shift.self,
                    PayPeriod.self,
                    PayRuleset.self,
                    CalendarEvent.self,
                    NotificationSettings.self,
                    configurations: fallback
                )
            }
            throw error
        }
    }

    @MainActor
    static func previewContainer() throws -> ModelContainer {
        let container = try makeContainer(cloudSyncEnabled: false, inMemory: true)
        let context = container.mainContext

        let profile = UserProfile(
            badgeNumber: "1234",
            department: "Metro Police",
            rank: "Sergeant",
            baseRateCents: 3500,
            regularHoursPerPay: 80
        )
        context.insert(profile)

        let pattern = ShiftPattern.standard9to5(owner: profile)
        pattern.owner = profile
        context.insert(pattern)

        let today = Date()
        let shift = Shift.fromPattern(pattern, on: today, owner: profile)
        context.insert(shift)

        let notificationSettings = NotificationSettings(owner: profile)
        context.insert(notificationSettings)

        return container
    }

    private static func storeLocationURL() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let storeURL = appSupport.appendingPathComponent("ShiftPro.store")

        try FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true,
            attributes: nil
        )

        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: appSupport.path
        )

        return storeURL
    }
}
