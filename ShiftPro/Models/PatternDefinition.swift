import Foundation

struct PatternDefinition: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case weekly
        case rotating
    }

    struct RotationDayDefinition: Identifiable, Codable, Hashable {
        let id: UUID
        let index: Int
        let isWorkDay: Bool
        let shiftName: String?
        let startMinuteOfDay: Int?
        let durationMinutes: Int?

        init(
            id: UUID = UUID(),
            index: Int,
            isWorkDay: Bool,
            shiftName: String? = nil,
            startMinuteOfDay: Int? = nil,
            durationMinutes: Int? = nil
        ) {
            self.id = id
            self.index = index
            self.isWorkDay = isWorkDay
            self.shiftName = shiftName
            self.startMinuteOfDay = startMinuteOfDay
            self.durationMinutes = durationMinutes
        }
    }

    let id: UUID
    var name: String
    var kind: Kind
    var startMinuteOfDay: Int
    var durationMinutes: Int
    var weekdays: [Weekday]
    var rotationDays: [RotationDayDefinition]
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        kind: Kind,
        startMinuteOfDay: Int,
        durationMinutes: Int,
        weekdays: [Weekday] = [],
        rotationDays: [RotationDayDefinition] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.startMinuteOfDay = startMinuteOfDay
        self.durationMinutes = durationMinutes
        self.weekdays = weekdays
        self.rotationDays = rotationDays
        self.notes = notes
    }
}

struct ShiftPreview: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let title: String
    let start: Date
    let end: Date
    let isWorkDay: Bool

    init(date: Date, title: String, start: Date, end: Date, isWorkDay: Bool) {
        self.id = UUID()
        self.date = date
        self.title = title
        self.start = start
        self.end = end
        self.isWorkDay = isWorkDay
    }
}
