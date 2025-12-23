# ShiftPro iOS App - Architecture Refinements & Detailed Specifications

This document serves as an addendum to the `ARCHITECTURE_PLAN.md`, providing deeper technical specifications, resolving conflicts, and expanding on critical implementation details.

## 1. Technical Stack Evolution
**Minimum Target:** iOS 17.0+
**Primary Reasoning:** Adoption of SwiftData and advanced SwiftUI features requires the latest stable SDKs.

### Key Frameworks
- **SwiftData:** Replaces manual Core Data boilerplate for persistence.
- **StoreKit 2:** For modern in-app purchase and subscription management.
- **LocalAuthentication:** For biometric (FaceID/TouchID) security layers.
- **TipKit:** To assist with the "Smart Onboarding" experience.

---

## 2. Advanced Data Modeling: The Rotating Roster
To support complex shift patterns common in emergency services (e.g., 4-on/2-off, Pitman, etc.), the data model is refined as follows:

```swift
@Model
class ShiftPattern {
    var id: UUID
    var name: String
    var colorHex: String
    
    // Pattern Logic
    var scheduleType: String // "weekly" or "cycling"
    var fixedDaysOfWeek: [Int]? // [1, 2, 3] for Sun, Mon, Tue
    
    // Rotation details
    var cycleStartDate: Date? 
    var rotationCycle: [RotationDay] = [] 
    
    var createdAt: Date
    
    init(name: String, type: ScheduleType) {
        self.id = UUID()
        self.name = name
        self.scheduleType = type.rawValue
        self.createdAt = Date()
    }
}

struct RotationDay: Codable {
    var isWorkDay: Bool
    var shiftName: String? // e.g., "Day", "Night", "Swing"
    var startTimeOffset: TimeInterval? // Offset from midnight in seconds
    var duration: TimeInterval?
}

enum ScheduleType: String {
    case weekly
    case cycling
}
```

---

## 3. User Experience & Onboarding Flow
The app will implement a **"Smart Setup Wizard"** to reduce the friction of initial configuration.

### Onboarding Steps:
1.  **Permission Pre-flight:** Clear explanation of why Calendar and Notification permissions are requested.
2.  **Pattern Discovery:** A step-by-step UI asking users for their "Days On" and "Days Off".
3.  **Visual Confirmation:** A 1-month preview calendar where users confirm the projected shifts before they are persisted to SwiftData.

---

## 4. Privacy & Security Compliance
### Privacy Manifest (`PrivacyInfo.xcprivacy`)
Required declarations for iOS 17+ App Store submission:
- **NSPrivacyAccessedAPICategoryUserDefaults:** Used for persisting app settings and onboarding status.
- **NSPrivacyAccessedAPICategoryFileTimestamp:** Used by SwiftData for internal database management.
- **Calendar Usage:** `NSCalendarsFullAccessUsageDescription` must clearly state: *"We use your calendar to sync your work shifts and prevent personal scheduling conflicts."*

### Secure Storage
- **Keychain:** Sensitive user profile data (e.g., specific badge numbers or department IDs) will be stored in the Keychain using the `KeychainAccess` library, rather than standard `UserDefaults`.

---

## 5. Quality Assurance & Testing
### Snapshot Testing
- **Library:** `swift-snapshot-testing` (Point-Free).
- **Target:** All reusable UI components (Cards, Badges, Dashboards).
- **Goal:** Ensure layout integrity across iPhone SE (4"), iPhone 15 Pro Max (6.7"), and iPad sizes.

### Performance Benchmarks
- **Cold Launch:** Must reach the Dashboard in < 1.5s.
- **Sync Latency:** Background calendar sync should complete in < 5s without blocking the UI thread.

---

## 6. Monetization Architecture
### Entitlement-Based Access
- **Tier 1 (Free):** Local shift logging, 30-day history, 1 active shift pattern.
- **Tier 2 (Pro):** Unlimited history, Two-way Calendar Sync, CSV/PDF Export, Custom Theme Icons.
- **Implementation:** An `EntitlementManager` observable object will wrap StoreKit 2 status and be injected into the environment.
