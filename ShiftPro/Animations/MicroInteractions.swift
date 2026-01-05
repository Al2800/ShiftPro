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
