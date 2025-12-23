import XCTest

final class ShiftProPerformanceTests: XCTestCase {
    func testLaunchPerformance() {
        let app = XCUIApplication()
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launchArguments.append("-ui-testing")
            app.launch()
            app.terminate()
        }
    }
}
