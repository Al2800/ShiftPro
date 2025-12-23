# ShiftPro iOS App - Comprehensive Architecture Plan

## 1. High-Level Architecture Overview

### Architecture Pattern: MVVM + Clean Architecture
```
┌─────────────────────────────────────────────────┐
│                 Presentation Layer              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐│
│  │   SwiftUI   │ │  UIKit      │ │ Observation ││
│  │   Views     │ │  Components │ │  /Combine   ││
│  └─────────────┘ └─────────────┘ └─────────────┘│
└─────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────┐
│                Business Logic Layer             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐│
│  │  ViewModels │ │ Use Cases/  │ │  Domain     ││
│  │             │ │ Interactors │ │  Models     ││
│  └─────────────┘ └─────────────┘ └─────────────┘│
└─────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────┐
│                  Data Layer                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐│
│  │ Repositories│ │   Data      │ │   Network   ││
│  │             │ │  Sources    │ │   Services  ││
│  └─────────────┘ └─────────────┘ └─────────────┘│
└─────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────┐
│                Infrastructure Layer             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐│
│  │  SwiftData  │ │   SQLite/   │ │   Calendar  ││
│  │             │ │   CloudKit  │ │ Integration ││
│  └─────────────┘ └─────────────┘ └─────────────┘│
└─────────────────────────────────────────────────┘
```

### Key Architectural Principles
- **Single-User Focus**: Designed for personal, on-device planning with optional iCloud sync
- **Separation of Concerns**: Clear layer boundaries with defined responsibilities
- **Dependency Inversion**: Higher-level modules don't depend on lower-level modules
- **Single Responsibility**: Each class/module has one reason to change
- **Reactive Programming**: Using Observation/Combine for data flow and state management
- **Offline-First**: Local-first architecture with best-effort background sync

## 2. Detailed Technical Stack Recommendations

### Core iOS Technologies
```swift
// Primary Frameworks
- SwiftUI (iOS 17+) for modern UI development
- UIKit for complex custom components
- Observation (iOS 17+) for state management
- Combine for advanced reactive pipelines where needed
- SwiftData + CloudKit (ModelContainer) for persistence and optional iCloud sync
- EventKit for calendar integration
- StoreKit 2 for in-app purchases and subscriptions
- UserNotifications for shift reminders
- Background Tasks for data processing
- LocalAuthentication for biometric app access
- TipKit for onboarding guidance

// Supporting Libraries
- Swift Package Manager for dependency management
- KeychainAccess for secure storage
- Lottie for animations
- Charts (iOS 17+) for hours and rate-multiplier visualizations
- CryptoKit for encrypted exports (optional)
```

### Development Tools & Infrastructure
```
- Xcode 15+
- iOS Deployment Target: 17.0
- Swift 5.9+
- TestFlight for beta distribution
- App Store Connect for production
- Firebase Analytics (optional)
- Crash reporting (Crashlytics or native)
```

## 3. Database Design and Data Models

### SwiftData Model Schema (SwiftData @Model)

```swift
@Model
class UserProfile {
    @Attribute(.unique) var id: UUID
    var badgeNumber: String?
    var department: String?
    var rank: String?
    var startDate: Date
    var baseRateCents: Int64?
    var regularHoursPerPay: Int
    var payPeriodTypeRaw: Int16
    var timeZoneIdentifier: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify) var patterns: [ShiftPattern] = []
    @Relationship(deleteRule: .nullify) var shifts: [Shift] = []
    @Relationship(deleteRule: .nullify) var payRulesets: [PayRuleset] = []
    @Relationship(deleteRule: .nullify) var activePayRuleset: PayRuleset?
}

@Model
class ShiftPattern {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String?
    var scheduleTypeRaw: Int16
    var startMinuteOfDay: Int
    var durationMinutes: Int
    var daysOfWeekMask: Int16
    var cycleStartDate: Date?
    var isActive: Bool
    var colorHex: String
    var isSystem: Bool
    var createdAt: Date
    var deletedAt: Date?

    @Relationship(deleteRule: .nullify) var owner: UserProfile?
    @Relationship(deleteRule: .nullify) var shifts: [Shift] = []
    @Relationship(deleteRule: .cascade) var rotationDays: [RotationDay] = []
}

@Model
class RotationDay {
    @Attribute(.unique) var id: UUID
    var index: Int
    var isWorkDay: Bool
    var shiftName: String?
    var startMinuteOfDay: Int?
    var durationMinutes: Int?

    @Relationship(deleteRule: .nullify) var pattern: ShiftPattern?
}

@Model
class Shift {
    @Attribute(.unique) var id: UUID
    var scheduledStart: Date
    var scheduledEnd: Date
    var actualStart: Date?
    var actualEnd: Date?
    var breakMinutes: Int
    var isAdditionalShift: Bool
    var notes: String?
    var statusRaw: Int16
    var paidMinutes: Int
    var premiumMinutes: Int
    var rateMultiplier: Double
    var rateLabel: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(deleteRule: .nullify) var pattern: ShiftPattern?
    @Relationship(deleteRule: .nullify) var owner: UserProfile?
    @Relationship(deleteRule: .nullify) var payPeriod: PayPeriod?
    @Relationship(deleteRule: .cascade) var calendarEvent: CalendarEvent?
}

@Model
class PayPeriod {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date
    var paidMinutes: Int
    var premiumMinutes: Int
    var additionalShiftMinutes: Int
    var estimatedPayCents: Int64?
    var isComplete: Bool
    var deletedAt: Date?

    @Relationship(deleteRule: .nullify) var shifts: [Shift] = []
}

@Model
class PayRuleset {
    @Attribute(.unique) var id: UUID
    var name: String
    var schemaVersion: Int16
    var rulesJSON: String // e.g., unpaidBreakMinutes, rateMultipliers (1.0, 1.3, 1.5, 2.0), pay-period settings
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify) var owner: UserProfile?
}

@Model
class CalendarEvent {
    @Attribute(.unique) var id: UUID
    var eventIdentifier: String
    var calendarIdentifier: String
    var lastEventModified: Date?
    var lastSyncDate: Date
    var syncStateRaw: Int16

    @Relationship(deleteRule: .nullify) var shift: Shift?
}
```

### Enumerations
```swift
enum PayPeriodType: Int16, CaseIterable {
    case weekly = 0
    case biweekly = 1
    case monthly = 2
}

enum ScheduleType: Int16, CaseIterable {
    case weekly = 0
    case cycling = 1
}

enum ShiftStatus: Int16, CaseIterable {
    case scheduled = 0
    case inProgress = 1
    case completed = 2
    case cancelled = 3
}

enum Weekday: Int, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

enum CalendarSyncState: Int16, CaseIterable {
    case localOnly = 0
    case synced = 1
    case needsUpdate = 2
    case failed = 3
}
```

Presentation-layer view models should expose computed properties (e.g., `status`, `timeRange`, `premiumHours`)
to keep storage fields like `statusRaw` and minute counts isolated to the data layer.
Weekly patterns use `daysOfWeekMask` plus `startMinuteOfDay` and `durationMinutes`; cycling patterns
use `cycleStartDate` and `rotationDays` to generate scheduled shifts.
Pay rules are represented as a versioned JSON ruleset to support county/team variations without
frequent schema changes; simple defaults can still use `regularHoursPerPay` and optional `baseRateCents`.

### Default Hours Policy (Initial)
- **Unpaid Break**: First 30 minutes of any shift are unpaid by default
- **Pay Period Basis**: Hours are tracked by pay period without automatic overtime classification
- **Rate Multipliers**: Default set is 1.0 (regular), 1.3 (overtime bracket), 1.5 (extra), 2.0 (bank holiday)
- **Estimated Pay**: Optional if `baseRateCents` is provided

Example `rulesJSON` (illustrative):
```json
{
  "schemaVersion": 1,
  "unpaidBreakMinutes": 30,
  "rateMultipliers": [
    { "label": "Regular", "multiplier": 1.0 },
    { "label": "Overtime (Bracket)", "multiplier": 1.3 },
    { "label": "Extra", "multiplier": 1.5 },
    { "label": "Bank Holiday", "multiplier": 2.0 }
  ],
  "payPeriodType": "biweekly"
}
```

## 4. User Interface/UX Architecture

### Navigation Structure
```
TabView (Primary Navigation)
├── Dashboard
│   ├── Current Shift Status
│   ├── Upcoming Shifts (Next 7 days)
│   ├── Quick Actions (Start/End Shift)
│   └── Hours Summary (Current Pay Period)
├── Schedule
│   ├── Calendar View (Month/Week)
│   ├── Shift List View
│   └── Add Shift (Floating Action)
├── Hours
│   ├── Pay Period Overview
│   ├── Rate Multipliers
│   ├── Historical Data
│   └── Export Options
└── Settings
    ├── Profile Management
    ├── Shift Patterns
    ├── Calendar Integration
    ├── Notifications
    ├── Data Privacy Controls
    └── Data Export/Import
```

### Key UI Components Design

#### SwiftUI Components
```swift
// Reusable shift card component
struct ShiftCardView: View {
    let shift: Shift
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ShiftStatusIndicator(status: shift.status)
                VStack(alignment: .leading) {
                    Text(shift.pattern?.name ?? "Custom Shift")
                        .font(.headline)
                    Text(shift.timeRange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if shift.premiumHours > 0 {
                    RateBadge(multiplier: shift.rateMultiplier, hours: shift.premiumHours)
                }
            }

            if isExpanded {
                ShiftDetailsView(shift: shift)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
}

// Quick action floating button
struct QuickActionButton: View {
    @EnvironmentObject var shiftManager: ShiftManager

    var body: some View {
        Button(action: shiftManager.toggleCurrentShift) {
            Image(systemName: shiftManager.isOnShift ? "stop.fill" : "play.fill")
                .font(.title2)
                .foregroundColor(.white)
        }
        .frame(width: 60, height: 60)
        .background(shiftManager.isOnShift ? Color.red : Color.blue)
        .clipShape(Circle())
        .shadow(radius: 4)
    }
}
```

### Rate Multiplier UX
- **Shift Editor**: Picker for multiplier (1.0, 1.3, 1.5, 2.0) with editable labels
- **Hours Summary**: Totals grouped by multiplier and label for quick review

### UX Flow Optimization
1. **One-Tap Actions**: Start/end shift, add common shifts
2. **Contextual Information**: Show relevant data based on current time
3. **Progressive Disclosure**: Detailed information available on demand
4. **Haptic Feedback**: Confirm important actions
5. **Dark Mode Support**: Essential for night shift workers
6. **Onboarding**: Permissions (Calendar, Notifications) and pay period setup

### Smart Setup Wizard (Onboarding)
1. **Permission Pre-flight**: Explain Calendar and Notifications before requesting access
2. **Pattern Discovery**: Ask days-on/days-off or weekly pattern details
3. **Visual Confirmation**: Show a 1-month preview calendar before saving
4. **TipKit Hints**: Contextual tips for first-time actions

### Data Export & Import Strategy
- **CSV**: Shift lists and pay-period summaries (UTF-8)
- **ICS**: Calendar exports for compatibility
- **JSON Backup**: Full app backup (`.shiftpro` package) for restore
- **PDF**: Readable summaries for sharing
- **Encryption**: Optional password-protected AES-GCM for exported files

## 5. Calendar Integration Strategy

### EventKit Integration Architecture
```swift
class CalendarIntegrationService {
    private let eventStore = EKEventStore()

    // Request calendar access with proper permissions
    func requestCalendarAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return await eventStore.requestAccess(to: .event)
        case .authorized:
            return true
        default:
            return false
        }
    }

    // Sync shifts to calendar
    func syncShiftToCalendar(_ shift: Shift) async throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = "Shift: \(shift.pattern?.name ?? "Work")"
        event.startDate = shift.scheduledStart
        event.endDate = shift.scheduledEnd
        event.calendar = getOrCreateShiftCalendar()
        event.notes = generateShiftNotes(shift)
        event.url = URL(string: "shiftpro://shift/\(shift.id.uuidString)")

        try eventStore.save(event, span: .thisEvent)

        // Save mapping for future updates
        await saveCalendarMapping(shiftId: shift.id, eventId: event.eventIdentifier)
    }
}
```

### Calendar Features
- **Dedicated Shift Calendar**: Create separate calendar for shifts
- **Sync Direction Control**: Default export-only, optional two-way sync
- **Stable Event Identification**: Store EventKit identifier and set `event.url` to `shiftpro://shift/<id>` for dedupe
- **Conflict Detection**: Warn about scheduling conflicts
- **Multiple Calendar Support**: Work with existing calendar apps
- **Intelligent Defaults**: Auto-populate common shift information

## 6. Sync & Conflict Resolution

### CloudKit Strategy (Single-User, Multi-Device)
- **Merge Policy**: Last-writer-wins based on `updatedAt`, favoring the newest change on conflicts
- **Soft Deletes**: Use `deletedAt` to prevent CloudKit from resurrecting deleted records
- **Sync State Tracking**: Use simple flags (e.g., pending, synced, failed) for retries and diagnostics
- **Account Changes**: On iCloud sign-out, keep local data but pause sync and prompt user

### Calendar Conflict Resolution
- **Default Mode**: Export-only to avoid surprises
- **Two-Way Mode**: Compare `EKEvent.lastModifiedDate` to `Shift.updatedAt`
- **Resolution Rule**: If Calendar is newer, update the shift; if the app is newer, update the event
- **User Override**: If timestamps are very close or ambiguous, prompt for a choice

## 7. Performance Optimization Approaches

### Data Management Optimization
```swift
// Lazy loading for large datasets
class ShiftRepository {
    @Published var shifts: [Shift] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadShifts(for dateRange: DateInterval) throws {
        var descriptor = FetchDescriptor<Shift>(
            predicate: #Predicate { shift in
                shift.scheduledStart >= dateRange.start &&
                shift.scheduledStart <= dateRange.end
            },
            sortBy: [SortDescriptor(\.scheduledStart, order: .forward)]
        )
        descriptor.fetchLimit = 50 // Pagination
        shifts = try modelContext.fetch(descriptor)
    }
}
```

### UI Performance
- **SwiftUI Optimization**: Use `@Observable`, `@StateObject`, `@ObservedObject` properly
- **Image Caching**: Cache shift pattern icons and user avatars
- **List Virtualization**: Efficient scrolling for large shift lists
- **Background Processing**: Heavy calculations on background queues
- **Memory Management**: Proper cleanup of observers and subscriptions

### Battery Optimization
- **Background App Refresh**: Minimal background processing
- **Location Services**: Only when needed for geofenced shifts
- **Network Requests**: Batch sync operations
- **SwiftData**: Efficient fetch requests with proper predicates

## 8. Implementation Phases with Milestones

### Phase 1: Foundation (Weeks 1-4)
**Milestone: MVP Core Functionality**
- Project setup and architecture implementation
- SwiftData model implementation
- Basic shift CRUD operations
- Simple calendar view
- On-device onboarding and user profile

**Deliverables:**
- Xcode project with proper architecture
- SwiftData model container with optional CloudKit sync
- Basic UI wireframes implemented
- Unit tests for core business logic

### Phase 2: Essential Features (Weeks 5-8)
**Milestone: Essential Shift Management**
- Shift pattern creation and management
- Calendar integration (EventKit)
- Hours calculation and rate multipliers
- Basic notification system
- Import/export functionality

**Deliverables:**
- Functional shift scheduling
- Calendar synchronization
- Hours dashboard
- Beta-ready app for internal testing

### Phase 3: UX Polish & Advanced Features (Weeks 9-12)
**Milestone: Production-Ready UX**
- Advanced UI animations and transitions
- Comprehensive notification system
- Widgets for quick access
- Advanced reporting and analytics
- Performance optimization

**Deliverables:**
- App Store-ready build
- Comprehensive test suite
- User documentation
- Performance benchmarks

### Phase 4: Enhancement & Scaling (Weeks 13-16)
**Milestone: Extended Platform Features**
- Apple Watch companion app
- Siri Shortcuts integration
- Advanced analytics and insights
- Optional multiple personal profiles on one device
- Backup and restore functionality

## 9. Security and Data Privacy Considerations

### Data Protection Framework
```swift
// Secure data storage implementation
class SecureDataManager {
    private let keychain = KeychainAccess(service: "com.shiftpro.app")

    // Store sensitive data in Keychain
    func storeSensitiveData<T: Codable>(_ data: T, for key: String) throws {
        let encoded = try JSONEncoder().encode(data)
        try keychain.set(encoded, key: key)
    }

    // SwiftData store file protection
    func makeModelContainer() throws -> ModelContainer {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
        let storeURL = appSupport.appendingPathComponent("ShiftPro.store")

        try FileManager.default.createDirectory(at: appSupport,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete],
                                              ofItemAtPath: appSupport.path)

        let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .automatic)
        return try ModelContainer(for: UserProfile.self,
                                  ShiftPattern.self,
                                  RotationDay.self,
                                  Shift.self,
                                  PayPeriod.self,
                                  PayRuleset.self,
                                  CalendarEvent.self,
                                  configurations: config)
    }
}
```

### Privacy Measures
- **Data Minimization**: Only collect necessary information
- **Local-First**: Primary data storage on device
- **Encryption**: At-rest and in-transit data encryption
- **Keychain Integration**: Secure storage for sensitive data
- **App Transport Security**: Enforce HTTPS for network requests
- **CloudKit Privacy**: User controls data sharing
- **Biometric Authentication**: Touch/Face ID for app access
- **Export Encryption**: Optional password-based AES-GCM for CSV/JSON exports

### Privacy Manifest (iOS 17+)
- **PrivacyInfo.xcprivacy** declarations for required API categories
- **UserDefaults**: Onboarding and settings persistence
- **File Timestamp**: SwiftData internal file access
- **Calendar Access**: Clear usage description for shift sync

### Compliance Considerations
- **GDPR Compliance**: Data portability and deletion rights
- **CCPA Compliance**: California Consumer Privacy Act requirements
- **Audit Trail (Optional)**: Local change history for user review and export

## 10. Testing Strategy

### Test Pyramid Structure
```swift
// Unit Tests - Business Logic
class ShiftCalculationTests: XCTestCase {
    func testPaidMinutesCalculation() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .hour, value: 8, to: start)!
        let shift = Shift(scheduledStart: start, scheduledEnd: end, breakMinutes: 30,
                          rateMultiplier: 1.0) // 8 hours with unpaid 30 min break
        let calculator = HoursCalculator()

        XCTAssertEqual(calculator.paidMinutes(for: shift), 450)
    }

    func testPayPeriodCalculation() {
        // Test pay period hour aggregation
    }
}

// Integration Tests - Data Layer
class SwiftDataIntegrationTests: XCTestCase {
    func testShiftPersistence() {
        // Test SwiftData operations
    }

    func testCloudKitSync() {
        // Test CloudKit synchronization
    }
}

// UI Tests - Critical User Flows
class ShiftManagementUITests: XCTestCase {
    func testCreateShift() {
        // Test complete shift creation flow
    }

    func testStartEndShiftFlow() {
        // Test quick action functionality
    }
}
```

### Testing Approach
- **Unit Tests**: 80% code coverage for business logic
- **Integration Tests**: Data layer and external service integration
- **UI Tests**: Critical user journeys and accessibility
- **Performance Tests**: Memory usage, battery drain, startup time
- **Device Testing**: Multiple iOS versions and device types
- **Accessibility Testing**: VoiceOver and other assistive technologies
- **Time Tests**: DST transitions, time zones, and overnight shifts
- **Sync Tests**: Calendar merge, delete, and conflict scenarios

### Snapshot Testing
- **Library**: `swift-snapshot-testing` for reusable UI components
- **Targets**: iPhone SE, iPhone 15 Pro Max, and iPad sizes

## 11. Deployment and Distribution Plan

### Build and Release Pipeline
```yaml
# CI/CD Pipeline Structure
Continuous Integration:
  - Automated testing on pull requests
  - Static analysis (SwiftLint, SonarQube)
  - Security scanning
  - Performance benchmarking

Continuous Deployment:
  - Automatic TestFlight builds for main branch
  - Staging environment for QA testing
  - Production releases via App Store Connect
  - Rollback capability for critical issues
```

### Distribution Strategy
- **Development**: Xcode simulator and physical devices
- **Internal Testing**: TestFlight with development team
- **Beta Testing**: TestFlight with volunteer early adopters
- **Production**: App Store distribution with phased rollout

### Release Management
- **Version Numbering**: Semantic versioning (Major.Minor.Patch)
- **Release Notes**: Clear communication of new features and fixes
- **Rollback Plan**: Ability to revert to previous version if needed
- **Monitoring**: Crash reporting and performance metrics
- **Support**: In-app feedback and support contact information
- **App Store Privacy Labels**: Declare data collection and usage clearly

## 12. Monetization Architecture

### Entitlement-Based Access
- **Tier 1 (Free)**: Local shift logging, 30-day history, 1 active shift pattern
- **Tier 2 (Pro)**: Unlimited history, two-way calendar sync, CSV/PDF export, custom theme icons
- **Implementation**: `EntitlementManager` wraps StoreKit 2 status and is injected into the environment

## 13. Critical Implementation Considerations

### Performance Targets
- **App Launch Time**: < 1.5 seconds cold start
- **UI Responsiveness**: < 100ms for all interactions
- **Memory Usage**: < 50MB baseline, < 100MB under load
- **Battery Impact**: Minimal background usage
- **Network Efficiency**: Offline-first with smart sync
- **Calendar Sync Latency**: < 5 seconds in background

### Scalability Factors
- **Multiple Profiles**: Optional separate profiles for personal use
- **Platform Extension**: Shared business logic for future Android app
- **API Integration**: RESTful API design for future web dashboard
- **Data Migration**: Version management for SwiftData schema changes
- **Feature Flags**: Remote configuration for gradual feature rollout

### Critical Files for Implementation

The most critical files for implementing this architecture plan:

- `/ShiftPro/Models/SwiftDataModels.swift` - SwiftData model definitions and relationships that form the foundation of all data operations
- `/ShiftPro/Services/ShiftManager.swift` - Central business logic coordinator managing shift operations, calculations, and state management
- `/ShiftPro/Views/DashboardView.swift` - Primary user interface that orchestrates the main user experience and navigation
- `/ShiftPro/Services/CalendarIntegrationService.swift` - EventKit integration service handling two-way calendar synchronization and conflict resolution
- `/ShiftPro/Repositories/ShiftRepository.swift` - Data access layer implementing the repository pattern for efficient SwiftData operations and CloudKit sync
- `/ShiftPro/Services/PayRulesEngine.swift` - Pluggable rules engine for hours and rate multipliers
- `/ShiftPro/Services/EntitlementManager.swift` - StoreKit 2 wrapper controlling feature access

This architecture provides a robust foundation for building a production-ready shift planning app that scales with user needs while maintaining excellent performance and user experience. The phased implementation approach allows for iterative development with regular user feedback and course corrections.
