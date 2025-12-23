import XCTest

final class ShiftProUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments.append("-ui-testing")
        app.launch()
    }

    func testDashboardLoads() {
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["dashboard.heroCard"].exists)
        XCTAssertTrue(app.buttons["dashboard.action.startShift"].exists)
    }

    func testShiftCardExpansion() {
        let detailsButton = app.buttons["View details"].firstMatch
        XCTAssertTrue(detailsButton.waitForExistence(timeout: 2))
        detailsButton.tap()
        XCTAssertTrue(app.buttons["Hide details"].exists)
    }

    func testTabSwitchingToSettings() {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 2))
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }
}
