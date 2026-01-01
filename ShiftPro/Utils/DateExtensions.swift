import Foundation

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }

    func endOfDay(for date: Date) -> Date {
        let start = startOfDay(for: date)
        let nextDay = self.date(byAdding: .day, value: 1, to: start) ?? date
        return self.date(byAdding: .second, value: -1, to: nextDay) ?? date
    }
}
