import Foundation

/// Shared currency formatter using device locale
enum CurrencyFormatter {
    /// Shared formatter instance using device locale for currency display
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }()

    /// Currency symbol for the current locale (e.g., "$", "£", "€")
    static var currencySymbol: String {
        shared.currencySymbol ?? Locale.current.currencySymbol ?? "$"
    }

    /// Format a value as currency string
    static func format(_ value: Double) -> String? {
        shared.string(from: NSNumber(value: value))
    }

    /// Format cents to currency string (divide by 100)
    static func formatCents(_ cents: Int) -> String? {
        format(Double(cents) / 100.0)
    }

    /// Compact format for large values (e.g., "$1.2k", "£1.2k")
    static func formatCompact(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%@%.1fk", currencySymbol, value / 1000)
        }
        return format(value) ?? "\(currencySymbol)0"
    }

    /// Create a formatter for input fields (allows editing)
    static func inputFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        return formatter
    }
}
