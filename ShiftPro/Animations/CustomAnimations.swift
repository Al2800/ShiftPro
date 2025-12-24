import SwiftUI

struct MilestoneCelebrationView: View {
    var isActive: Bool

    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isActive {
                ForEach(0..<18, id: \.self) { index in
                    ConfettiParticle(index: index, animate: animate)
                }
            }
        }
        .onAppear {
            guard isActive, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.0)) {
                animate = true
            }
        }
        .onChange(of: isActive) { newValue in
            guard newValue, !reduceMotion else { return }
            animate = false
            withAnimation(.easeOut(duration: 1.0)) {
                animate = true
            }
        }
    }
}

private struct ConfettiParticle: View {
    let index: Int
    let animate: Bool

    private var color: Color {
        let palette: [Color] = [ShiftProColors.accent, ShiftProColors.success, ShiftProColors.warning]
        return palette[index % palette.count]
    }

    private var angle: Double {
        Double(index) * 18
    }

    private var distance: CGFloat {
        60 + CGFloat(index % 5) * 12
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .offset(x: animate ? distance : 0, y: animate ? -distance : 0)
            .rotationEffect(.degrees(angle))
            .opacity(animate ? 0 : 1)
    }
}

struct AnimatedProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(ShiftProColors.surfaceMuted, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    ShiftProColors.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(AnimationManager.shared.animation(for: .standard), value: progress)
        }
    }
}
