import XCTest

final class OnboardingTests: XCTestCase {
    func testOnboardingPrimaryButtonIsVisible() {
        let app = UITestHelper.makeApp()
        app.launch()

        let primaryButton = app.buttons["onboarding.primary"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))
    }

    func testOnboardingAdvanceShowsBackButton() {
        let app = UITestHelper.makeApp()
        app.launch()

        let primaryButton = app.buttons["onboarding.primary"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))
        primaryButton.tap()

        let backButton = app.buttons["onboarding.back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 2))
    }
}
