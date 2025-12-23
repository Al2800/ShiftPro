import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastScheduleDate: Date?

    private let center = UNUserNotificationCenter.current()
    private let context: ModelContext
    private let shiftRepository: ShiftRepository
    private let profileRepository: UserProfileRepository
    private let scheduler = NotificationScheduler()
    private let calculator = HoursCalculator()
    private let periodEngine: PayPeriodEngine

    init(context: ModelContext) {
        self.context = context
        self.shiftRepository = ShiftRepository(context: context)
        self.profileRepository = UserProfileRepository(context: context)
        self.periodEngine = PayPeriodEngine(context: context, calculator: calculator)
        super.init()
        center.delegate = self
        NotificationScheduler.registerCategories(center: center)
        Task { await refreshAuthorizationStatus() }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound, .timeSensitive]
            )
            await refreshAuthorizationStatus()
            return granted
        } catch {
            authorizationStatus = .denied
            return false
        }
    }

    func rescheduleUpcomingShifts(lookaheadDays: Int = 30) async throws {
        let settings = NotificationSettings.load()
        await refreshAuthorizationStatus()

        guard settings.isEnabled,
              authorizationStatus == .authorized
                || authorizationStatus == .provisional
                || authorizationStatus == .ephemeral else {
            await removeAllShiftNotifications()
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: lookaheadDays, to: now) ?? now
        let shifts = try shiftRepository.fetchShifts(in: DateInterval(start: now, end: end))

        let requests = scheduler.requests(for: shifts, settings: settings, now: now, calendar: calendar)
        await removeAllShiftNotifications()
        for request in requests {
            try await center.add(request)
        }

        if let summaryRequest = scheduler.weeklySummaryRequest(settings: settings, calendar: calendar, now: now) {
            center.removePendingNotificationRequests(withIdentifiers: [NotificationScheduler.weeklySummaryIdentifier])
            try await center.add(summaryRequest)
        }

        lastScheduleDate = Date()
    }

    func scheduleNotifications(for shift: Shift) async throws {
        let settings = NotificationSettings.load()
        await refreshAuthorizationStatus()

        guard settings.isEnabled,
              authorizationStatus == .authorized
                || authorizationStatus == .provisional
                || authorizationStatus == .ephemeral else { return }

        let requests = scheduler.requests(for: [shift], settings: settings, now: Date())
        let identifiers = requests.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        for request in requests {
            try await center.add(request)
        }
        lastScheduleDate = Date()
    }

    func cancelNotifications(for shift: Shift) {
        let identifiers = [
            NotificationScheduler.shiftStartIdentifier(shift.id),
            NotificationScheduler.shiftEndIdentifier(shift.id)
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func removeAllShiftNotifications() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(NotificationScheduler.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func handleAction(_ identifier: String, shiftID: UUID) async {
        guard let shift = try? shiftRepository.fetch(id: shiftID) else { return }

        switch identifier {
        case NotificationActionIdentifier.startShift:
            shift.clockIn(at: Date())
            try? shiftRepository.update(shift)
        case NotificationActionIdentifier.completeShift:
            shift.clockOut(at: Date())
            calculator.updateCalculatedFields(for: shift)
            try? shiftRepository.update(shift)
            if let period = shift.payPeriod {
                let baseRate = shift.owner?.baseRateCents
                calculator.updatePayPeriod(period, baseRateCents: baseRate)
                try? context.save()
            } else if let owner = shift.owner {
                try? periodEngine.assignToPeriod(shift, type: owner.payPeriodType)
            }
        case NotificationActionIdentifier.snooze15:
            let settings = NotificationSettings.load()
            let calendar = Calendar.current
            let newDate = calendar.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            let adjustedDate = scheduler.adjustedDate(newDate, settings: settings, calendar: calendar)
            if adjustedDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Shift starts soon"
                content.body = "Snoozed reminder for \(shift.timeRangeFormatted)."
                content.sound = .default
                content.categoryIdentifier = NotificationCategory.shiftStart.rawValue
                content.userInfo = [
                    "shiftID": shift.id.uuidString,
                    "type": "shiftStart"
                ]

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: adjustedDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let snoozeRequest = UNNotificationRequest(
                    identifier: NotificationScheduler.shiftStartIdentifier(shift.id),
                    content: content,
                    trigger: trigger
                )
                try? await center.add(snoozeRequest)
            }
        default:
            break
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let shiftIDString = response.notification.request.content.userInfo["shiftID"] as? String,
              let shiftID = UUID(uuidString: shiftIDString) else {
            completionHandler()
            return
        }

        Task {
            await handleAction(response.actionIdentifier, shiftID: shiftID)
            completionHandler()
        }
    }
}
