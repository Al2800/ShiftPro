import Foundation

enum DateMath {
    static func daysBetween(_ start: Date, _ end: Date, calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }

    static func addDays(_ days: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func addMinutes(_ minutes: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: date) ?? date
    }

    static func dates(from start: Date, to end: Date, calendar: Calendar = .current) -> [Date] {
        guard start <= end else { return [] }
        var dates: [Date] = []
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while current <= endDay {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }

    static func date(for day: Date, atMinute minuteOfDay: Int, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: minuteOfDay, to: startOfDay) ?? day
    }
}
