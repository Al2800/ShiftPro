import Foundation

/// Shared currency formatter configured for GBP
enum CurrencyFormatter {
    /// Shared formatter instance for currency display
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()

    /// Format a value as currency string
    static func format(_ value: Double) -> String? {
        shared.string(from: NSNumber(value: value))
    }

    /// Format cents to currency string (divide by 100)
    static func formatCents(_ cents: Int) -> String? {
        format(Double(cents) / 100.0)
    }

    /// Compact format for large values (e.g., "£1.2k")
    static func formatCompact(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "£%.1fk", value / 1000)
        }
        return format(value) ?? "£0"
    }
}
