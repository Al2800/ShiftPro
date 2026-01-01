import Foundation
import SwiftData

/// Configurable pay rules stored as JSON for flexibility across employers or teams.
/// Supports unpaid breaks, rate multipliers, and pay period settings.
@Model
final class PayRuleset {
    // MARK: - Primary Key
    @Attribute(.unique) var id: UUID

    // MARK: - Identification
    var name: String

    /// Schema version for migration support
    var schemaVersion: Int16

    /// JSON string containing the rules configuration
    var rulesJSON: String

    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var owner: UserProfile?

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        name: String,
        schemaVersion: Int16 = 1,
        rulesJSON: String = PayRules.defaultRulesJSON,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        owner: UserProfile? = nil
    ) {
        self.id = id
        self.name = name
        self.schemaVersion = schemaVersion
        self.rulesJSON = rulesJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.owner = owner
    }
}

// MARK: - Computed Properties
extension PayRuleset {
    /// Decoded rules from JSON
    var rules: PayRules? {
        get {
            guard let data = rulesJSON.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(PayRules.self, from: data)
        }
        set {
            guard let newValue = newValue,
                  let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else { return }
            rulesJSON = json
            updatedAt = Date()
        }
    }

    /// Unpaid break minutes from rules (default 30)
    var unpaidBreakMinutes: Int {
        rules?.unpaidBreakMinutes ?? 30
    }

    /// Available rate multipliers
    var rateMultipliers: [PayRules.RateMultiplierConfig] {
        rules?.rateMultipliers ?? PayRules.defaultMultipliers
    }

    /// Pay period type from rules
    var payPeriodType: PayPeriodType {
        PayPeriodType(rawValue: rules?.payPeriodTypeRaw ?? 1) ?? .biweekly
    }
}

// MARK: - Convenience Methods
extension PayRuleset {
    /// Marks the ruleset as updated
    func markUpdated() {
        updatedAt = Date()
    }

    /// Creates a copy of this ruleset with a new name
    func duplicate(withName newName: String) -> PayRuleset {
        PayRuleset(
            name: newName,
            schemaVersion: schemaVersion,
            rulesJSON: rulesJSON,
            owner: owner
        )
    }

    /// Resets to default rules
    func resetToDefaults() {
        rules = PayRules.defaults
    }
}

// MARK: - Pay Rules Structure

/// Decodable structure for pay rules JSON
struct PayRules: Codable, Sendable {
    let schemaVersion: Int
    let unpaidBreakMinutes: Int
    let rateMultipliers: [RateMultiplierConfig]
    let payPeriodTypeRaw: Int16

    struct RateMultiplierConfig: Codable, Sendable, Identifiable {
        let id: UUID
        let label: String
        let multiplier: Double

        init(id: UUID = UUID(), label: String, multiplier: Double) {
            self.id = id
            self.label = label
            self.multiplier = multiplier
        }
    }

    init(
        schemaVersion: Int = 1,
        unpaidBreakMinutes: Int = 30,
        rateMultipliers: [RateMultiplierConfig] = PayRules.defaultMultipliers,
        payPeriodType: PayPeriodType = .biweekly
    ) {
        self.schemaVersion = schemaVersion
        self.unpaidBreakMinutes = unpaidBreakMinutes
        self.rateMultipliers = rateMultipliers
        self.payPeriodTypeRaw = payPeriodType.rawValue
    }

    /// Default rate multipliers
    static let defaultMultipliers: [RateMultiplierConfig] = [
        RateMultiplierConfig(label: "Regular", multiplier: 1.0),
        RateMultiplierConfig(label: "Overtime (Bracket)", multiplier: 1.3),
        RateMultiplierConfig(label: "Extra", multiplier: 1.5),
        RateMultiplierConfig(label: "Bank Holiday", multiplier: 2.0)
    ]

    /// Default rules configuration
    static let defaults = PayRules()

    /// Default rules as JSON string
    static var defaultRulesJSON: String {
        guard let data = try? JSONEncoder().encode(defaults),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - Factory Methods
extension PayRuleset {
    /// Creates a standard shift-worker ruleset
    static func standardShiftWorker(
        owner: UserProfile? = nil,
        payPeriodType: PayPeriodType = .biweekly
    ) -> PayRuleset {
        let rules = PayRules(
            unpaidBreakMinutes: 30,
            rateMultipliers: [
                .init(label: "Regular", multiplier: 1.0),
                .init(label: "Overtime (1.3x)", multiplier: 1.3),
                .init(label: "Extra Shift", multiplier: 1.5),
                .init(label: "Bank Holiday", multiplier: 2.0)
            ],
            payPeriodType: payPeriodType
        )

        let json = try? JSONEncoder().encode(rules)
        let jsonString = json.flatMap { String(data: $0, encoding: .utf8) } ?? PayRules.defaultRulesJSON

        return PayRuleset(
            name: "Standard Shift Ruleset",
            rulesJSON: jsonString,
            owner: owner
        )
    }

    /// Creates a simple hourly ruleset
    static func simpleHourly(owner: UserProfile? = nil) -> PayRuleset {
        let rules = PayRules(
            unpaidBreakMinutes: 0,
            rateMultipliers: [
                .init(label: "Regular", multiplier: 1.0),
                .init(label: "Overtime", multiplier: 1.5)
            ],
            payPeriodType: .biweekly
        )

        let json = try? JSONEncoder().encode(rules)
        let jsonString = json.flatMap { String(data: $0, encoding: .utf8) } ?? PayRules.defaultRulesJSON

        return PayRuleset(
            name: "Simple Hourly",
            rulesJSON: jsonString,
            owner: owner
        )
    }
}
