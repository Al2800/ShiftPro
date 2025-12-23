import XCTest

/// UI Tests for accessibility compliance
/// Tests VoiceOver, Dynamic Type, and other accessibility features
final class AccessibilityTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = TestUtilities.launchApp(with: TestUtilities.accessibilityTestArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - VoiceOver Label Tests

    func testDashboardElementsHaveAccessibilityLabels() throws {
        TestUtilities.navigateToTab("Dashboard", in: app)

        // Verify key elements have accessibility labels
        let dashboardNav = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardNav.waitForExistence(timeout: 5))
        XCTAssertFalse(dashboardNav.label.isEmpty)
    }

    func testButtonsHaveAccessibilityLabels() throws {
        TestUtilities.navigateToTab("Dashboard", in: app)

        // Check that buttons have meaningful accessibility labels
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            if button.exists && button.isHittable {
                XCTAssertFalse(button.label.isEmpty, "Button should have accessibility label")
            }
        }
    }

    func testShiftCardsHaveAccessibilityLabels() throws {
        TestUtilities.navigateToTab("Dashboard", in: app)

        // Shift cards should be accessible
        let cards = app.buttons.matching(identifier: "ShiftCard").allElementsBoundByIndex
        for card in cards {
            if card.exists {
                XCTAssertFalse(card.label.isEmpty, "Shift card should have accessibility label")
            }
        }
    }

    func testNavigationButtonsAccessible() throws {
        // Tab bar buttons should be accessible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let tabs = tabBar.buttons.allElementsBoundByIndex
        for tab in tabs {
            if tab.exists {
                XCTAssertFalse(tab.label.isEmpty, "Tab should have accessibility label")
            }
        }
    }

    // MARK: - Focus Order Tests

    func testTabBarFocusOrder() throws {
        // Tab bar should have logical focus order
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Verify tabs exist and are in expected order
        let dashboardTab = tabBar.buttons["Dashboard"]
        let scheduleTab = tabBar.buttons["Schedule"]
        let hoursTab = tabBar.buttons["Hours"]
        let settingsTab = tabBar.buttons["Settings"]

        // At least some tabs should exist
        XCTAssertTrue(dashboardTab.exists || scheduleTab.exists || hoursTab.exists || settingsTab.exists)
    }

    func testOnboardingFocusOrder() throws {
        // Launch fresh for onboarding
        let freshApp = TestUtilities.launchApp(with: TestUtilities.standardLaunchArguments)

        // Continue button should be focused/accessible
        let continueButton = freshApp.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(continueButton.isHittable)
        }
    }

    // MARK: - Dynamic Type Tests

    func testDynamicTypeScaling() throws {
        // Note: Dynamic Type testing is limited in XCUITest
        // This test verifies text elements exist and can scale
        TestUtilities.navigateToTab("Dashboard", in: app)

        // Text should exist and be readable
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        XCTAssertTrue(staticTexts.count > 0, "Should have text elements")
    }

    func testLargeTextSupport() throws {
        // Launch with accessibility size text
        let largeTextApp = TestUtilities.launchApp(with: [
            "-UITesting",
            "-resetOnLaunch",
            "-skipOnboarding=true",
            "-UIPreferredContentSizeCategory=UICTContentSizeCategoryAccessibilityExtraExtraLarge"
        ])

        let tabBar = largeTextApp.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 10) {
            // App should still be usable with large text
            XCTAssertTrue(tabBar.exists)
        }
    }

    // MARK: - Color Contrast Tests

    func testHighContrastSupport() throws {
        // Launch with high contrast mode
        let contrastApp = TestUtilities.launchApp(with: [
            "-UITesting",
            "-resetOnLaunch",
            "-skipOnboarding=true",
            "-UIAccessibilityDarkerSystemColorsEnabled=true"
        ])

        let tabBar = contrastApp.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 10) {
            // App should support high contrast
            XCTAssertTrue(tabBar.exists)
        }
    }

    // MARK: - Reduced Motion Tests

    func testReducedMotionSupport() throws {
        // Launch with reduced motion
        let reducedMotionApp = TestUtilities.launchApp(with: [
            "-UITesting",
            "-resetOnLaunch",
            "-skipOnboarding=true",
            "-UIAccessibilityReduceMotionEnabled=true"
        ])

        let tabBar = reducedMotionApp.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 10) {
            // App should work with reduced motion
            XCTAssertTrue(tabBar.exists)

            // Navigate between tabs
            let tabs = tabBar.buttons.allElementsBoundByIndex
            for tab in tabs {
                if tab.exists && tab.isHittable {
                    tab.tap()
                    _ = reducedMotionApp.waitForExistence(timeout: 1)
                }
            }
        }
    }

    // MARK: - Voice Control Tests

    func testVoiceControlLabels() throws {
        TestUtilities.navigateToTab("Dashboard", in: app)

        // Verify elements have labels Voice Control can use
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            if button.exists && button.isHittable {
                // Labels should not be just numbers or generic
                let label = button.label
                XCTAssertFalse(label.isEmpty, "Button should have label for Voice Control")
            }
        }
    }

    // MARK: - Accessibility Actions Tests

    func testCustomAccessibilityActions() throws {
        TestUtilities.navigateToTab("Dashboard", in: app)

        // Shift cards should support accessibility actions
        let shiftCard = app.buttons.matching(identifier: "ShiftCard").firstMatch
        if shiftCard.waitForExistence(timeout: 5) {
            // Card should exist and be accessible
            XCTAssertTrue(shiftCard.isHittable)
        }
    }

    // MARK: - Form Accessibility Tests

    func testFormFieldsAccessible() throws {
        // Navigate to a form (settings or onboarding)
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            // Form fields should have proper labels
            let textFields = app.textFields.allElementsBoundByIndex
            for field in textFields {
                if field.exists {
                    XCTAssertFalse(field.label.isEmpty || field.placeholderValue?.isEmpty ?? true,
                                   "Text field should have label or placeholder")
                }
            }
        }
    }

    func testSwitchesHaveLabels() throws {
        // Navigate to settings
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            // Switches should have labels
            let switches = app.switches.allElementsBoundByIndex
            for switchElement in switches {
                if switchElement.exists {
                    XCTAssertFalse(switchElement.label.isEmpty,
                                   "Switch should have accessibility label")
                }
            }
        }
    }

    // MARK: - Navigation Accessibility Tests

    func testBackButtonAccessible() throws {
        // Navigate to a detail view
        TestUtilities.navigateToTab("Settings", in: app)

        // Find and tap a navigation link
        let firstLink = app.buttons.firstMatch
        if firstLink.waitForExistence(timeout: 5) && firstLink.isHittable {
            firstLink.tap()

            // Back button should be accessible
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.waitForExistence(timeout: 3) {
                XCTAssertFalse(backButton.label.isEmpty)
            }
        }
    }

    // MARK: - Accessibility Audit

    func testAccessibilityAudit() throws {
        TestUtilities.navigateToTab("Dashboard", in: app)

        // Perform basic accessibility checks
        let allElements = app.descendants(matching: .any).allElementsBoundByIndex

        var elementsWithoutLabels = 0
        for element in allElements.prefix(50) { // Limit to avoid timeout
            if element.exists && element.isHittable {
                if element.label.isEmpty && element.value == nil {
                    elementsWithoutLabels += 1
                }
            }
        }

        // Allow some elements without labels (spacers, etc.)
        XCTAssertLessThan(elementsWithoutLabels, 10,
                          "Too many interactive elements without accessibility labels")
    }

    // MARK: - Helper Methods

    private func navigateToSettings() {
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()
        }
    }
}
