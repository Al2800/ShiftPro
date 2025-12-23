import XCTest

final class ShiftProAccessibilityTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments.append("-ui-testing")
        app.launch()
    }

    func testDashboardAccessibilityIdentifiers() {
        XCTAssertTrue(app.otherElements["dashboard.heroCard"].exists)
        XCTAssertTrue(app.buttons["dashboard.action.logBreak"].exists)
        XCTAssertTrue(app.buttons["dashboard.action.addShift"].exists)
    }

    func testHoursSectionVisible() {
        XCTAssertTrue(app.staticTexts["Hours"].exists)
        XCTAssertTrue(app.staticTexts["Total Hours"].exists)
    }
}
