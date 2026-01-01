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

    func testOnboardingPersistsProfileDetails() {
        let app = UITestHelper.makeApp()
        app.launch()

        let primaryButton = app.buttons["onboarding.primary"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))
        primaryButton.tap()

        let workplaceField = app.textFields["Workplace (optional)"]
        XCTAssertTrue(workplaceField.waitForExistence(timeout: 2))
        enterText("Test Workplace", into: workplaceField, in: app)

        let roleField = app.textFields["Job Title (optional)"]
        enterText("Test Role", into: roleField, in: app)

        let employeeIdField = app.textFields["Employee ID (optional)"]
        enterText("E123", into: employeeIdField, in: app)

        advanceOnboarding(in: app, maxSteps: 8)
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 4))
        UITestHelper.openTab("Settings", in: app)

        XCTAssertTrue(app.staticTexts["Test Workplace"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Test Role"].exists)
        XCTAssertTrue(app.staticTexts["E123"].exists)
    }

    private func advanceOnboarding(in app: XCUIApplication, maxSteps: Int) {
        let primaryButton = app.buttons["onboarding.primary"]
        let skipButton = app.buttons["onboarding.skip"]

        for _ in 0..<maxSteps {
            if app.tabBars.buttons["Settings"].exists {
                break
            }

            if primaryButton.waitForExistence(timeout: 1) {
                primaryButton.tap()
                continue
            }

            if skipButton.waitForExistence(timeout: 1) {
                skipButton.tap()
                continue
            }

            break
        }
    }

    private func enterText(_ text: String, into field: XCUIElement, in app: XCUIApplication) {
        field.tap()
        field.typeText(text)
        dismissKeyboard(in: app)
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        } else if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
        } else {
            app.tap()
        }
    }
}
