import Foundation

/// Cached DateFormatter instances for performance
/// DateFormatter is expensive to create, so we cache common formats
enum DateFormatters {
    // MARK: - Time Formatters

    /// Time only format: "09:00" or "14:30"
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// 12-hour time format: "9:00 AM" or "2:30 PM"
    static let time12Hour: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    // MARK: - Date Formatters

    /// Day number only: "23"
    static let dayNumber: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    /// Short weekday: "Mon", "Tue"
    static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    /// Single letter weekday: "M", "T", "W"
    static let singleLetterWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter
    }()

    /// Full weekday: "Monday", "Tuesday"
    static let fullWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    /// Short date: "Mon, Dec 23"
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    /// Month and year: "December 2024"
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    /// Short month and year: "Dec 2024"
    static let shortMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    /// ISO date: "2024-12-23"
    static let isoDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Combined Formatters

    /// Date and time: "Dec 23, 09:00"
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter
    }()

    /// Full date and time: "Mon, Dec 23 at 09:00"
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' HH:mm"
        return formatter
    }()

    // MARK: - Relative Formatter

    /// Relative date formatter for "Today", "Yesterday", etc.
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    // MARK: - Duration Formatter

    /// Duration formatter for shift lengths
    static let duration: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()

    /// Short duration: "8h 30m"
    static let shortDuration: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .brief
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()
}

// MARK: - Date Extensions using Cached Formatters

extension Date {
    /// Time string using cached formatter: "09:00"
    var timeString: String {
        DateFormatters.time.string(from: self)
    }

    /// Day number using cached formatter: "23"
    var dayString: String {
        DateFormatters.dayNumber.string(from: self)
    }

    /// Short weekday using cached formatter: "Mon"
    var shortWeekdayString: String {
        DateFormatters.shortWeekday.string(from: self)
    }

    /// Short date using cached formatter: "Mon, Dec 23"
    var shortDateString: String {
        DateFormatters.shortDate.string(from: self)
    }

    /// Month year using cached formatter: "December 2024"
    var monthYearString: String {
        DateFormatters.monthYear.string(from: self)
    }
}
