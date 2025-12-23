import SwiftUI
import SwiftData

@main
struct ShiftProApp: App {
    let sharedModelContainer: ModelContainer
    @StateObject private var notificationManager: NotificationManager

    init() {
        do {
            let container = try ModelContainerFactory.makeContainer()
            sharedModelContainer = container
            _notificationManager = StateObject(
                wrappedValue: NotificationManager(context: container.mainContext)
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        BackgroundTaskManager.shared.register()
        BackgroundTaskManager.shared.scheduleAppRefresh()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    try? await notificationManager.rescheduleUpcomingShifts()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
