import Foundation
import SwiftData

@MainActor
struct OnboardingPersistenceService {
    private let context: ModelContext
    private let profileRepository: UserProfileRepository
    private let patternEngine: PatternEngine
    private let calculator = HoursCalculator()

    init(context: ModelContext) {
        self.context = context
        self.profileRepository = UserProfileRepository(context: context)
        self.patternEngine = PatternEngine()
    }

    func persist(data: OnboardingData) throws {
        let profile = try profileRepository.ensurePrimary()
        data.apply(to: profile)
        try profileRepository.update(profile)

        try persistNotificationSettings(for: profile, data: data)
        try persistDefaultPattern(for: profile, data: data)
        try persistPayRuleset(for: profile, data: data)

        let calendarSettings = data.calendarSyncSettings()
        calendarSettings.save()

        UserDefaults.standard.set(true, forKey: "hasOnboarded")
        UserDefaults.standard.set(1, forKey: "onboardingVersion")
    }

    private func persistNotificationSettings(for profile: UserProfile, data: OnboardingData) throws {
        if let existing = try fetchNotificationSettings(for: profile) {
            if !data.wantsNotifications {
                existing.shiftStartReminderEnabled = false
                existing.shiftEndSummaryEnabled = false
                existing.overtimeWarningEnabled = false
                existing.weeklySummaryEnabled = false
                existing.markUpdated()
                try context.save()
            }
            return
        }

        let settings = data.makeNotificationSettings(owner: profile)
        context.insert(settings)
        try context.save()
    }

    private func persistDefaultPattern(for profile: UserProfile, data: OnboardingData) throws {
        if let existing = try fetchPatterns(for: profile), !existing.isEmpty {
            return
        }

        let definition = data.selectedPatternDefinition()
        let pattern = patternEngine.buildPattern(from: definition, owner: profile)
        pattern.cycleStartDate = data.patternStartDate
        context.insert(pattern)
        for rotationDay in pattern.rotationDays {
            context.insert(rotationDay)
        }
        try context.save()

        try generateInitialShifts(for: pattern, startDate: data.patternStartDate, owner: profile)
    }

    private func generateInitialShifts(for pattern: ShiftPattern, startDate: Date, owner: UserProfile) throws {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 2, to: startDate) ?? startDate
        let periodEngine = PayPeriodEngine(context: context, calculator: calculator)

        let shifts = patternEngine.generateShifts(for: pattern, from: startDate, to: endDate, owner: owner)
        for shift in shifts {
            calculator.updateCalculatedFields(for: shift)
            context.insert(shift)
            try periodEngine.assignToPeriod(shift, type: owner.payPeriodType)
        }
        try context.save()
    }

    private func persistPayRuleset(for profile: UserProfile, data: OnboardingData) throws {
        if profile.activePayRuleset != nil {
            return
        }

        let ruleset = PayRuleset.standardShiftWorker(owner: profile, payPeriodType: data.payPeriodType)
        context.insert(ruleset)
        profile.activePayRuleset = ruleset
        try context.save()
    }

    private func fetchNotificationSettings(for profile: UserProfile) throws -> NotificationSettings? {
        let ownerID = profile.id
        let predicate = #Predicate<NotificationSettings> { settings in
            settings.owner?.id == ownerID
        }
        let descriptor = FetchDescriptor<NotificationSettings>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    private func fetchPatterns(for profile: UserProfile) throws -> [ShiftPattern]? {
        let ownerID = profile.id
        let predicate = #Predicate<ShiftPattern> { pattern in
            pattern.owner?.id == ownerID
        }
        let descriptor = FetchDescriptor<ShiftPattern>(predicate: predicate)
        return try context.fetch(descriptor)
    }
}
