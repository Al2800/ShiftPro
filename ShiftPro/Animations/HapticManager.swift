import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func selectionChanged() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }

    static func fire(_ feedback: ShiftProHaptic, enabled: Bool = true) {
        guard enabled else { return }
        Task { @MainActor in
            feedback.fire()
        }
    }
}
