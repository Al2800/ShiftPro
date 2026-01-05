import SwiftUI

// MARK: - Premium Stat Card

struct PremiumStatCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue: Double = 0
    @State private var hasAppeared = false

    let title: String
    let value: Double
    var unit: String = ""
    var icon: String?
    var trend: TrendIndicator?
    var accentColor: Color = ShiftProColors.accent
    var showRing: Bool = false
    var ringProgress: Double = 0

    struct TrendIndicator {
        let delta: Double
        let label: String?

        var isPositive: Bool { delta >= 0 }
        var color: Color { isPositive ? ShiftProColors.success : ShiftProColors.warning }
        var icon: String { isPositive ? "arrow.up.right" : "arrow.down.right" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            // Header
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(accentColor.opacity(0.15))
                        )
                }

                Text(title)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)

                Spacer()

                if let trend {
                    trendBadge(trend)
                }
            }

            // Value display
            HStack(alignment: .bottom, spacing: 4) {
                if showRing {
                    ringProgressView
                        .frame(width: 56, height: 56)
                }

                VStack(alignment: showRing ? .leading : .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formattedValue)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(ShiftProColors.ink)
                            .contentTransition(.numericText())

                        if !unit.isEmpty {
                            Text(unit)
                                .font(ShiftProTypography.subheadline)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                    }

                    if let trend, let label = trend.label {
                        Text(label)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }

                Spacer()
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(ShiftProColors.surface)

                // Top highlight
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                // Border
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .shadow(color: accentColor.opacity(0.08), radius: 20, x: 0, y: 8)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            if reduceMotion {
                animatedValue = value
            } else {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                    animatedValue = value
                }
            }
        }
        .onChange(of: value) { _, newValue in
            if reduceMotion {
                animatedValue = newValue
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animatedValue = newValue
                }
            }
        }
    }

    private var formattedValue: String {
        if value == floor(value) {
            return String(format: "%.0f", animatedValue)
        }
        return String(format: "%.1f", animatedValue)
    }

    @ViewBuilder
    private func trendBadge(_ trend: TrendIndicator) -> some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .font(.system(size: 10, weight: .bold))

            Text(String(format: "%+.1f", trend.delta))
                .font(ShiftProTypography.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(trend.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(trend.color.opacity(0.12))
        )
    }

    @ViewBuilder
    private var ringProgressView: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(accentColor.opacity(0.15), lineWidth: 6)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(ringProgress, 1.0))
                .stroke(
                    AngularGradient(
                        colors: [accentColor, accentColor.opacity(0.6)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: ringProgress)

            // Center glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(0.2), accentColor.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 28
                    )
                )
        }
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
    let title: String
    let value: String
    var icon: String?
    var accentColor: Color = ShiftProColors.inkSubtle

    var body: some View {
        HStack(spacing: ShiftProSpacing.small) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)

                Text(value)
                    .font(ShiftProTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ShiftProColors.ink)
            }
        }
        .padding(ShiftProSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ShiftProColors.surfaceMuted)
        )
    }
}

// MARK: - Earnings Highlight Card

struct EarningsHighlightCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: CGFloat = 0

    let amount: Double
    let label: String
    var subtitle: String?

    private var formattedAmount: String {
        CurrencyFormatter.format(amount) ?? "£\(String(format: "%.2f", amount))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text(label)
                .font(ShiftProTypography.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(formattedAmount)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            if let subtitle {
                Text(subtitle)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ShiftProSpacing.large)
        .background(
            ZStack {
                // Base gradient
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.72, blue: 0.52),
                                Color(red: 0.14, green: 0.58, blue: 0.56)
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
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0)
                                ],
                                startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0),
                                endPoint: UnitPoint(x: shimmerPhase + 0.3, y: 1)
                            )
                        )
                }

                // Top highlight
                RoundedRectangle(cornerRadius: 24, style: .continuous)
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
            }
        )
        .shadow(color: Color(red: 0.18, green: 0.72, blue: 0.52).opacity(0.3), radius: 16, x: 0, y: 8)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.5
            }
        }
    }
}

// MARK: - Stat Grid

struct StatGrid: View {
    let stats: [(title: String, value: String, icon: String?, color: Color)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ShiftProSpacing.small) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                MiniStatCard(
                    title: stat.title,
                    value: stat.value,
                    icon: stat.icon,
                    accentColor: stat.color
                )
            }
        }
    }
}

#Preview("Stat Cards") {
    ScrollView {
        VStack(spacing: 20) {
            PremiumStatCard(
                title: "Total Hours",
                value: 42.5,
                unit: "hrs",
                icon: "clock",
                trend: .init(delta: 4.2, label: "vs last period"),
                showRing: true,
                ringProgress: 0.85
            )

            EarningsHighlightCard(
                amount: 1847.50,
                label: "Estimated Earnings",
                subtitle: "This pay period"
            )

            StatGrid(stats: [
                ("Regular", "32.0 hrs", "sun.max", ShiftProColors.accent),
                ("Overtime", "10.5 hrs", "flame", ShiftProColors.warning),
                ("Breaks", "3.5 hrs", "cup.and.saucer", ShiftProColors.inkSubtle),
                ("Shifts", "6", "calendar", ShiftProColors.success)
            ])
        }
        .padding()
    }
    .background(ShiftProColors.background)
}
