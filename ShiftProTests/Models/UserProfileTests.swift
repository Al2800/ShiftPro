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
        let jobTitleProfile = UserProfile(jobTitle: "Nurse")
        XCTAssertEqual(jobTitleProfile.displayName, "Nurse")

        let workplaceProfile = UserProfile(workplace: "City Hospital")
        XCTAssertEqual(workplaceProfile.displayName, "City Hospital")

        let employeeIdProfile = UserProfile(employeeId: "E5678")
        XCTAssertEqual(employeeIdProfile.displayName, "ID: E5678")

        let defaultProfile = UserProfile()
        XCTAssertEqual(defaultProfile.displayName, "User")
    }
}
