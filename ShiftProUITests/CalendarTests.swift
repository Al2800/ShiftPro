import XCTest

final class CalendarTests: XCTestCase {
    func testCalendarSettingsNavigation() {
        let app = UITestHelper.makeApp()
        app.launch()

        UITestHelper.openTab("Settings", in: app)

        let calendarCell = app.staticTexts["Calendar Settings"]
        XCTAssertTrue(calendarCell.waitForExistence(timeout: 2))
        calendarCell.tap()

        let navTitle = app.navigationBars["Calendar Settings"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 2))
    }
}
