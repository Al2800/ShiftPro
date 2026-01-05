import SwiftUI

// MARK: - Premium Button Styles

enum PremiumButtonStyle {
    case primary
    case secondary
    case success
    case ghost

    var gradient: LinearGradient {
        switch self {
        case .primary:
            return LinearGradient(
                colors: [
                    Color(red: 0.30, green: 0.50, blue: 0.98),
                    Color(red: 0.45, green: 0.40, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            return LinearGradient(
                colors: [
                    ShiftProColors.surface,
                    ShiftProColors.surfaceElevated
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .success:
            return LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.80, blue: 0.55),
                    Color(red: 0.18, green: 0.68, blue: 0.58)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ghost:
            return LinearGradient(
                colors: [Color.clear, Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    var textColor: Color {
        switch self {
        case .primary, .success:
            return .white
        case .secondary:
            return ShiftProColors.ink
        case .ghost:
            return ShiftProColors.accent
        }
    }

    var glowColor: Color {
        switch self {
        case .primary:
            return Color(red: 0.35, green: 0.50, blue: 0.98)
        case .success:
            return Color(red: 0.22, green: 0.80, blue: 0.55)
        case .secondary, .ghost:
            return .clear
        }
    }
}

// MARK: - Premium Button View

struct PremiumButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var shimmerPhase: CGFloat = 0

    let title: String
    var icon: String?
    var style: PremiumButtonStyle = .primary
    var size: ButtonSize = .regular
    var isLoading: Bool = false
    var fullWidth: Bool = false
    var showShimmer: Bool = false
    let action: () -> Void

    enum ButtonSize {
        case small
        case regular
        case large

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 10
            case .regular: return 14
            case .large: return 18
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 16
            case .regular: return 24
            case .large: return 32
            }
        }

        var font: Font {
            switch self {
            case .small: return ShiftProTypography.caption
            case .regular: return ShiftProTypography.subheadline
            case .large: return ShiftProTypography.headline
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .regular: return 16
            case .large: return 20
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 10
            case .regular: return 14
            case .large: return 18
            }
        }
    }

    var body: some View {
        Button(action: performAction) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.textColor))
                        .scaleEffect(0.8)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .semibold))
                    }

                    Text(title)
                        .font(size.font)
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(style.textColor)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                ZStack {
                    // Main gradient background
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(style.gradient)

                    // Top highlight
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(1)
                        .mask(
                            RoundedRectangle(cornerRadius: size.cornerRadius - 1, style: .continuous)
                        )

                    // Shimmer overlay
                    if showShimmer && !reduceMotion {
                        RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0),
                                    endPoint: UnitPoint(x: shimmerPhase + 0.3, y: 1)
                                )
                            )
                            .mask(
                                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                            )
                    }

                    // Border
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(style == .ghost ? 0.1 : 0.3),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: style == .ghost ? 1 : 0.5
                        )
                }
            )
            .shadow(
                color: style.glowColor.opacity(isPressed ? 0.1 : 0.3),
                radius: isPressed ? 4 : 12,
                x: 0,
                y: isPressed ? 2 : 6
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
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
        .disabled(isLoading)
        .onAppear {
            if showShimmer && !reduceMotion {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.5
                }
            }
        }
    }

    private func performAction() {
        if !reduceMotion {
            HapticManager.fire(.impactMedium)
        }
        action()
    }
}

// MARK: - Icon Button

struct PremiumIconButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    let icon: String
    var size: CGFloat = 44
    var style: PremiumButtonStyle = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: performAction) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(style == .secondary ? ShiftProColors.ink : style.textColor)
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        Circle()
                            .fill(style.gradient)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )

                        Circle()
                            .strokeBorder(
                                Color.white.opacity(0.1),
                                lineWidth: 0.5
                            )
                    }
                )
                .shadow(color: style.glowColor.opacity(0.2), radius: 8, x: 0, y: 4)
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private func performAction() {
        if !reduceMotion {
            HapticManager.fire(.impactLight)
        }
        action()
    }
}

// MARK: - Floating Action Button

struct PremiumFAB: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0

    let icon: String
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: performAction) {
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(ShiftProColors.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: size * pulseScale, height: size * pulseScale)
                    .opacity(2 - pulseScale)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.30, green: 0.52, blue: 0.98),
                                Color(red: 0.42, green: 0.38, blue: 0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    )
                    .shadow(color: ShiftProColors.accent.opacity(0.4), radius: 16, x: 0, y: 8)
                    .shadow(color: ShiftProColors.accent.opacity(0.2), radius: 32, x: 0, y: 16)

                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                pulseScale = 1.8
            }
        }
    }

    private func performAction() {
        if !reduceMotion {
            HapticManager.fire(.impactMedium)
        }
        action()
    }
}

#Preview("Premium Buttons") {
    ZStack {
        ShiftProColors.background.ignoresSafeArea()

        VStack(spacing: 24) {
            PremiumButton(title: "Start Shift", icon: "play.fill", style: .primary, showShimmer: true) {}

            PremiumButton(title: "View Schedule", icon: "calendar", style: .secondary) {}

            PremiumButton(title: "End Shift", icon: "stop.fill", style: .success) {}

            PremiumButton(title: "Learn More", style: .ghost) {}

            HStack(spacing: 16) {
                PremiumIconButton(icon: "plus") {}
                PremiumIconButton(icon: "bell.badge", style: .primary) {}
                PremiumIconButton(icon: "gearshape") {}
            }

            PremiumFAB(icon: "plus") {}
        }
        .padding()
    }
}
