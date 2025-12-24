# ShiftPro UI Tests

This directory contains XCUITest-based UI tests for the ShiftPro iOS app.

## Setup Instructions

### 1. Create UI Testing Target in Xcode

1. Open `ShiftPro.xcodeproj` in Xcode 15+
2. Select the project in the navigator
3. Click `+` at the bottom of the targets list
4. Choose `iOS > Test > UI Testing Bundle`
5. Name it `ShiftProUITests`
6. Ensure the target to be tested is `ShiftPro`
7. Click Finish

### 2. Add Test Files to Target

1. Select all `.swift` files in this directory
2. In the File Inspector, check the `ShiftProUITests` target membership
3. Ensure `TestUtilities.swift` is included in all test targets

### 3. Configure Launch Arguments

The tests use launch arguments for UI testing mode. Add these to your scheme:

1. Edit Scheme > Test > Arguments
2. Add `-ui-testing` to Launch Arguments
3. Add `-reduce-motion` for deterministic animations

### 4. Run Tests

```bash
# From command line
xcodebuild test \
  -scheme ShiftPro \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  -only-testing:ShiftProUITests

# Or use Cmd+U in Xcode
```

## Test Files

| File | Description |
|------|-------------|
| `TestUtilities.swift` | Shared test utilities and launch configuration |
| `OnboardingTests.swift` | Onboarding flow tests |
| `ShiftManagementTests.swift` | Dashboard and schedule tests |
| `HoursTests.swift` | Hours dashboard tests |
| `PatternTests.swift` | Shift pattern tests |
| `CalendarTests.swift` | Calendar settings tests |
| `AccessibilityTests.swift` | Accessibility identifier validation |
| `PerformanceTests.swift` | Launch and UI performance metrics |

## Accessibility Identifiers

Tests rely on stable accessibility identifiers defined in:
`ShiftPro/Utils/AccessibilityIdentifiers.swift`

Key identifiers used by tests:
- `onboarding.primary` - Primary onboarding button
- `onboarding.back` - Back button in onboarding
- `schedule.addShift` - Add shift button
- `dashboard.heroCard` - Dashboard hero card
- `hours.heroCard` - Hours dashboard hero card

## CI Integration

See `.github/workflows/ci.yml` for GitHub Actions configuration.

The CI runs:
1. Unit tests (`ShiftProTests`)
2. UI tests (`ShiftProUITests`)
3. SwiftLint
4. Static analysis

## Writing New Tests

1. Create a new `XCTestCase` subclass
2. Use `UITestHelper.makeApp()` to create the app instance
3. Use `UITestHelper.openTab(_:in:)` for navigation
4. Use accessibility identifiers for element lookup
5. Keep tests independent and idempotent

Example:
```swift
import XCTest

final class MyNewTests: XCTestCase {
    func testFeature() {
        let app = UITestHelper.makeApp()
        app.launch()

        UITestHelper.openTab("Schedule", in: app)

        let button = app.buttons["schedule.addShift"]
        XCTAssertTrue(button.waitForExistence(timeout: 2))
    }
}
```
