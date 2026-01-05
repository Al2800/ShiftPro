import SwiftUI
import UIKit

enum ShiftProColors {
    // Premium dark mode: near-black with subtle blue undertone (#08090C)
    static let background = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.031, green: 0.035, blue: 0.047, alpha: 1.0)
        }
        return UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
    })

    // Surface level 1: Primary cards and sections (#12141A)
    static let surface = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.071, green: 0.078, blue: 0.102, alpha: 1.0)
        }
        return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    })

    // Surface level 2: Elevated cards that pop more (#1A1D24)
    static let surfaceElevated = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.102, green: 0.114, blue: 0.141, alpha: 1.0)
        }
        return UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0)
    })

    // Surface muted: Subtle backgrounds between bg and surface (#0E1014)
    static let surfaceMuted = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.055, green: 0.063, blue: 0.078, alpha: 1.0)
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
        return UIColor(red: 0.12, green: 0.46, blue: 0.31, alpha: 1.0)
    })

    static let warning = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.95, green: 0.76, blue: 0.29, alpha: 1.0)
        }
        return UIColor(red: 0.62, green: 0.38, blue: 0.04, alpha: 1.0)
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
        return UIColor(red: 0.40, green: 0.44, blue: 0.50, alpha: 1.0)
    })

    // Steel: Structural borders and separators (#1C1F28)
    static let steel = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.110, green: 0.122, blue: 0.157, alpha: 1.0)
        }
        return UIColor(red: 0.94, green: 0.95, blue: 0.98, alpha: 1.0)
    })

    // Premium glow for elevated surfaces (accent-tinted shadow)
    static let elevationGlow = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.40, green: 0.58, blue: 0.88, alpha: 0.12)
        }
        return UIColor(red: 0.09, green: 0.32, blue: 0.66, alpha: 0.06)
    })

    // Surface level 3: Featured cards and hero sections (#22262F)
    static let card = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.133, green: 0.149, blue: 0.184, alpha: 1.0)
        }
        return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    })

    // Divider: More visible on deep backgrounds (#262A35)
    static let divider = Color(UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.149, green: 0.165, blue: 0.208, alpha: 1.0)
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
