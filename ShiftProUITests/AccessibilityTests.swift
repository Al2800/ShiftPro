import XCTest

final class AccessibilityTests: XCTestCase {
    func testKeyAccessibilityIdentifiersExist() {
        let app = UITestHelper.makeApp()
        app.launch()

        XCTAssertTrue(app.buttons["onboarding.primary"].waitForExistence(timeout: 2))

        UITestHelper.openTab("Schedule", in: app)
        XCTAssertTrue(app.buttons["schedule.addShift"].waitForExistence(timeout: 2))
    }
}
