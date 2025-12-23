import XCTest
@testable import ShiftPro

final class PayRulesetTests: XCTestCase {
    func testDefaultsDecode() {
        let ruleset = PayRuleset(name: "Default")
        XCTAssertNotNil(ruleset.rules)
        XCTAssertEqual(ruleset.unpaidBreakMinutes, 30)
        XCTAssertFalse(ruleset.rateMultipliers.isEmpty)
    }

    func testRulesMutationUpdatesJson() {
        var custom = PayRules(
            schemaVersion: 1,
            unpaidBreakMinutes: 45,
            rateMultipliers: PayRules.defaultMultipliers,
            payPeriodType: .weekly
        )
        let ruleset = PayRuleset(name: "Custom")
        ruleset.rules = custom

        XCTAssertEqual(ruleset.unpaidBreakMinutes, 45)
        XCTAssertEqual(ruleset.payPeriodType, .weekly)
    }
}
