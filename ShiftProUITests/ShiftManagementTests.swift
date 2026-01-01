import XCTest

final class ShiftManagementTests: XCTestCase {
    func testScheduleTabShowsAddShiftButton() {
        let app = UITestHelper.makeApp()
        app.launchArguments.append("-skip-onboarding")
        app.launch()

        UITestHelper.openTab("Schedule", in: app)

        let addShiftButton = app.buttons["schedule.addShift"]
        XCTAssertTrue(addShiftButton.waitForExistence(timeout: 2))
    }

    func testShiftCRUDFlow() {
        let app = UITestHelper.makeApp()
        app.launchArguments.append("-skip-onboarding")
        app.launch()

        UITestHelper.openTab("Schedule", in: app)

        let seedButton = app.buttons["test.shift.seed"]
        XCTAssertTrue(seedButton.waitForExistence(timeout: 2))
        seedButton.tap()

        let initialTimeRange = app.staticTexts["09:00 - 17:00"]
        XCTAssertTrue(initialTimeRange.waitForExistence(timeout: 2))

        let editButton = app.buttons["test.shift.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2))
        editButton.tap()

        let updatedTimeRange = app.staticTexts["09:00 - 19:00"]
        XCTAssertTrue(updatedTimeRange.waitForExistence(timeout: 2))

        let deleteButton = app.buttons["test.shift.delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        XCTAssertFalse(updatedTimeRange.waitForExistence(timeout: 2))
    }
}
