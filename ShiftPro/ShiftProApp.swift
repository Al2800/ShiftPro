import SwiftUI
import SwiftData
import UIKit

@main
struct ShiftProApp: App {
    let sharedModelContainer: ModelContainer
    @StateObject private var notificationManager: NotificationManager
    @StateObject private var entitlementManager = EntitlementManager()

    init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        if isUITest {
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            if ProcessInfo.processInfo.arguments.contains("-reduce-motion") {
                UIView.setAnimationsEnabled(false)
            }
        }

        do {
            let container = try ModelContainerFactory.makeContainer()
            sharedModelContainer = container
            _notificationManager = StateObject(
                wrappedValue: NotificationManager(context: container.mainContext)
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        if !isUITest {
            BackgroundTaskManager.shared.register()
            BackgroundTaskManager.shared.scheduleAppRefresh()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    try? await notificationManager.rescheduleUpcomingShifts()
                }
                .environmentObject(entitlementManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
