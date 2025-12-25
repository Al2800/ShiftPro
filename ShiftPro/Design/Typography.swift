import SwiftUI

enum ShiftProTypography {
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)
    static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let subheadline = Font.system(.subheadline, design: .rounded).weight(.medium)
    static let body = Font.system(.body, design: .rounded)
    static let callout = Font.system(.callout, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded).weight(.medium)
    static let mono = Font.system(.footnote, design: .monospaced)
}

enum ShiftProSpacing {
    static let extraExtraSmall: CGFloat = 4
    static let extraSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
}
