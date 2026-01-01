import EventKit
import Foundation
import SwiftData
import UIKit

@MainActor
final class CalendarIntegrationService: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    @Published private(set) var lastSyncDate: Date?

    private let eventStore = EKEventStore()
    private let context: ModelContext
    private let shiftRepository: ShiftRepository
    private let conflictResolver = ConflictResolver()

    private let calendarIdentifierKey = "ShiftPro.CalendarIdentifier"

    init(context: ModelContext) {
        self.context = context
        self.shiftRepository = ShiftRepository(context: context)
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Permissions

    func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
                authorizationStatus = granted ? .fullAccess : .denied
            } else {
                granted = try await eventStore.requestAccess(to: .event)
                authorizationStatus = granted ? .authorized : .denied
            }
            return granted
        } catch {
            authorizationStatus = .denied
            return false
        }
    }

    private func ensureAuthorized() throws {
        switch authorizationStatus {
        case .authorized, .fullAccess:
            return
        default:
            throw DataError.permissionDenied
        }
    }

    // MARK: - Calendar Setup

    func ensureShiftCalendar() throws -> EKCalendar {
        if let identifier = UserDefaults.standard.string(forKey: calendarIdentifierKey),
           let calendar = eventStore.calendar(withIdentifier: identifier) {
            return calendar
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "ShiftPro Shifts"
        calendar.cgColor = UIColor(ShiftProColors.accent).cgColor
        calendar.source = try preferredCalendarSource()

        try eventStore.saveCalendar(calendar, commit: true)
        UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdentifierKey)
        return calendar
    }

    private func preferredCalendarSource() throws -> EKSource {
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            return defaultSource
        }
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            return localSource
        }
        if let firstSource = eventStore.sources.first {
            return firstSource
        }
        throw DataError.invalidState("No calendar source available.")
    }

    // MARK: - Sync

    func syncShifts(in dateRange: DateInterval) async throws {
        let settings = CalendarSyncSettings.load()
        guard settings.isEnabled else { return }

        refreshAuthorizationStatus()
        try ensureAuthorized()

        let calendar = try ensureShiftCalendar()
        let shifts = try shiftRepository.fetchShifts(in: dateRange)

        for shift in shifts {
            try syncShift(shift, calendar: calendar, settings: settings)
        }

        if settings.mode == .twoWay {
            try pullCalendarChanges(calendar: calendar, dateRange: dateRange, settings: settings)
        }

        lastSyncDate = Date()
        var updatedSettings = settings
        updatedSettings.markSynced()
    }

    func syncShift(_ shift: Shift) async throws {
        let settings = CalendarSyncSettings.load()
        guard settings.isEnabled else { return }

        refreshAuthorizationStatus()
        try ensureAuthorized()

        let calendar = try ensureShiftCalendar()
        try syncShift(shift, calendar: calendar, settings: settings)
        lastSyncDate = Date()
    }

    private func syncShift(_ shift: Shift, calendar: EKCalendar, settings: CalendarSyncSettings) throws {
        if let calendarEvent = shift.calendarEvent,
           !calendarEvent.eventIdentifier.isEmpty,
           let event = eventStore.event(withIdentifier: calendarEvent.eventIdentifier) {
            let decision = conflictResolver.resolve(
                shift: shift,
                event: event,
                lastSyncDate: calendarEvent.lastSyncDate
            )

            switch decision {
            case .conflict:
                calendarEvent.markConflict()
                try context.save()
                return
            case .useEvent:
                if settings.mode == .twoWay {
                    EventMapper.updateShift(shift, from: event)
                    calendarEvent.markSynced(eventModified: event.lastModifiedDate)
                    try context.save()
                    return
                }
            case .noAction:
                calendarEvent.markSynced(eventModified: event.lastModifiedDate)
            case .useShift:
                break
            }

            EventMapper.apply(
                shift: shift,
                to: event,
                calendar: calendar,
                includeAlarms: settings.includeAlarms,
                alarmOffsetMinutes: settings.alarmOffsetMinutes
            )
            try eventStore.save(event, span: .thisEvent)
            calendarEvent.markSynced(eventModified: event.lastModifiedDate)
            try context.save()
            return
        }

        // Event missing, create new
        let event = EKEvent(eventStore: eventStore)
        EventMapper.apply(
            shift: shift,
            to: event,
            calendar: calendar,
            includeAlarms: settings.includeAlarms,
            alarmOffsetMinutes: settings.alarmOffsetMinutes
        )
        try eventStore.save(event, span: .thisEvent)

        let calendarEvent = CalendarEvent(
            eventIdentifier: event.eventIdentifier ?? "",
            calendarIdentifier: calendar.calendarIdentifier,
            lastEventModified: event.lastModifiedDate,
            lastSyncDate: Date(),
            syncState: .synced,
            shift: shift
        )
        context.insert(calendarEvent)
        shift.calendarEvent = calendarEvent
        try context.save()
    }

    func removeShift(_ shift: Shift) throws {
        refreshAuthorizationStatus()
        try ensureAuthorized()

        guard let calendarEvent = shift.calendarEvent,
              !calendarEvent.eventIdentifier.isEmpty,
              let event = eventStore.event(withIdentifier: calendarEvent.eventIdentifier) else {
            return
        }
        try eventStore.remove(event, span: .thisEvent)
        calendarEvent.syncState = .localOnly
        calendarEvent.lastSyncDate = Date()
        try context.save()
    }

    private func pullCalendarChanges(
        calendar: EKCalendar,
        dateRange: DateInterval,
        settings: CalendarSyncSettings
    ) throws {
        let predicate = eventStore.predicateForEvents(
            withStart: dateRange.start,
            end: dateRange.end,
            calendars: [calendar]
        )
        let events = eventStore.events(matching: predicate)

        for event in events {
            guard let shiftID = EventMapper.shiftID(from: event) else { continue }
            guard let shift = try shiftRepository.fetch(id: shiftID) else { continue }

            let calendarEvent = shift.calendarEvent
            let decision = conflictResolver.resolve(
                shift: shift,
                event: event,
                lastSyncDate: calendarEvent?.lastSyncDate
            )

            switch decision {
            case .conflict:
                calendarEvent?.markConflict()
            case .useEvent:
                EventMapper.updateShift(shift, from: event)
                calendarEvent?.markSynced(eventModified: event.lastModifiedDate)
            case .useShift:
                try syncShift(shift, calendar: calendar, settings: settings)
            case .noAction:
                calendarEvent?.markSynced(eventModified: event.lastModifiedDate)
            }
        }

        try context.save()
    }
}
