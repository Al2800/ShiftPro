import Foundation
import SwiftUI

@MainActor
final class OnboardingManager: ObservableObject {
    @Published var step: OnboardingStep = .welcome
    @Published var data = OnboardingData()

    var progress: Double {
        let total = Double(OnboardingStep.allCases.count - 1)
        return Double(step.index) / total
    }

    func next() {
        guard let nextStep = step.next else { return }
        step = nextStep
    }

    func back() {
        guard let previous = step.previous else { return }
        step = previous
    }

    func skip() {
        guard step.isSkippable else { return }
        next()
    }

    func reset() {
        step = .welcome
        data = OnboardingData()
    }
}

enum OnboardingStep: CaseIterable {
    case welcome
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

    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
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

struct OnboardingData {
    var badgeNumber: String = ""
    var department: String = "Metro PD"
    var rank: String = "Officer"
    var startDate: Date = Date()
    var payPeriod: PayPeriodOption = .biweekly
    var regularHours: Double = 40
    var baseRate: Double = 42
    var selectedPattern: ShiftPatternOption = .twelveHour
    var wantsCalendarSync: Bool = true
    var wantsNotifications: Bool = true
}

enum PayPeriodOption: String, CaseIterable, Identifiable {
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
}

enum ShiftPatternOption: String, CaseIterable, Identifiable {
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
            return "Popular for patrol coverage"
        case .fourOnFourOff:
            return "Predictable blocks of time off"
        case .pitman:
            return "Alternating 2/3 day blocks"
        }
    }
}
