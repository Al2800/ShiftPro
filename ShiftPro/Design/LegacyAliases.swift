import SwiftUI

/// Compatibility aliases for older design token names.
enum ShiftProColor {
    static let textPrimary = ShiftProColors.ink
    static let textSecondary = ShiftProColors.inkSubtle
    static let background = ShiftProColors.background
    static let surface = ShiftProColors.surface
    static let accent = ShiftProColors.accent
    static let accentSoft = ShiftProColors.accentMuted
    static let success = ShiftProColors.success
    static let warning = ShiftProColors.warning
    static let danger = ShiftProColors.danger
}

extension ShiftProSpacing {
    static let small = s
    static let xSmall = xs
    static let medium = m
}
