import SwiftUI

// MARK: - ShiftPro Surface Style Guide
//
// Surface Levels:
// - .standard (22pt radius): Default cards, form sections, list items
// - .elevated (24pt radius): Important cards, summaries, featured content
// - .hero (28pt radius): Hero cards, primary CTAs, dashboard highlights
//
// Usage:
// - Cards: .shiftProSurface(.standard) or .shiftProSurface(.elevated)
// - Hero sections: .shiftProSurface(.hero)
// - Form sections: .shiftProCardSection() for styled form rows
//
// Shadow Rules:
// - .standard: No shadow (flat surface)
// - .elevated: Subtle shadow (8pt blur, 0.15 opacity)
// - .hero: Prominent shadow (18pt blur, 0.25 opacity)
//
// Corner Radius Reference:
// - Small elements (chips, pills): 12-14pt
// - Cards and sections: 20-22pt
// - Featured/hero: 24-28pt

enum ShiftProSurfaceLevel {
    case standard
    case elevated
    case hero

    var cornerRadius: CGFloat {
        switch self {
        case .standard:
            return 22
        case .elevated:
            return 24
        case .hero:
            return 28
        }
    }

    var backgroundColor: Color {
        switch self {
        case .standard:
            return ShiftProColors.surface
        case .elevated:
            return ShiftProColors.surfaceElevated
        case .hero:
            return ShiftProColors.surfaceElevated
        }
    }

    var borderColor: Color {
        switch self {
        case .hero:
            return ShiftProColors.accent
        default:
            return ShiftProColors.accentMuted
        }
    }

    var shadowColor: Color {
        switch self {
        case .standard:
            return .clear
        case .elevated:
            return ShiftProColors.accent.opacity(0.15)
        case .hero:
            return ShiftProColors.accent.opacity(0.25)
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .standard:
            return 0
        case .elevated:
            return 12
        case .hero:
            return 18
        }
    }

    var shadowX: CGFloat { 0 }
    var shadowY: CGFloat {
        switch self {
        case .standard:
            return 0
        case .elevated:
            return 8
        case .hero:
            return 10
        }
    }

    var contentPadding: CGFloat {
        switch self {
        case .standard:
            return ShiftProSpacing.large
        case .elevated, .hero:
            return ShiftProSpacing.extraLarge
        }
    }
}

struct ShiftProSurfaceStyle: ViewModifier {
    let level: ShiftProSurfaceLevel

    func body(content: Content) -> some View {
        content
            .padding(level.contentPadding)
            .background(level.backgroundColor)
            .clipShape(
                RoundedRectangle(cornerRadius: level.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: level.cornerRadius, style: .continuous)
                    .stroke(level.borderColor, lineWidth: 1)
            )
            .shadow(
                color: level.shadowColor,
                radius: level.shadowRadius,
                x: level.shadowX,
                y: level.shadowY
            )
    }
}

extension View {
    func shiftProSurface(_ level: ShiftProSurfaceLevel = .standard) -> some View {
        modifier(ShiftProSurfaceStyle(level: level))
    }

    /// Card-style section for form content without border
    func shiftProCardSection(
        cornerRadius: CGFloat = 22,
        padding: CGFloat = ShiftProSpacing.medium,
        shadow: Bool = true
    ) -> some View {
        self
            .padding(padding)
            .background(ShiftProColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: shadow ? ShiftProColors.accent.opacity(0.1) : .clear,
                radius: shadow ? 8 : 0,
                x: 0,
                y: shadow ? 4 : 0
            )
    }

    /// Standard corner radius constant
    static var shiftProCornerRadius: CGFloat { 22 }

    /// Elevated corner radius constant
    static var shiftProCornerRadiusElevated: CGFloat { 24 }

    /// Hero corner radius constant
    static var shiftProCornerRadiusHero: CGFloat { 28 }
}

// MARK: - Corner Radius Constants

enum ShiftProCornerRadius {
    /// Small elements: chips, pills, progress bars (12pt)
    static let small: CGFloat = 12

    /// Medium elements: buttons, tags, badges (14pt)
    static let medium: CGFloat = 14

    /// Standard cards and sections (22pt)
    static let standard: CGFloat = 22

    /// Elevated cards and important content (24pt)
    static let elevated: CGFloat = 24

    /// Hero cards and primary CTAs (28pt)
    static let hero: CGFloat = 28
}

extension View {
    /// Clips view to ShiftPro standard rounded rectangle
    func clipShiftProShape(_ level: ShiftProSurfaceLevel = .standard) -> some View {
        clipShape(RoundedRectangle(cornerRadius: level.cornerRadius, style: .continuous))
    }

    /// Clips view to a custom ShiftPro corner radius
    func clipShiftProShape(radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Spacing Constants Extension

extension ShiftProSpacing {
    /// Standard card padding
    static let cardPadding: CGFloat = medium

    /// Section spacing between cards
    static let sectionSpacing: CGFloat = large
}
