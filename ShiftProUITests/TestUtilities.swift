import XCTest

enum UITestLaunchArgument {
    static let uiTesting = "-ui-testing"
    static let reduceMotion = "-reduce-motion"
}

enum UITestHelper {
    static func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            UITestLaunchArgument.uiTesting,
            UITestLaunchArgument.reduceMotion
        ]
        return app
    }

    static func openTab(_ label: String, in app: XCUIApplication) {
        let tabBar = app.tabBars.firstMatch
        let button = tabBar.buttons[label]
        if button.waitForExistence(timeout: 2) {
            button.tap()
        }
    }
}
