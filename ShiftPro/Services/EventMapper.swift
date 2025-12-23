import EventKit
import Foundation

struct EventMapper {
    static func shiftURL(for shift: Shift) -> URL? {
        URL(string: "shiftpro://shift/\(shift.id.uuidString)")
    }

    static func shiftID(from event: EKEvent) -> UUID? {
        guard let url = event.url,
              url.scheme == "shiftpro",
              url.host == "shift" else { return nil }
        let idString = url.path.replacingOccurrences(of: "/", with: "")
        return UUID(uuidString: idString)
    }

    static func apply(
        shift: Shift,
        to event: EKEvent,
        calendar: EKCalendar,
        includeAlarms: Bool,
        alarmOffsetMinutes: Int
    ) {
        event.calendar = calendar
        event.title = title(for: shift)
        event.startDate = shift.scheduledStart
        event.endDate = shift.scheduledEnd
        event.notes = notes(for: shift)
        event.url = shiftURL(for: shift)

        if includeAlarms {
            let offset = TimeInterval(-alarmOffsetMinutes * 60)
            event.alarms = [EKAlarm(relativeOffset: offset)]
        } else {
            event.alarms = []
        }
    }

    static func updateShift(_ shift: Shift, from event: EKEvent) {
        shift.scheduledStart = event.startDate
        shift.scheduledEnd = event.endDate
        shift.markUpdated()
    }

    private static func title(for shift: Shift) -> String {
        if let pattern = shift.pattern {
            return "Shift: \(pattern.name)"
        }
        return "Shift"
    }

    private static func notes(for shift: Shift) -> String {
        var lines: [String] = []
        lines.append("ShiftPro")
        lines.append("Time: \(shift.timeRangeFormatted)")
        if let label = shift.rateLabel {
            lines.append("Rate: \(label) (\(shift.rateMultiplierFormatted))")
        } else {
            lines.append("Rate: \(shift.rateMultiplierFormatted)")
        }
        if let notes = shift.notes, !notes.isEmpty {
            lines.append("Notes: \(notes)")
        }
        return lines.joined(separator: "\n")
    }
}
