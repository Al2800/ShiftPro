import AppIntents

/// Main App Intents configuration for ShiftPro.
/// Registers all available Siri Shortcuts and voice commands.

// MARK: - App Shortcuts Bundle

/// Combined shortcuts provider for all ShiftPro intents.
struct ShiftProShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Shift Control shortcuts
        ShiftControlShortcuts.appShortcuts +
        // Status Query shortcuts
        StatusQueryShortcuts.appShortcuts
    }
}

// MARK: - Intent Entities

/// Entity representing a shift for Siri disambiguation.
struct ShiftEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shift")
    static var defaultQuery = ShiftEntityQuery()
    
    var id: UUID
    var title: String
    var dateFormatted: String
    var timeFormatted: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(dateFormatted), \(timeFormatted)"
        )
    }
}

/// Query for finding shifts.
struct ShiftEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ShiftEntity] {
        // Fetch shifts by ID
        []
    }
    
    func suggestedEntities() async throws -> [ShiftEntity] {
        // Return upcoming shifts for suggestions
        []
    }
}

// MARK: - Custom Parameter Types

/// Duration parameter for break logging.
struct BreakDuration: AppEnum {
    case fifteen
    case thirty
    case fortyFive
    case sixty
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Break Duration")
    static var caseDisplayRepresentations: [BreakDuration: DisplayRepresentation] = [
        .fifteen: "15 minutes",
        .thirty: "30 minutes",
        .fortyFive: "45 minutes",
        .sixty: "1 hour"
    ]
    
    var minutes: Int {
        switch self {
        case .fifteen: return 15
        case .thirty: return 30
        case .fortyFive: return 45
        case .sixty: return 60
        }
    }
}

/// Rate multiplier options.
struct RateMultiplierOption: AppEnum {
    case regular
    case enhanced
    case timeAndHalf
    case double
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Rate")
    static var caseDisplayRepresentations: [RateMultiplierOption: DisplayRepresentation] = [
        .regular: "Regular (1x)",
        .enhanced: "Enhanced (1.3x)",
        .timeAndHalf: "Time and a Half (1.5x)",
        .double: "Double Time (2x)"
    ]
    
    var value: Double {
        switch self {
        case .regular: return 1.0
        case .enhanced: return 1.3
        case .timeAndHalf: return 1.5
        case .double: return 2.0
        }
    }
}

// MARK: - Intent Response Types

/// Structured response for shift queries.
struct ShiftQueryResponse: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shift Info")
    static var defaultQuery = ShiftQueryResponseQuery()
    
    var id: String
    var title: String
    var isOnShift: Bool
    var hoursWorked: Double
    var nextShiftInfo: String?
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct ShiftQueryResponseQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ShiftQueryResponse] {
        []
    }
}

// MARK: - Siri Tips

/// Provides contextual Siri tips in the app.
enum ShiftProSiriTips {
    static let clockInTip = "Try saying 'Hey Siri, start my shift in ShiftPro'"
    static let clockOutTip = "Try saying 'Hey Siri, end my shift'"
    static let hoursTip = "Try saying 'Hey Siri, how many hours this week'"
    static let nextShiftTip = "Try saying 'Hey Siri, when is my next shift'"
}
