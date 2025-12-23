import BackgroundTasks
import Foundation
import SwiftData

@MainActor
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    static let refreshIdentifier = "com.shiftpro.refresh"

    private var isRegistered = false

    private init() {}

    func register() {
        guard !isRegistered else { return }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task {
                await self.handleAppRefresh(refreshTask)
            }
        }

        isRegistered = true
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Best-effort scheduling; background refresh can be retried later.
        }
    }

    private func handleAppRefresh(_ task: BGAppRefreshTask) async {
        scheduleAppRefresh()

        let success = await performRefreshWork()
        task.setTaskCompleted(success: success)
    }

    private func performRefreshWork() async -> Bool {
        do {
            let container = try ModelContainerFactory.makeContainer(cloudSyncEnabled: false)
            let context = container.mainContext

            let notificationManager = NotificationManager(context: context)
            try await notificationManager.rescheduleUpcomingShifts()

            let profileRepository = UserProfileRepository(context: context)
            if let profile = try? profileRepository.fetchPrimary() {
                let calculator = HoursCalculator()
                let engine = PayPeriodEngine(context: context, calculator: calculator)
                try? engine.recalculateAll(for: profile, baseRateCents: profile.baseRateCents)
            }

            return true
        } catch {
            return false
        }
    }
}
