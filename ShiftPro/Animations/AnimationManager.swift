import SwiftUI
import UIKit

@MainActor
final class AnimationManager: ObservableObject {
    static let shared = AnimationManager()

    @Published private(set) var reduceMotionEnabled: Bool
    @Published private(set) var isLowPowerModeEnabled: Bool

    private init() {
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReduceMotionChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerModeChange),
            name: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    var shouldAnimate: Bool {
        !(reduceMotionEnabled || isLowPowerModeEnabled)
    }

    func animation(for preset: ShiftProAnimationPreset) -> Animation? {
        guard shouldAnimate else { return nil }

        switch preset {
        case .quick:
            return .easeOut(duration: 0.18)
        case .standard:
            return .easeInOut(duration: 0.32)
        case .bouncy:
            return .spring(response: 0.45, dampingFraction: 0.78)
        case .slow:
            return .easeInOut(duration: 0.6)
        case .subtle:
            return .easeInOut(duration: 0.24)
        }
    }

    static func animation(_ preset: ShiftProAnimationPreset, reduceMotion: Bool) -> Animation? {
        guard !reduceMotion, !UITestSupport.isUITesting else { return nil }
        return AnimationManager.shared.animation(for: preset)
    }

    @objc private func handleReduceMotionChange() {
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    }

    @objc private func handlePowerModeChange() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

enum ShiftProAnimationPreset {
    case quick
    case standard
    case bouncy
    case slow
    case subtle
}
