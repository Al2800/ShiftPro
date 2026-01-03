import Foundation

struct OnboardingProgress: Codable {
    let version: Int
    let step: OnboardingStep
    let data: OnboardingData
    let skippedSteps: [OnboardingStep]
    let lastUpdated: Date
}

enum OnboardingProgressStore {
    private static let key = "onboardingProgress"
    private static let version = 1

    static func load() -> OnboardingProgress? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            let progress = try JSONDecoder().decode(OnboardingProgress.self, from: data)
            guard progress.version == version else {
                clear()
                return nil
            }
            return progress
        } catch {
            clear()
            return nil
        }
    }

    static func save(step: OnboardingStep, data: OnboardingData, skippedSteps: [OnboardingStep]) {
        let progress = OnboardingProgress(
            version: version,
            step: step,
            data: data,
            skippedSteps: skippedSteps,
            lastUpdated: Date()
        )

        do {
            let encoded = try JSONEncoder().encode(progress)
            UserDefaults.standard.set(encoded, forKey: key)
        } catch {
            return
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static var hasProgress: Bool {
        load() != nil
    }

    // MARK: - Skipped Steps (persisted after completion)

    private static let skippedStepsKey = "onboardingSkippedSteps"

    static func saveSkippedSteps(_ steps: [OnboardingStep]) {
        guard !steps.isEmpty else {
            clearSkippedSteps()
            return
        }
        do {
            let encoded = try JSONEncoder().encode(steps.map { $0.rawValue })
            UserDefaults.standard.set(encoded, forKey: skippedStepsKey)
        } catch {
            return
        }
    }

    static func loadSkippedSteps() -> [OnboardingStep] {
        guard let data = UserDefaults.standard.data(forKey: skippedStepsKey) else { return [] }
        do {
            let rawValues = try JSONDecoder().decode([String].self, from: data)
            return rawValues.compactMap { OnboardingStep(rawValue: $0) }
        } catch {
            return []
        }
    }

    static func clearSkippedSteps() {
        UserDefaults.standard.removeObject(forKey: skippedStepsKey)
    }

    static var hasSkippedSteps: Bool {
        !loadSkippedSteps().isEmpty
    }
}
