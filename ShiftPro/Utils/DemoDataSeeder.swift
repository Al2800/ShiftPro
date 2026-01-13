import Foundation
import SwiftData

/// Seeds realistic demo data for App Store screenshots
enum DemoDataSeeder {

    static var isDemoMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-mode")
    }

    /// Seeds the database with demo data for screenshots
    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        guard isDemoMode else { return }

        // Check if we already have data
        let descriptor = FetchDescriptor<UserProfile>()
        let existingProfiles = (try? context.fetch(descriptor)) ?? []
        guard existingProfiles.isEmpty else { return }

        seedDemoData(context: context)
    }

    @MainActor
    private static func seedDemoData(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        // Create user profile
        let profile = UserProfile(
            employeeId: "4821",
            workplace: "Metro Police Dept",
            jobTitle: "Sergeant",
            startDate: calendar.date(byAdding: .year, value: -3, to: now) ?? now,
            baseRateCents: 3250, // $32.50/hour
            regularHoursPerPay: 80,
            payPeriodType: .biweekly
        )
        context.insert(profile)

        // Create a 4-on/4-off pattern
        let pattern = ShiftPattern(
            name: "4 On / 4 Off",
            scheduleType: .cycling,
            startMinuteOfDay: 7 * 60, // 7:00 AM
            durationMinutes: 720, // 12 hours
            cycleStartDate: calendar.date(byAdding: .day, value: -14, to: now),
            isActive: true,
            colorHex: "#4A90D9",
            shortCode: "D",
            owner: profile
        )
        context.insert(pattern)

        // Create shifts for the past 2 weeks and next week
        var shifts: [Shift] = []

        // Past completed shifts (last 14 days)
        for dayOffset in stride(from: -14, through: -1, by: 1) {
            // 4-on/4-off pattern: work days 1-4, off days 5-8, repeat
            let cycleDay = ((14 + dayOffset) % 8) + 1
            guard cycleDay <= 4 else { continue } // Only work first 4 days of cycle

            guard let shiftDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }

            let startComponents = calendar.dateComponents([.year, .month, .day], from: shiftDate)
            var start = calendar.date(from: startComponents) ?? shiftDate
            start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: start) ?? start
            let end = calendar.date(byAdding: .hour, value: 12, to: start) ?? start

            // Vary the actual times slightly for realism
            let actualStartOffset = Int.random(in: -10...5)
            let actualEndOffset = Int.random(in: -5...15)
            let actualStart = calendar.date(byAdding: .minute, value: actualStartOffset, to: start)
            let actualEnd = calendar.date(byAdding: .minute, value: actualEndOffset, to: end)

            // Some shifts have overtime rate
            let hasOvertime = dayOffset == -2 || dayOffset == -7
            let rateMultiplier = hasOvertime ? 1.5 : 1.0
            let rateLabel = hasOvertime ? "Overtime" : nil

            let shift = Shift(
                scheduledStart: start,
                scheduledEnd: end,
                actualStart: actualStart,
                actualEnd: actualEnd,
                breakMinutes: 30,
                status: .completed,
                paidMinutes: 690, // 11.5 hours
                rateMultiplier: rateMultiplier,
                rateLabel: rateLabel,
                pattern: pattern,
                owner: profile
            )
            shifts.append(shift)
        }

        // Today's shift - in progress
        let todayStart = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
        let todayEnd = calendar.date(byAdding: .hour, value: 12, to: todayStart) ?? now
        let todayShift = Shift(
            scheduledStart: todayStart,
            scheduledEnd: todayEnd,
            actualStart: calendar.date(byAdding: .minute, value: -3, to: todayStart), // Clocked in 3 min early
            breakMinutes: 30,
            status: .inProgress,
            pattern: pattern,
            owner: profile
        )
        shifts.append(todayShift)

        // Future scheduled shifts (next 7 days following pattern)
        for dayOffset in 1...7 {
            let cycleDay = ((14 + dayOffset) % 8) + 1
            guard cycleDay <= 4 else { continue }

            guard let shiftDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }

            let startComponents = calendar.dateComponents([.year, .month, .day], from: shiftDate)
            var start = calendar.date(from: startComponents) ?? shiftDate
            start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: start) ?? start
            let end = calendar.date(byAdding: .hour, value: 12, to: start) ?? start

            let shift = Shift(
                scheduledStart: start,
                scheduledEnd: end,
                breakMinutes: 30,
                status: .scheduled,
                pattern: pattern,
                owner: profile
            )
            shifts.append(shift)
        }

        // Insert all shifts
        for shift in shifts {
            shift.recalculatePaidMinutes()
            context.insert(shift)
        }

        // Save
        try? context.save()
    }
}
