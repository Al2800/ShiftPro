import SwiftUI

// MARK: - Premium Hero Card

struct PremiumHeroCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gradientPhase: CGFloat = 0
    @State private var isPressed = false

    let title: String
    let subtitle: String
    var badge: String?
    var estimatedPay: String?
    var actionTitle: String?
    var actionIcon: String?
    var isLoading: Bool = false
    var style: HeroStyle = .primary
    var breakInfo: BreakInfo?
    var action: (() -> Void)?
    var onBreakTap: ((Int) -> Void)?

    struct BreakInfo {
        let currentMinutes: Int
        let quickOptions: [Int]
    }

    enum HeroStyle {
        case primary
        case success
        case warning

        var gradient: [Color] {
            switch self {
            case .primary:
                return [
                    Color(red: 0.22, green: 0.42, blue: 0.95),
                    Color(red: 0.45, green: 0.35, blue: 0.88),
                    Color(red: 0.55, green: 0.30, blue: 0.82)
                ]
            case .success:
                return [
                    Color(red: 0.15, green: 0.72, blue: 0.52),
                    Color(red: 0.12, green: 0.60, blue: 0.58),
                    Color(red: 0.10, green: 0.52, blue: 0.62)
                ]
            case .warning:
                return [
                    Color(red: 0.95, green: 0.65, blue: 0.20),
                    Color(red: 0.90, green: 0.50, blue: 0.25),
                    Color(red: 0.85, green: 0.40, blue: 0.30)
                ]
            }
        }

        var glowColor: Color {
            switch self {
            case .primary: return Color(red: 0.35, green: 0.45, blue: 0.95)
            case .success: return Color(red: 0.15, green: 0.72, blue: 0.52)
            case .warning: return Color(red: 0.95, green: 0.65, blue: 0.20)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content area
            VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                // Badge row
                if let badge {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                            .modifier(PulseEffectModifier())

                        Text(badge)
                            .font(ShiftProTypography.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }

                // Title
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Subtitle
                Text(subtitle)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(.white.opacity(0.85))

                // Estimated pay
                if let pay = estimatedPay {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 14))
                        Text("Est. \(pay)")
                            .font(ShiftProTypography.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }

                // Break controls
                if let breakInfo {
                    breakControls(breakInfo)
                }

                // Action button
                if let actionTitle, let action {
                    Button(action: action) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: style.gradient[0]))
                                    .scaleEffect(0.8)
                            } else {
                                if let actionIcon {
                                    Image(systemName: actionIcon)
                                        .font(.system(size: 14, weight: .bold))
                                }
                                Text(actionTitle)
                                    .font(ShiftProTypography.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(style.gradient[0])
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isLoading)
                    .scaleEffect(isPressed ? 0.96 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in isPressed = true }
                            .onEnded { _ in isPressed = false }
                    )
                }
            }
            .padding(ShiftProSpacing.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Animated gradient background
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: style.gradient,
                            startPoint: UnitPoint(x: gradientPhase, y: 0),
                            endPoint: UnitPoint(x: 1 - gradientPhase * 0.5, y: 1)
                        )
                    )

                // Mesh overlay for depth
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.15),
                                .clear
                            ],
                            center: UnitPoint(x: 0.2, y: 0.2),
                            startRadius: 0,
                            endRadius: 200
                        )
                    )

                // Noise texture
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.03))
                    .overlay(
                        NoiseOverlay()
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    )

                // Top edge highlight
                VStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 80)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        )
        .shadow(color: style.glowColor.opacity(0.35), radius: 24, x: 0, y: 12)
        .shadow(color: style.glowColor.opacity(0.2), radius: 48, x: 0, y: 24)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                gradientPhase = 0.3
            }
        }
    }

    @ViewBuilder
    private func breakControls(_ info: BreakInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 12))
                Text("Break: \(info.currentMinutes) min")
                    .font(ShiftProTypography.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 8) {
                ForEach(info.quickOptions, id: \.self) { minutes in
                    Button {
                        onBreakTap?(minutes)
                    } label: {
                        Text("+\(minutes)m")
                            .font(ShiftProTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(style.gradient[0])
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.95))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Pulse Effect Modifier

private struct PulseEffectModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - Noise Overlay

private struct NoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, through: size.width, by: 3) {
                for y in stride(from: 0, through: size.height, by: 3) {
                    let brightness = Double.random(in: 0...1)
                    if brightness > 0.7 {
                        context.fill(
                            Path(CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(Color.white.opacity(brightness * 0.05))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Compact Hero Card

struct CompactHeroCard: View {
    let title: String
    let subtitle: String
    var icon: String?
    var style: PremiumHeroCard.HeroStyle = .primary
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: ShiftProSpacing.medium) {
            if let icon {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: style.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: style.glowColor.opacity(0.25), radius: 12, x: 0, y: 6)
        .onTapGesture {
            action?()
        }
    }
}

#Preview("Hero Cards") {
    ScrollView {
        VStack(spacing: 24) {
            PremiumHeroCard(
                title: "On Shift Now",
                subtitle: "Started at 9:00 AM - 4h 32m elapsed",
                badge: "In Progress",
                estimatedPay: "$156.80",
                actionTitle: "End Shift",
                actionIcon: "stop.fill",
                style: .success,
                breakInfo: .init(currentMinutes: 30, quickOptions: [5, 15, 30]),
                action: {}
            )

            PremiumHeroCard(
                title: "Next Shift",
                subtitle: "Tomorrow at 7:00 AM",
                estimatedPay: "$184.00",
                actionTitle: "Start Shift",
                actionIcon: "play.fill",
                style: .primary,
                action: {}
            )

            CompactHeroCard(
                title: "Shift Reminder",
                subtitle: "Your shift starts in 30 minutes",
                icon: "clock.badge",
                style: .warning
            ) {}
        }
        .padding()
    }
    .background(ShiftProColors.background)
}
