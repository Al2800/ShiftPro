import XCTest

final class PatternTests: XCTestCase {
    func testPatternStepAppearsInOnboarding() {
        let app = UITestHelper.makeApp()
        app.launch()

        let primaryButton = app.buttons["onboarding.primary"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))

        for _ in 0..<4 {
            primaryButton.tap()
        }

        XCTAssertTrue(app.staticTexts["Shift Pattern"].waitForExistence(timeout: 2))
    }
}
