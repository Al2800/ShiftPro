import XCTest
import SwiftData
@testable import ShiftPro

@MainActor
final class ShiftManagerTests: XCTestCase {
    func testCreateShiftCalculatesPaidMinutes() async throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let manager = await ShiftManager(context: container.mainContext)

        let start = Date()
        let end = Calendar.current.date(byAdding: .hour, value: 8, to: start) ?? start
        let shift = try await manager.createShift(
            scheduledStart: start,
            scheduledEnd: end,
            breakMinutes: 30
        )

        XCTAssertEqual(shift.paidMinutes, 450)
    }
}
