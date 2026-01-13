import OSLog
import SwiftData
import SwiftUI
import UIKit

// MARK: - Appearance Mode
enum AppearanceMode: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct ShiftProApp: App {
    private let sharedModelContainer: ModelContainer?
    private let logger = Logger(subsystem: "com.shiftpro", category: "App")
    @State private var notificationManager: NotificationManager?
    @StateObject private var entitlementManager = EntitlementManager()
    @AppStorage("appearanceMode") private var appearanceMode: Int = AppearanceMode.dark.rawValue

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
            _notificationManager = State(initialValue: NotificationManager(context: container.mainContext))
        } catch {
            logger.error("Failed to create ModelContainer: \(error.localizedDescription, privacy: .public)")
            let fallback = try? ModelContainerFactory.makeContainer(cloudSyncEnabled: false, inMemory: true)
            sharedModelContainer = fallback
            if let fallback {
                _notificationManager = State(initialValue: NotificationManager(context: fallback.mainContext))
            } else {
                _notificationManager = State(initialValue: nil)
            }
        }

        if !isUITest {
            BackgroundTaskManager.shared.register()
            BackgroundTaskManager.shared.scheduleAppRefresh()
        }
    }

    var body: some Scene {
        WindowGroup {
            if let sharedModelContainer {
                ContentView()
                    .task {
                        try? await notificationManager?.rescheduleUpcomingShifts()
                    }
                    .environmentObject(entitlementManager)
                    .modelContainer(sharedModelContainer)
                    .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
            } else {
                StorageUnavailableView()
            }
        }
    }
}

private struct StorageUnavailableView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(ShiftProColors.warning)
            Text("Storage Unavailable")
                .font(ShiftProTypography.headline)
            Text("ShiftPro could not load its data store. Please restart the app or reinstall if the issue persists.")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding()
    }
}
