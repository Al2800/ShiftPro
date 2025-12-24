import SwiftUI

struct ShimmerView: View {
    var cornerRadius: CGFloat = 14
    var isActive: Bool = true

    @State private var phase: CGFloat = -0.7
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let gradient = LinearGradient(
                gradient: Gradient(colors: [
                    ShiftProColors.surfaceMuted,
                    ShiftProColors.surfaceElevated,
                    ShiftProColors.surfaceMuted
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(ShiftProColors.surfaceMuted)
                .overlay(
                    gradient
                        .rotationEffect(.degrees(20))
                        .offset(x: proxy.size.width * phase)
                        .blendMode(.plusLighter)
                )
                .clipped()
                .onAppear {
                    guard isActive, !reduceMotion else { return }
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 0.7
                    }
                }
        }
    }
}

struct LoadingDots: View {
    var color: Color = ShiftProColors.accent
    var size: CGFloat = 8

    @State private var scale: CGFloat = 0.7
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .scaleEffect(scale)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.12),
                        value: scale
                    )
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            scale = 1
        }
    }
}

struct LoadingStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: ShiftProSpacing.medium) {
            LoadingDots()
            Text(title)
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)
            Text(message)
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.inkSubtle)
                .multilineTextAlignment(.center)
        }
        .padding(ShiftProSpacing.large)
        .frame(maxWidth: .infinity)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
