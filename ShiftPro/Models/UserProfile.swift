import Foundation
import SwiftData

/// User profile containing settings, pay rules, and workplace information.
/// This is the root entity that owns patterns, shifts, and pay rulesets.
@Model
final class UserProfile {
    // MARK: - Primary Key
    @Attribute(.unique) var id: UUID

    // MARK: - User Information
    @Attribute(originalName: "badgeNumber") var employeeId: String?
    @Attribute(originalName: "department") var workplace: String?
    @Attribute(originalName: "rank") var jobTitle: String?
    var startDate: Date

    // MARK: - Pay Configuration
    /// Base hourly rate stored in cents to avoid floating point errors
    var baseRateCents: Int64?
    /// Standard hours per pay period (e.g., 80 for bi-weekly)
    var regularHoursPerPay: Int
    /// Raw value for PayPeriodType enum (for CloudKit compatibility)
    var payPeriodTypeRaw: Int16
    /// User's preferred timezone identifier
    var timeZoneIdentifier: String

    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify, inverse: \ShiftPattern.owner)
    var patterns: [ShiftPattern] = []

    @Relationship(deleteRule: .nullify, inverse: \Shift.owner)
    var shifts: [Shift] = []

    @Relationship(deleteRule: .nullify, inverse: \PayRuleset.owner)
    var payRulesets: [PayRuleset] = []

    @Relationship(deleteRule: .nullify)
    var activePayRuleset: PayRuleset?

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        employeeId: String? = nil,
        workplace: String? = nil,
        jobTitle: String? = nil,
        startDate: Date = Date(),
        baseRateCents: Int64? = nil,
        regularHoursPerPay: Int = 80,
        payPeriodType: PayPeriodType = .biweekly,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.employeeId = employeeId
        self.workplace = workplace
        self.jobTitle = jobTitle
        self.startDate = startDate
        self.baseRateCents = baseRateCents
        self.regularHoursPerPay = regularHoursPerPay
        self.payPeriodTypeRaw = payPeriodType.rawValue
        self.timeZoneIdentifier = timeZoneIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties
extension UserProfile {
    /// The pay period type enum value
    var payPeriodType: PayPeriodType {
        get { PayPeriodType(rawValue: payPeriodTypeRaw) ?? .biweekly }
        set { payPeriodTypeRaw = newValue.rawValue }
    }

    /// The user's timezone
    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    /// Base hourly rate in dollars (computed from cents)
    var baseRateDollars: Double? {
        guard let cents = baseRateCents else { return nil }
        return Double(cents) / 100.0
    }

    /// Sets the base rate from a dollar amount
    func setBaseRate(dollars: Double?) {
        if let dollars = dollars {
            baseRateCents = Int64(dollars * 100)
        } else {
            baseRateCents = nil
        }
    }

    /// Regular hours per pay period in hours (from minutes)
    var regularHoursPerPayPeriod: Double {
        Double(regularHoursPerPay)
    }

    /// Display name for the user
    var displayName: String {
        if let title = jobTitle, !title.isEmpty {
            return title
        }
        if let place = workplace, !place.isEmpty {
            return place
        }
        if let empId = employeeId, !empId.isEmpty {
            return "ID: \(empId)"
        }
        return "User"
    }

    /// Active shift patterns (not deleted)
    var activePatterns: [ShiftPattern] {
        patterns.filter { $0.deletedAt == nil && $0.isActive }
    }

    /// Recent shifts (not deleted, sorted by date)
    var recentShifts: [Shift] {
        shifts
            .filter { $0.deletedAt == nil }
            .sorted { $0.scheduledStart > $1.scheduledStart }
    }

    /// User's name (using displayName as alias)
    var name: String { displayName }

    /// Target weekly hours (derived from regularHoursPerPay)
    var targetWeeklyHours: Int {
        // Convert based on pay period type
        switch payPeriodType {
        case .weekly:
            return regularHoursPerPay
        case .biweekly:
            return regularHoursPerPay / 2
        case .monthly:
            return 40  // Default to 40 hours/week
        }
    }
}

// MARK: - Convenience Methods
extension UserProfile {
    /// Marks the profile as updated
    func markUpdated() {
        updatedAt = Date()
    }
}
