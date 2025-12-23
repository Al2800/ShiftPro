import SwiftUI
import SwiftData

@main
struct ShiftProApp: App {
    private let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainerFactory.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        BackgroundTaskManager.shared.register()
        BackgroundTaskManager.shared.scheduleAppRefresh()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
