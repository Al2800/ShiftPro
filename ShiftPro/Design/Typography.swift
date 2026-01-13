import SwiftUI

// MARK: - Typography Scale
// Clear visual hierarchy from largest to smallest:
// largeTitle (34pt) → titleLarge (28pt) → title (22pt) → headline (17pt bold) →
// body (17pt) → subheadline (15pt) → callout (16pt) → caption (12pt) → footnote (13pt)

enum ShiftProTypography {
    /// Primary screen titles, hero text (34pt bold)
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)

    /// Section headers, card titles (28pt semibold)
    static let titleLarge = Font.system(.title, design: .rounded).weight(.semibold)

    /// Subsection headers, prominent values (22pt semibold)
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)

    /// Card headings, list row titles (17pt semibold)
    static let headline = Font.system(.headline, design: .rounded).weight(.semibold)

    /// Secondary labels, descriptions (15pt medium)
    static let subheadline = Font.system(.subheadline, design: .rounded).weight(.medium)

    /// Primary content text (17pt regular)
    static let body = Font.system(.body, design: .rounded)

    /// Tertiary labels, hints (16pt regular)
    static let callout = Font.system(.callout, design: .rounded)

    /// Metadata, timestamps, helper text (12pt medium)
    static let caption = Font.system(.caption, design: .rounded).weight(.medium)

    /// Small metadata, footnotes (13pt regular)
    static let footnote = Font.system(.footnote, design: .rounded)

    /// Code, IDs, fixed-width values (13pt monospaced)
    static let mono = Font.system(.footnote, design: .monospaced)
}

// MARK: - Spacing Scale
// Consistent spacing for padding, margins, and gaps:
// xxs (4) → xs (8) → sm (12) → md (16) → lg (24) → xl (32) → xxl (48)

enum ShiftProSpacing {
    /// Tight spacing: inline elements, icon gaps (4pt)
    static let extraExtraSmall: CGFloat = 4

    /// Compact spacing: list item padding, small gaps (8pt)
    static let extraSmall: CGFloat = 8

    /// Alias for extraSmall (8pt) - legacy compatibility
    static let xSmall: CGFloat = 8

    /// Standard tight spacing: form fields, card internal (12pt)
    static let small: CGFloat = 12

    /// Default spacing: section padding, card gaps (16pt)
    static let medium: CGFloat = 16

    /// Generous spacing: between sections, card margins (24pt)
    static let large: CGFloat = 24

    /// Wide spacing: major section breaks (32pt)
    static let extraLarge: CGFloat = 32

    /// Maximum spacing: page margins, hero sections (48pt)
    static let extraExtraLarge: CGFloat = 48

    /// Bottom padding to clear the tab bar
    static let tabBarPadding: CGFloat = 100
}

// MARK: - Common Options
enum ShiftProOptions {
    /// Standard break duration options in minutes
    static let breakMinutes: [Int] = [0, 15, 30, 45, 60]

    /// Default break duration in minutes
    static let defaultBreakMinutes: Int = 30

    /// Default shift duration in hours
    static let defaultShiftDurationHours: Int = 8

    /// Time rounding interval in minutes
    static let timeRoundingInterval: Int = 15
}
