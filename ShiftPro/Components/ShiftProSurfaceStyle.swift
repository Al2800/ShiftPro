import SwiftUI
import UIKit

// MARK: - ShiftPro Surface Style Guide
//
// Surface Levels:
// - .flat (22pt radius): Flat surfaces without elevation
// - .standard (22pt radius): Subtle lift for default cards, form sections, list items
// - .elevated (24pt radius): Important cards, summaries, featured content
// - .hero (28pt radius): Hero cards, primary CTAs, dashboard highlights
// - .floating (30pt radius): Floating panels, modals, popovers
//
// Usage:
// - Cards: .shiftProSurface(.standard) or .shiftProSurface(.elevated)
// - Hero sections: .shiftProSurface(.hero)
// - Form sections: .shiftProCardSection() for styled form rows
//
// Shadow Rules:
// - .flat: No shadow (flat surface)
// - .standard: Subtle depth + soft glow
// - .elevated: Layered depth + standard glow
// - .hero: Prominent depth + noticeable glow
// - .floating: Strong depth + wide glow
//
// Corner Radius Reference:
// - Small elements (chips, pills): 12-14pt
// - Cards and sections: 20-22pt
// - Featured/hero: 24-28pt

enum ShiftProSurfaceLevel {
    case flat
    case standard
    case elevated
    case hero
    case floating

    var cornerRadius: CGFloat {
        switch self {
        case .flat:
            return 22
        case .standard:
            return 22
        case .elevated:
            return 24
        case .hero:
            return 28
        case .floating:
            return 30
        }
    }

    var backgroundColor: Color {
        switch self {
        case .flat:
            return ShiftProColors.surface
        case .standard:
            return ShiftProColors.surface
        case .elevated:
            return ShiftProColors.surfaceElevated
        case .hero:
            return ShiftProColors.surfaceElevated
        case .floating:
            return ShiftProColors.card
        }
    }

    var borderColor: Color {
        switch self {
        case .hero:
            return ShiftProColors.accent
        case .floating:
            return ShiftProColors.accent.opacity(0.3)
        default:
            return ShiftProColors.accentMuted
        }
    }

    var primaryShadowOpacity: Double {
        switch self {
        case .flat:
            return 0
        case .standard:
            return 0.18
        case .elevated:
            return 0.28
        case .hero:
            return 0.36
        case .floating:
            return 0.42
        }
    }

    var primaryShadowRadius: CGFloat {
        switch self {
        case .flat:
            return 0
        case .standard:
            return 6
        case .elevated:
            return 10
        case .hero:
            return 14
        case .floating:
            return 18
        }
    }

    var primaryShadowY: CGFloat {
        switch self {
        case .flat:
            return 0
        case .standard:
            return 3
        case .elevated:
            return 6
        case .hero:
            return 10
        case .floating:
            return 12
        }
    }

    var glowIntensity: GlowIntensity {
        switch self {
        case .standard:
            return .subtle
        case .elevated:
            return .standard
        case .hero:
            return .prominent
        case .floating:
            return .prominent
        case .flat:
            return .none
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .flat:
            return 0
        case .standard:
            return 14
        case .elevated:
            return 20
        case .hero:
            return 28
        case .floating:
            return 34
        }
    }

    var primaryShadowColor: Color {
        let opacity = primaryShadowOpacity
        return Color(UIColor { trait in
            let adjusted = trait.userInterfaceStyle == .dark ? opacity : opacity * 0.6
            return UIColor(white: 0.0, alpha: adjusted)
        })
    }

    var glowColor: Color {
        ShiftProColors.glow(glowIntensity)
    }

    var contentPadding: CGFloat {
        switch self {
        case .flat:
            return ShiftProSpacing.medium
        case .standard:
            return ShiftProSpacing.large
        case .elevated, .hero, .floating:
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
            // Primary shadow for depth
            .shadow(
                color: level.primaryShadowColor,
                radius: level.primaryShadowRadius,
                x: 0,
                y: level.primaryShadowY
            )
            // Secondary glow for premium elevation effect
            .shadow(
                color: level.glowColor,
                radius: level.glowRadius,
                x: 0,
                y: 0
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
        let level: ShiftProSurfaceLevel = shadow ? .standard : .flat
        self
            .padding(padding)
            .background(level.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Primary depth shadow
            .shadow(
                color: level.primaryShadowColor,
                radius: shadow ? level.primaryShadowRadius : 0,
                x: 0,
                y: shadow ? level.primaryShadowY : 0
            )
            // Secondary glow for premium feel
            .shadow(
                color: shadow ? level.glowColor : .clear,
                radius: shadow ? level.glowRadius : 0,
                x: 0,
                y: 0
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

    /// Floating panels and popovers (30pt)
    static let floating: CGFloat = 30
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
