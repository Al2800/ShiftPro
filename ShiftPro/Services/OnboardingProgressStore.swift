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
}
