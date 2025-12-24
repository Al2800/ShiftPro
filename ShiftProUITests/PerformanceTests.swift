import XCTest

final class PerformanceTests: XCTestCase {
    func testLaunchPerformance() {
        if #available(iOS 17.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let app = UITestHelper.makeApp()
                app.launch()
            }
        }
    }
}
