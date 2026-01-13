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

extension Date {
    /// Rounds the date to the nearest interval (in minutes)
    /// - Parameter minutes: The interval to round to (default: 15)
    /// - Returns: The rounded date
    func roundedToNearest(minutes: Int = 15) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        let currentMinutes = components.minute ?? 0
        let roundedMinutes = ((currentMinutes + minutes / 2) / minutes) * minutes

        var newComponents = components
        newComponents.minute = roundedMinutes % 60
        newComponents.second = 0

        // Handle hour rollover
        let hourAdjustment = roundedMinutes / 60
        if hourAdjustment > 0 {
            newComponents.hour = (newComponents.hour ?? 0) + hourAdjustment
        }

        return calendar.date(from: newComponents) ?? self
    }

    /// Rounds up to the next interval (in minutes)
    /// - Parameter minutes: The interval to round to (default: 15)
    /// - Returns: The rounded up date
    func roundedUp(toNearest minutes: Int = 15) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        let currentMinutes = components.minute ?? 0
        let remainder = currentMinutes % minutes

        if remainder == 0 {
            // Already on the interval, just clear seconds
            var newComponents = components
            newComponents.second = 0
            return calendar.date(from: newComponents) ?? self
        }

        let minutesToAdd = minutes - remainder
        return calendar.date(byAdding: .minute, value: minutesToAdd, to: self)?.roundedToNearest(minutes: minutes) ?? self
    }

    /// Returns true if this date is on the same day as the given date
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
