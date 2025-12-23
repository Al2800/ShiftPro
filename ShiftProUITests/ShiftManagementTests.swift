import XCTest

final class ShiftManagementTests: XCTestCase {
    func testScheduleTabShowsAddShiftButton() {
        let app = UITestHelper.makeApp()
        app.launch()

        UITestHelper.openTab("Schedule", in: app)

        let addShiftButton = app.buttons["schedule.addShift"]
        XCTAssertTrue(addShiftButton.waitForExistence(timeout: 2))
    }
}
