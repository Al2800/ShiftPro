import SwiftUI
import UIKit

enum ShiftProHaptic {
    case selection
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    case notification(UINotificationFeedbackGenerator.FeedbackType)

    @MainActor
    func fire() {
        switch self {
        case .selection:
            HapticManager.shared.selectionChanged()
        case .impact(let style):
            HapticManager.shared.impact(style)
        case .notification(let type):
            HapticManager.shared.notify(type)
        }
    }
}

extension ShiftProHaptic {
    static let impactLight = ShiftProHaptic.impact(.light)
    static let impactMedium = ShiftProHaptic.impact(.medium)
    static let impactHeavy = ShiftProHaptic.impact(.heavy)
    static let notificationSuccess = ShiftProHaptic.notification(.success)
    static let notificationWarning = ShiftProHaptic.notification(.warning)
    static let notificationError = ShiftProHaptic.notification(.error)
}

struct ShiftProPressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var opacity: Double = 0.94
    var haptic: ShiftProHaptic? = .selection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? scale : 1))
            .opacity(reduceMotion ? 1 : (configuration.isPressed ? opacity : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                guard isPressed, let haptic else { return }
                Task { @MainActor in
                    haptic.fire()
                }
            }
    }
}

struct PressableScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var opacity: Double = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(PressableScaleEffect(isPressed: configuration.isPressed, scale: scale, opacity: opacity))
    }
}

private struct PressableScaleEffect: ViewModifier {
    let isPressed: Bool
    let scale: CGFloat
    let opacity: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : (isPressed ? scale : 1))
            .opacity(reduceMotion ? 1 : (isPressed ? opacity : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isPressed)
    }
}

struct ShiftProPulse: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.04 : 1.0)
            .animation(
                AnimationManager.shared.animation(for: .subtle)?.repeatForever(autoreverses: true),
                value: isActive
            )
    }
}

struct ShiftProHoverLift: ViewModifier {
    var scale: CGFloat = 1.02
    var opacity: Double = 0.98

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                guard !reduceMotion else {
                    isHovering = false
                    return
                }
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
            .scaleEffect(reduceMotion ? 1 : (isHovering ? scale : 1))
            .opacity(reduceMotion ? 1 : (isHovering ? opacity : 1))
    }
}

struct ShiftProShake: GeometryEffect {
    var amount: CGFloat = 6
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

extension View {
    func shiftProPressable(
        scale: CGFloat = 0.97,
        opacity: Double = 0.94,
        haptic: ShiftProHaptic? = .selection
    ) -> some View {
        buttonStyle(ShiftProPressableStyle(scale: scale, opacity: opacity, haptic: haptic))
    }

    func shiftProPulse(isActive: Bool) -> some View {
        modifier(ShiftProPulse(isActive: isActive))
    }

    func shiftProShake(trigger: Bool) -> some View {
        modifier(ShiftProShake(animatableData: trigger ? 1 : 0))
    }

    func shiftProHoverLift(scale: CGFloat = 1.02, opacity: Double = 0.98) -> some View {
        modifier(ShiftProHoverLift(scale: scale, opacity: opacity))
    }
}

// MARK: - Premium Entrance Animations

struct SlideInModifier: ViewModifier {
    let delay: Double
    let direction: Edge
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(
                x: direction == .leading ? (isVisible ? 0 : -30) : (direction == .trailing ? (isVisible ? 0 : 30) : 0),
                y: direction == .top ? (isVisible ? 0 : -20) : (direction == .bottom ? (isVisible ? 0 : 20) : 0)
            )
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

struct FadeInScaleModifier: ViewModifier {
    let delay: Double
    let scale: CGFloat
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : scale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    let delayIncrement: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 15)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                let delay = baseDelay + (Double(index) * delayIncrement)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Bounce Effect

struct BounceModifier: ViewModifier {
    @Binding var trigger: Bool
    let intensity: CGFloat

    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { newValue in
                guard newValue else { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
                    scale = 1.0 + intensity
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.4).delay(0.15)) {
                    scale = 1.0
                }
                // Reset trigger
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    trigger = false
                }
            }
    }
}

// MARK: - Success Checkmark Animation

struct SuccessCheckmarkView: View {
    @Binding var isShowing: Bool

    @State private var circleScale: CGFloat = 0
    @State private var checkScale: CGFloat = 0
    @State private var checkTrim: CGFloat = 0

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(ShiftProColors.success)
                .frame(width: 80, height: 80)
                .scaleEffect(circleScale)

            // Checkmark
            Path { path in
                path.move(to: CGPoint(x: 24, y: 42))
                path.addLine(to: CGPoint(x: 36, y: 54))
                path.addLine(to: CGPoint(x: 56, y: 28))
            }
            .trim(from: 0, to: checkTrim)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .frame(width: 80, height: 80)
            .scaleEffect(checkScale)
        }
        .opacity(isShowing ? 1 : 0)
        .onChange(of: isShowing) { showing in
            if showing {
                animateIn()
            } else {
                reset()
            }
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            circleScale = 1
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.15)) {
            checkScale = 1
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.25)) {
            checkTrim = 1
        }
        HapticManager.fire(.notificationSuccess, enabled: true)
    }

    private func reset() {
        circleScale = 0
        checkScale = 0
        checkTrim = 0
    }
}

// MARK: - Ripple Effect

struct RippleModifier: ViewModifier {
    @Binding var trigger: Bool
    let color: Color

    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0.6

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(color)
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
            )
            .onChange(of: trigger) { newValue in
                guard newValue else { return }
                rippleScale = 0
                rippleOpacity = 0.6

                withAnimation(.easeOut(duration: 0.5)) {
                    rippleScale = 2.5
                    rippleOpacity = 0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    trigger = false
                }
            }
    }
}

// MARK: - Counter Animation

struct AnimatedCounterModifier: ViewModifier {
    let value: Int
    let duration: Double

    @State private var displayedValue: Int = 0

    func body(content: Content) -> some View {
        content
            .onAppear {
                animateValue(to: value)
            }
            .onChange(of: value) { newValue in
                animateValue(to: newValue)
            }
    }

    private func animateValue(to targetValue: Int) {
        let startValue = displayedValue
        let steps = 20
        let stepDuration = duration / Double(steps)

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (stepDuration * Double(step))) {
                let progress = Double(step) / Double(steps)
                let eased = 1 - pow(1 - progress, 3) // easeOutCubic
                displayedValue = startValue + Int(Double(targetValue - startValue) * eased)
            }
        }
    }
}

// MARK: - Extensions

extension View {
    func slideIn(delay: Double = 0, from direction: Edge = .bottom) -> some View {
        modifier(SlideInModifier(delay: delay, direction: direction))
    }

    func fadeInScale(delay: Double = 0, scale: CGFloat = 0.9) -> some View {
        modifier(FadeInScaleModifier(delay: delay, scale: scale))
    }

    func staggeredAppear(index: Int, baseDelay: Double = 0.1, increment: Double = 0.05) -> some View {
        modifier(StaggeredAppearModifier(index: index, baseDelay: baseDelay, delayIncrement: increment))
    }

    func bounceEffect(trigger: Binding<Bool>, intensity: CGFloat = 0.15) -> some View {
        modifier(BounceModifier(trigger: trigger, intensity: intensity))
    }

    func rippleEffect(trigger: Binding<Bool>, color: Color = ShiftProColors.accent) -> some View {
        modifier(RippleModifier(trigger: trigger, color: color))
    }
}
