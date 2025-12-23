import XCTest

final class HoursTests: XCTestCase {
    func testHoursDashboardLoads() {
        let app = UITestHelper.makeApp()
        app.launch()

        UITestHelper.openTab("Hours", in: app)

        let navTitle = app.navigationBars["Hours"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 2))
    }
}
