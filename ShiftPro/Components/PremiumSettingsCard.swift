import SwiftUI

// MARK: - Premium Settings Section

struct PremiumSettingsSection<Content: View>: View {
    let title: String
    var icon: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ShiftProColors.accent)
                }
                Text(title)
                    .font(ShiftProTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(ShiftProColors.inkSubtle)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.horizontal, ShiftProSpacing.small)

            VStack(spacing: 1) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ShiftProColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        }
    }
}

// MARK: - Premium Settings Row

struct PremiumSettingsRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    let icon: String
    let title: String
    var detail: String?
    var iconColor: Color = ShiftProColors.accent
    var showChevron: Bool = true
    var badge: String?
    var badgeColor: Color = ShiftProColors.warning
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: ShiftProSpacing.medium) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    iconColor.opacity(0.2),
                                    iconColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                // Title and detail
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(ShiftProTypography.body)
                            .foregroundStyle(ShiftProColors.ink)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(badgeColor)
                                )
                        }
                    }

                    if let detail {
                        Text(detail)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ShiftProColors.inkSubtle.opacity(0.5))
                }
            }
            .padding(.horizontal, ShiftProSpacing.medium)
            .padding(.vertical, ShiftProSpacing.small + 2)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        HapticManager.fire(.impactLight, enabled: !reduceMotion)
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Premium Toggle Row

struct PremiumToggleRow: View {
    let icon: String
    let title: String
    var detail: String?
    var iconColor: Color = ShiftProColors.accent
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: ShiftProSpacing.medium) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                iconColor.opacity(0.2),
                                iconColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            // Title and detail
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)

                if let detail {
                    Text(detail)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(ShiftProColors.accent)
        }
        .padding(.horizontal, ShiftProSpacing.medium)
        .padding(.vertical, ShiftProSpacing.small + 2)
    }
}

// MARK: - Premium Profile Header

struct PremiumProfileHeader: View {
    let name: String
    var subtitle: String?
    var avatarIcon: String = "person.crop.circle.fill"
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: ShiftProSpacing.medium) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.30, green: 0.50, blue: 0.98),
                                    Color(red: 0.45, green: 0.40, blue: 0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: avatarIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: ShiftProColors.accent.opacity(0.3), radius: 8, x: 0, y: 4)

                // Name and subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(ShiftProColors.ink)

                    if let subtitle {
                        Text(subtitle)
                            .font(ShiftProTypography.subheadline)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ShiftProColors.inkSubtle.opacity(0.5))
            }
            .padding(ShiftProSpacing.medium)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(ShiftProColors.surface)

                    // Gradient overlay
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ShiftProColors.accent.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Border
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .scalePress(0.98)
    }
}

// MARK: - Premium Upgrade Card

struct PremiumUpgradeCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: CGFloat = 0

    var currentPlan: String = "Free"
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(currentPlan)
                        .font(ShiftProTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.2))
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Premium")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Unlock unlimited shifts, patterns, and more")
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                HStack {
                    Text("Learn More")
                        .font(ShiftProTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(ShiftProSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    // Gradient background
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.75, green: 0.55, blue: 0.20),
                                    Color(red: 0.85, green: 0.45, blue: 0.25),
                                    Color(red: 0.70, green: 0.35, blue: 0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Shimmer
                    if !reduceMotion {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0),
                                    endPoint: UnitPoint(x: shimmerPhase + 0.3, y: 1)
                                )
                            )
                    }

                    // Top highlight
                    VStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .frame(height: 60)
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            )
            .shadow(color: Color(red: 0.85, green: 0.45, blue: 0.25).opacity(0.35), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(PlainButtonStyle())
        .scalePress(0.98)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.5
            }
        }
    }
}

// MARK: - Settings Divider

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 1)
            .padding(.leading, 60)
    }
}

#Preview("Settings Components") {
    ScrollView {
        VStack(spacing: 24) {
            PremiumProfileHeader(
                name: "John Doe",
                subtitle: "Healthcare Worker"
            )

            PremiumUpgradeCard()

            PremiumSettingsSection(title: "Account", icon: "person.fill") {
                PremiumSettingsRow(icon: "person.crop.circle", title: "Profile", detail: "John Doe")
                SettingsDivider()
                PremiumSettingsRow(icon: "briefcase", title: "Workplace", detail: "City Hospital")
            }

            PremiumSettingsSection(title: "Preferences", icon: "gearshape.fill") {
                PremiumSettingsRow(icon: "calendar", title: "Default Pattern", detail: "Night Shift")
                SettingsDivider()
                PremiumSettingsRow(icon: "bell", title: "Notifications", detail: "Enabled")
            }
        }
        .padding()
    }
    .background(ShiftProColors.background)
}
