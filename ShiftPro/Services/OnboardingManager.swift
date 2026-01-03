import Foundation
import SwiftUI
import SwiftData

@MainActor
final class OnboardingManager: ObservableObject {
    @Published var step: OnboardingStep = .welcome {
        didSet { persistProgress() }
    }
    @Published var data = OnboardingData() {
        didSet { persistProgress() }
    }
    @Published private(set) var skippedSteps: Set<OnboardingStep> = [] {
        didSet { persistProgress() }
    }

    private var hasRestoredProgress = false

    init() {
        restoreProgress()
        hasRestoredProgress = true
    }

    var progress: Double {
        let total = Double(OnboardingStep.allCases.count - 1)
        return Double(step.index) / total
    }

    func next() {
        advance(clearSkipped: true)
    }

    func back() {
        guard let previous = step.previous else { return }
        step = previous
    }

    func skip() {
        guard step.isSkippable else { return }
        skippedSteps.insert(step)
        advance(clearSkipped: false)
    }

    func reset() {
        step = .welcome
        data = OnboardingData()
        skippedSteps = []
        OnboardingProgressStore.clear()
    }

    // MARK: - Persistence

    /// Persists onboarding data to SwiftData models.
    /// Call this when user completes onboarding (taps "Start Using ShiftPro").
    func persist(context: ModelContext) throws {
        try OnboardingPersistenceService(context: context).persist(data: data)
        OnboardingProgressStore.clear()
    }

    // MARK: - Progress

    var hasSkippedOptionalSteps: Bool {
        !skippedSteps.isEmpty
    }

    func isStepSkipped(_ step: OnboardingStep) -> Bool {
        skippedSteps.contains(step)
    }

    // MARK: - Validation

    struct ValidationResult {
        let isValid: Bool
        let message: String?
    }

    var canProceed: Bool {
        validation(for: step).isValid
    }

    var validationMessage: String? {
        validation(for: step).message
    }

    private func validation(for step: OnboardingStep) -> ValidationResult {
        switch step {
        case .profile:
            if data.startDate > Date().addingTimeInterval(60 * 60 * 24 * 365) {
                return ValidationResult(
                    isValid: false,
                    message: "Start date looks too far in the future."
                )
            }
            return ValidationResult(isValid: true, message: nil)
        case .payPeriod:
            if data.regularHours <= 0 {
                return ValidationResult(isValid: false, message: "Add at least 1 regular hour.")
            }
            if data.baseRate < 0 {
                return ValidationResult(isValid: false, message: "Base rate can’t be negative.")
            }
            return ValidationResult(isValid: true, message: nil)
        default:
            return ValidationResult(isValid: true, message: nil)
        }
    }

    private func advance(clearSkipped: Bool) {
        guard let nextStep = step.next else { return }
        if clearSkipped {
            skippedSteps.remove(step)
        }
        step = nextStep
    }

    private func restoreProgress() {
        guard let progress = OnboardingProgressStore.load() else { return }
        step = progress.step
        data = progress.data
        skippedSteps = Set(progress.skippedSteps)
    }

    private func persistProgress() {
        guard hasRestoredProgress else { return }
        OnboardingProgressStore.save(
            step: step,
            data: data,
            skippedSteps: Array(skippedSteps)
        )
    }
}

enum OnboardingStep: String, CaseIterable, Codable {
    case welcome
    case valuePreview
    case permissions
    case profile
    case payPeriod
    case pattern
    case calendar
    case completion

    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    var next: OnboardingStep? {
        let nextIndex = index + 1
        guard nextIndex < Self.allCases.count else { return nil }
        return Self.allCases[nextIndex]
    }

    var previous: OnboardingStep? {
        let prevIndex = index - 1
        guard prevIndex >= 0 else { return nil }
        return Self.allCases[prevIndex]
    }

    var isSkippable: Bool {
        switch self {
        case .permissions, .pattern, .calendar:
            return true
        default:
            return false
        }
    }

    var requirementLabel: String {
        switch self {
        case .welcome, .valuePreview, .completion:
            return ""
        default:
            return isSkippable ? "Optional" : "Required"
        }
    }

    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .valuePreview:
            return "Preview"
        case .permissions:
            return "Permissions"
        case .profile:
            return "Profile"
        case .payPeriod:
            return "Pay Period"
        case .pattern:
            return "Shift Pattern"
        case .calendar:
            return "Calendar"
        case .completion:
            return "All Set"
        }
    }
}

struct OnboardingData: Codable {
    var employeeId: String = ""
    var workplace: String = ""
    var jobTitle: String = ""
    var startDate: Date = Date()
    var payPeriod: PayPeriodOption = .biweekly
    var regularHours: Double = 40
    var baseRate: Double = 25
    var selectedPattern: ShiftPatternOption = .eightHour
    var patternStartDate: Date = Date()
    var wantsCalendarSync: Bool = true
    var wantsNotifications: Bool = true
}

enum PayPeriodOption: String, CaseIterable, Identifiable, Codable {
    case weekly
    case biweekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly:
            return "Weekly"
        case .biweekly:
            return "Bi-Weekly"
        case .monthly:
            return "Monthly"
        }
    }

    func toPayPeriodType() -> PayPeriodType {
        switch self {
        case .weekly:
            return .weekly
        case .biweekly:
            return .biweekly
        case .monthly:
            return .monthly
        }
    }
}

enum ShiftPatternOption: String, CaseIterable, Identifiable, Codable {
    case eightHour
    case twelveHour
    case fourOnFourOff
    case pitman

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eightHour:
            return "8-hour Rotation"
        case .twelveHour:
            return "12-hour Rotation"
        case .fourOnFourOff:
            return "4-on / 4-off"
        case .pitman:
            return "Pitman"
        }
    }

    var summary: String {
        switch self {
        case .eightHour:
            return "Balanced 3-shift rotation"
        case .twelveHour:
            return "Popular for 24/7 coverage"
        case .fourOnFourOff:
            return "Predictable blocks of time off"
        case .pitman:
            return "Alternating 2/3 day blocks"
        }
    }
}
