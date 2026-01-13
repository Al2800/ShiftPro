import SwiftUI

/// Unified section header component for consistent styling across views
struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var style: Style = .standard

    enum Style {
        /// Standard section header with icon and bold title
        case standard
        /// Subtle uppercase header for secondary sections
        case subtle
        /// Prominent header for main sections
        case prominent
    }

    var body: some View {
        HStack(spacing: ShiftProSpacing.extraSmall) {
            if let icon {
                Image(systemName: icon)
                    .font(iconFont)
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(titleFont)
                .fontWeight(titleWeight)
                .foregroundStyle(titleColor)
                .textCase(style == .subtle ? .uppercase : nil)
        }
    }

    private var iconFont: Font {
        switch style {
        case .standard:
            return .system(size: 12, weight: .semibold)
        case .subtle:
            return .system(size: 10, weight: .medium)
        case .prominent:
            return .system(size: 14, weight: .bold)
        }
    }

    private var iconColor: Color {
        switch style {
        case .standard, .prominent:
            return ShiftProColors.accent
        case .subtle:
            return ShiftProColors.inkSubtle
        }
    }

    private var titleFont: Font {
        switch style {
        case .standard:
            return ShiftProTypography.headline
        case .subtle:
            return ShiftProTypography.subheadline
        case .prominent:
            return ShiftProTypography.title
        }
    }

    private var titleWeight: Font.Weight {
        switch style {
        case .standard, .prominent:
            return .semibold
        case .subtle:
            return .medium
        }
    }

    private var titleColor: Color {
        switch style {
        case .standard, .prominent:
            return ShiftProColors.ink
        case .subtle:
            return ShiftProColors.inkSubtle
        }
    }
}

// MARK: - Convenience Initializers

extension SectionHeader {
    /// Standard section header with icon
    static func withIcon(_ title: String, icon: String) -> SectionHeader {
        SectionHeader(title: title, icon: icon, style: .standard)
    }

    /// Subtle uppercase section header
    static func subtle(_ title: String) -> SectionHeader {
        SectionHeader(title: title, style: .subtle)
    }

    /// Prominent section header for main sections
    static func prominent(_ title: String, icon: String? = nil) -> SectionHeader {
        SectionHeader(title: title, icon: icon, style: .prominent)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        SectionHeader.withIcon("This Period", icon: "chart.bar.fill")
        SectionHeader.subtle("Details")
        SectionHeader.prominent("Overview", icon: "star.fill")
        SectionHeader(title: "Simple Title")
    }
    .padding()
    .background(ShiftProColors.background)
}
