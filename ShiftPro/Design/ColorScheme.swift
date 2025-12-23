import SwiftUI
import UIKit

enum ShiftProColors {
    static let background = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0)
        }
        return UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
    })

    static let surface = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.12, green: 0.13, blue: 0.17, alpha: 1.0)
        }
        return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    })

    static let surfaceElevated = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1.0)
        }
        return UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0)
    })

    static let surfaceMuted = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.14, green: 0.15, blue: 0.19, alpha: 1.0)
        }
        return UIColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1.0)
    })

    static let ink = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1.0)
        }
        return UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0)
    })

    static let inkSubtle = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.68, green: 0.72, blue: 0.78, alpha: 1.0)
        }
        return UIColor(red: 0.36, green: 0.40, blue: 0.46, alpha: 1.0)
    })

    /// Alias for inkSubtle for semantic clarity
    static let textSecondary = inkSubtle

    static let accent = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.40, green: 0.58, blue: 0.88, alpha: 1.0)
        }
        return UIColor(red: 0.09, green: 0.32, blue: 0.66, alpha: 1.0)
    })

    static let accentMuted = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.22, green: 0.30, blue: 0.42, alpha: 1.0)
        }
        return UIColor(red: 0.86, green: 0.90, blue: 0.96, alpha: 1.0)
    })

    static let success = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.33, green: 0.75, blue: 0.57, alpha: 1.0)
        }
        return UIColor(red: 0.16, green: 0.56, blue: 0.38, alpha: 1.0)
    })

    static let warning = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.95, green: 0.76, blue: 0.29, alpha: 1.0)
        }
        return UIColor(red: 0.80, green: 0.53, blue: 0.05, alpha: 1.0)
    })

    static let danger = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.93, green: 0.42, blue: 0.45, alpha: 1.0)
        }
        return UIColor(red: 0.72, green: 0.17, blue: 0.23, alpha: 1.0)
    })

    static let midnight = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1.0)
        }
        return UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0)
    })

    static let fog = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.82, green: 0.85, blue: 0.90, alpha: 1.0)
        }
        return UIColor(red: 0.52, green: 0.56, blue: 0.62, alpha: 1.0)
    })

    static let steel = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.14, green: 0.15, blue: 0.20, alpha: 1.0)
        }
        return UIColor(red: 0.94, green: 0.95, blue: 0.98, alpha: 1.0)
    })

    static let card = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.18, green: 0.20, blue: 0.26, alpha: 1.0)
        }
        return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    })

    static let divider = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.30, green: 0.32, blue: 0.38, alpha: 1.0)
        }
        return UIColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1.0)
    })

    static let heroGradient = LinearGradient(
        gradient: Gradient(colors: [accent, accentMuted]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func rateColor(multiplier: Double) -> Color {
        switch multiplier {
        case 2.0:
            return danger
        case 1.5:
            return warning
        case 1.3:
            return accent
        default:
            return success
        }
    }
}
