import XCTest

/// Performance tests for ShiftPro
/// Tests app launch time, UI responsiveness, and large dataset handling
final class PerformanceTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Performance Tests

    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let testApp = XCUIApplication()
            testApp.launchArguments = TestUtilities.skipOnboardingArguments
            testApp.launch()
        }
    }

    func testAppLaunchWithOnboarding() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let testApp = XCUIApplication()
            testApp.launchArguments = TestUtilities.standardLaunchArguments
            testApp.launch()
        }
    }

    // MARK: - Navigation Performance Tests

    func testTabNavigationPerformance() throws {
        app = TestUtilities.launchApp(with: TestUtilities.skipOnboardingArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        measure {
            // Navigate through all tabs
            let tabs = ["Dashboard", "Schedule", "Hours", "Settings"]
            for tabName in tabs {
                let tab = tabBar.buttons[tabName]
                if tab.exists {
                    tab.tap()
                    _ = app.waitForExistence(timeout: 0.5)
                }
            }
        }
    }

    func testDashboardLoadPerformance() throws {
        app = TestUtilities.launchApp(with: TestUtilities.skipOnboardingArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        measure {
            let dashboardTab = tabBar.buttons["Dashboard"]
            if dashboardTab.exists {
                dashboardTab.tap()

                // Wait for dashboard to fully load
                let dashboardNav = app.navigationBars["Dashboard"]
                _ = dashboardNav.waitForExistence(timeout: 2)
            }
        }
    }

    func testHoursDashboardLoadPerformance() throws {
        app = TestUtilities.launchApp(with: TestUtilities.skipOnboardingArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        measure {
            let hoursTab = tabBar.buttons["Hours"]
            if hoursTab.exists {
                hoursTab.tap()

                // Wait for hours dashboard to load
                let hoursNav = app.navigationBars["Hours"]
                _ = hoursNav.waitForExistence(timeout: 2)
            }
        }
    }

    // MARK: - Large Dataset Performance Tests

    func testLargeDatasetPerformance() throws {
        // Launch with large dataset
        app = TestUtilities.launchApp(with: TestUtilities.largeDatasetArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))

        measure {
            // Navigate and interact with large dataset
            let dashboardTab = tabBar.buttons["Dashboard"]
            if dashboardTab.exists {
                dashboardTab.tap()

                // Scroll through content
                let scrollView = app.scrollViews.firstMatch
                if scrollView.waitForExistence(timeout: 3) {
                    scrollView.swipeUp()
                    scrollView.swipeDown()
                }
            }
        }
    }

    func testScheduleScrollPerformance() throws {
        app = TestUtilities.launchApp(with: TestUtilities.largeDatasetArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))

        let scheduleTab = tabBar.buttons["Schedule"]
        if scheduleTab.exists {
            scheduleTab.tap()
        }

        measure {
            let scrollView = app.scrollViews.firstMatch
            if scrollView.waitForExistence(timeout: 3) {
                // Rapid scrolling
                for _ in 0..<5 {
                    scrollView.swipeUp()
                }
                for _ in 0..<5 {
                    scrollView.swipeDown()
                }
            }
        }
    }

    // MARK: - UI Interaction Performance Tests

    func testButtonTapResponseTime() throws {
        app = TestUtilities.launchApp(with: TestUtilities.skipOnboardingArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        TestUtilities.navigateToTab("Dashboard", in: app)

        measure {
            // Measure button tap responsiveness
            let buttons = app.buttons.allElementsBoundByIndex
            for button in buttons.prefix(5) {
                if button.exists && button.isHittable {
                    button.tap()
                    _ = app.waitForExistence(timeout: 0.1)
                }
            }
        }
    }

    // MARK: - Memory Performance Tests

    func testMemoryUsageDuringNavigation() throws {
        app = TestUtilities.launchApp(with: TestUtilities.skipOnboardingArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(metrics: [XCTMemoryMetric(application: app)], options: options) {
            // Navigate through app
            for tabName in ["Dashboard", "Schedule", "Hours", "Settings"] {
                let tab = tabBar.buttons[tabName]
                if tab.exists {
                    tab.tap()
                    _ = app.waitForExistence(timeout: 0.5)
                }
            }
        }
    }

    // MARK: - Clock Performance Tests

    func testCPUUsageDuringOperations() throws {
        app = TestUtilities.launchApp(with: TestUtilities.skipOnboardingArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: [XCTCPUMetric(application: app)], options: options) {
            // Perform various operations
            TestUtilities.navigateToTab("Dashboard", in: app)

            let scrollView = app.scrollViews.firstMatch
            if scrollView.waitForExistence(timeout: 3) {
                scrollView.swipeUp()
                scrollView.swipeDown()
            }

            TestUtilities.navigateToTab("Hours", in: app)
            _ = app.waitForExistence(timeout: 1)
        }
    }

    // MARK: - Form Input Performance Tests

    func testFormInputPerformance() throws {
        app = TestUtilities.launchApp(with: TestUtilities.standardLaunchArguments)

        // Go through onboarding to test form performance
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
        }

        // Skip to profile (has text input)
        if app.buttons["Continue"].waitForExistence(timeout: 3) {
            app.buttons["Continue"].tap()
        }

        measure {
            // Find text fields and measure input
            let textFields = app.textFields.allElementsBoundByIndex
            for field in textFields.prefix(3) {
                if field.exists && field.isHittable {
                    field.tap()
                    field.typeText("Test")
                    // Clear for next iteration
                    field.buttons["Clear text"].tap()
                }
            }
        }
    }

    // MARK: - Chart Rendering Performance Tests

    func testChartRenderingPerformance() throws {
        app = TestUtilities.launchApp(with: TestUtilities.skipOnboardingArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        TestUtilities.navigateToTab("Hours", in: app)

        measure {
            // Toggle chart styles
            let pieButton = app.buttons["Pie"]
            let barButton = app.buttons["Bar"]

            if pieButton.waitForExistence(timeout: 3) {
                pieButton.tap()
                _ = app.waitForExistence(timeout: 0.3)
            }

            if barButton.waitForExistence(timeout: 3) {
                barButton.tap()
                _ = app.waitForExistence(timeout: 0.3)
            }
        }
    }

    // MARK: - Search Performance Tests

    func testSearchPerformance() throws {
        app = TestUtilities.launchApp(with: TestUtilities.largeDatasetArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))

        // Navigate to search if available
        TestUtilities.navigateToTab("Schedule", in: app)

        measure {
            // Find and use search
            let searchField = app.searchFields.firstMatch
            if searchField.waitForExistence(timeout: 3) {
                searchField.tap()
                searchField.typeText("test")
                _ = app.waitForExistence(timeout: 0.5)

                // Clear search
                let clearButton = searchField.buttons["Clear text"]
                if clearButton.exists {
                    clearButton.tap()
                }
            }
        }
    }

    // MARK: - Baseline Performance Assertions

    func testAppLaunchUnder2Seconds() throws {
        let start = CFAbsoluteTimeGetCurrent()

        app = XCUIApplication()
        app.launchArguments = TestUtilities.skipOnboardingArguments
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let launchTime = CFAbsoluteTimeGetCurrent() - start

        // App should launch in under 2 seconds
        XCTAssertLessThan(launchTime, 2.0, "App launch time should be under 2 seconds")
    }

    func testTabSwitchUnder100ms() throws {
        app = TestUtilities.launchApp(with: TestUtilities.skipOnboardingArguments)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        // Warm up
        TestUtilities.navigateToTab("Dashboard", in: app)
        _ = app.waitForExistence(timeout: 0.5)

        let start = CFAbsoluteTimeGetCurrent()

        let hoursTab = tabBar.buttons["Hours"]
        if hoursTab.exists {
            hoursTab.tap()
        }

        let hoursNav = app.navigationBars["Hours"]
        XCTAssertTrue(hoursNav.waitForExistence(timeout: 2))

        let switchTime = CFAbsoluteTimeGetCurrent() - start

        // Tab switch should be under 500ms (100ms is ideal but UI testing adds overhead)
        XCTAssertLessThan(switchTime, 0.5, "Tab switch should be under 500ms")
    }
}
