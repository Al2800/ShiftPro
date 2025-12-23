import Foundation
import SwiftData
import SwiftUI
import UIKit

// MARK: - Date Formatting Extensions

extension Date {
    /// Formats the date for shift display (e.g., "Mon, Dec 23")
    var shiftDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: self)
    }

    /// Formats the time for shift display (e.g., "09:00")
    var shiftTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    /// Formats as relative date (e.g., "Today", "Tomorrow", "Dec 25")
    var relativeFormatted: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInTomorrow(self) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }

    /// Minutes since midnight for this date
    var minutesSinceMidnight: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// Start of day for this date
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of day for this date
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
}

// MARK: - Hours Formatting Extensions

extension Int {
    /// Formats minutes as hours and minutes string (e.g., "8h 30m")
    var minutesToHoursFormatted: String {
        let hours = self / 60
        let mins = self % 60

        if mins == 0 {
            return "\(hours)h"
        } else if hours == 0 {
            return "\(mins)m"
        }
        return "\(hours)h \(mins)m"
    }

    /// Converts minutes to decimal hours
    var minutesToDecimalHours: Double {
        Double(self) / 60.0
    }
}

extension Double {
    /// Formats hours as string (e.g., "8.5h")
    var hoursFormatted: String {
        String(format: "%.1fh", self)
    }

    /// Formats as currency (e.g., "$1,234.56")
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        if let currencyCode = Locale.current.currency?.identifier {
            formatter.currencyCode = currencyCode
        }
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "$%.2f", self)
    }
}

extension Int64 {
    /// Converts cents to dollars
    var centsToDollars: Double {
        Double(self) / 100.0
    }

    /// Formats cents as currency
    var centsFormatted: String {
        centsToDollars.currencyFormatted
    }
}

// MARK: - Color Extensions

extension String {
    /// Converts a hex color string to a SwiftUI Color
    var hexColor: Color {
        var hexString = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6,
              let rgb = UInt64(hexString, radix: 16) else {
            return .blue
        }

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        return Color(red: red, green: green, blue: blue)
    }
}

extension Color {
    /// Converts a Color to hex string
    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#007AFF"
        }

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255.0),
            Int(green * 255.0),
            Int(blue * 255.0)
        )
    }
}

// MARK: - Shift Status Colors

extension ShiftStatus {
    /// Color associated with this status
    var color: Color {
        switch self {
        case .scheduled: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }

    /// Background color (lighter) for this status
    var backgroundColor: Color {
        color.opacity(0.1)
    }
}

// MARK: - Rate Multiplier Colors

extension RateMultiplier {
    /// Color associated with this rate
    var color: Color {
        switch self {
        case .regular: return .primary
        case .overtimeBracket: return .orange
        case .extra: return .purple
        case .bankHoliday: return .red
        }
    }
}

// MARK: - Calendar Sync State Colors

extension CalendarSyncState {
    /// Color associated with this sync state
    var color: Color {
        switch self {
        case .localOnly: return .secondary
        case .synced: return .green
        case .needsUpdate: return .orange
        case .failed: return .red
        case .conflictDetected: return .pink
        }
    }

    /// SF Symbol name for this sync state
    var iconName: String {
        switch self {
        case .localOnly: return "icloud.slash"
        case .synced: return "checkmark.icloud.fill"
        case .needsUpdate: return "arrow.triangle.2.circlepath.icloud"
        case .failed: return "exclamationmark.icloud.fill"
        case .conflictDetected: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Predicate Helpers

extension Shift {
    /// Predicate for shifts in a date range
    static func predicate(
        from startDate: Date,
        to endDate: Date,
        includeDeleted: Bool = false
    ) -> Predicate<Shift> {
        if includeDeleted {
            return #Predicate<Shift> { shift in
                shift.scheduledStart >= startDate && shift.scheduledStart <= endDate
            }
        } else {
            return #Predicate<Shift> { shift in
                shift.scheduledStart >= startDate &&
                shift.scheduledStart <= endDate &&
                shift.deletedAt == nil
            }
        }
    }

    /// Predicate for today's shifts
    static var todayPredicate: Predicate<Shift> {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        return #Predicate<Shift> { shift in
            shift.scheduledStart >= startOfToday &&
            shift.scheduledStart < endOfToday &&
            shift.deletedAt == nil
        }
    }

    /// Predicate for upcoming shifts
    static var upcomingPredicate: Predicate<Shift> {
        let now = Date()
        return #Predicate<Shift> { shift in
            shift.scheduledStart > now && shift.deletedAt == nil
        }
    }
}

// MARK: - Sort Descriptors

extension Shift {
    /// Sort by scheduled start date (ascending)
    static var byDateAscending: SortDescriptor<Shift> {
        SortDescriptor(\.scheduledStart, order: .forward)
    }

    /// Sort by scheduled start date (descending)
    static var byDateDescending: SortDescriptor<Shift> {
        SortDescriptor(\.scheduledStart, order: .reverse)
    }
}

extension ShiftPattern {
    /// Sort by name (ascending)
    static var byNameAscending: SortDescriptor<ShiftPattern> {
        SortDescriptor(\.name, order: .forward)
    }
}

extension PayPeriod {
    /// Sort by start date (descending - most recent first)
    static var byStartDateDescending: SortDescriptor<PayPeriod> {
        SortDescriptor(\.startDate, order: .reverse)
    }
}
