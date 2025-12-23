import XCTest
@testable import ShiftPro

final class UserProfileTests: XCTestCase {
    func testBaseRateConversion() {
        let profile = UserProfile(baseRateCents: 3250)
        XCTAssertEqual(profile.baseRateDollars, 32.5)

        profile.setBaseRate(dollars: 40.0)
        XCTAssertEqual(profile.baseRateCents, 4000)

        profile.setBaseRate(dollars: nil)
        XCTAssertNil(profile.baseRateCents)
    }

    func testDisplayNameFallbacks() {
        let badgeProfile = UserProfile(badgeNumber: "5678")
        XCTAssertEqual(badgeProfile.displayName, "Badge #5678")

        let deptProfile = UserProfile(department: "Metro Police")
        XCTAssertEqual(deptProfile.displayName, "Metro Police")

        let defaultProfile = UserProfile()
        XCTAssertEqual(defaultProfile.displayName, "User")
    }
}
