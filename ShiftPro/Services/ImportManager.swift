import Foundation
import SwiftData

/// Handles importing data from various formats
@MainActor
final class ImportManager {
    enum ImportFormat {
        case csv
        case json
        case ics
    }

    enum ImportError: LocalizedError {
        case invalidFormat
        case parsingFailed(String)
        case validationFailed(String)
        case importFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid file format"
            case .parsingFailed(let reason):
                return "Failed to parse data: \(reason)"
            case .validationFailed(let reason):
                return "Data validation failed: \(reason)"
            case .importFailed(let reason):
                return "Import failed: \(reason)"
            }
        }
    }

    private let context: ModelContext
    private let calculator = HoursCalculator()
    private lazy var periodEngine = PayPeriodEngine(context: context, calculator: calculator)

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Import Methods

    func importData(from url: URL, format: ImportFormat, profile: UserProfile?) async throws -> ImportResult {
        let data = try await readFileData(from: url)

        switch format {
        case .csv:
            return try importCSV(data: data, profile: profile)
        case .json:
            return try importJSON(data: data)
        case .ics:
            return try importICS(data: data, profile: profile)
        }
    }

    func previewImpact(from url: URL, format: ImportFormat, profile: UserProfile?) async throws -> ImportImpact {
        let data = try await readFileData(from: url)
        return try previewImpact(data: data, format: format, profile: profile)
    }

    // MARK: - CSV Import

    private func importCSV(data: Data, profile: UserProfile?) throws -> ImportResult {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw ImportError.parsingFailed("Unable to decode CSV")
        }

        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            throw ImportError.validationFailed("No data rows found")
        }

        // Parse header
        let header = lines[0].components(separatedBy: ",")
        guard header.contains("Date") && header.contains("Start Time") else {
            throw ImportError.validationFailed("Required columns missing")
        }

        var importedShifts: [Shift] = []
        var errors: [String] = []

        // Parse data rows
        for (index, line) in lines.dropFirst().enumerated() {
            do {
                if let shift = try parseCSVLine(line, profile: profile) {
                    importedShifts.append(shift)
                    context.insert(shift)
                }
            } catch {
                errors.append("Row \(index + 2): \(error.localizedDescription)")
            }
        }

        try context.save()
        errors.append(contentsOf: assignImportedShifts(importedShifts, profile: profile))

        return ImportResult(
            importedShifts: importedShifts.count,
            importedPatterns: 0,
            errors: errors
        )
    }

    private func previewImpact(data: Data, format: ImportFormat, profile: UserProfile?) throws -> ImportImpact {
        switch format {
        case .csv:
            return try previewCSV(data: data, profile: profile)
        case .json:
            return try previewJSON(data: data)
        case .ics:
            return try previewICS(data: data)
        }
    }

    private func readFileData(from url: URL) async throws -> Data {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            return try handle.readToEnd() ?? Data()
        }.value
    }

    private func previewCSV(data: Data, profile: UserProfile?) throws -> ImportImpact {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw ImportError.parsingFailed("Unable to decode CSV")
        }

        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            throw ImportError.validationFailed("No data rows found")
        }

        let header = lines[0].components(separatedBy: ",")
        guard header.contains("Date") && header.contains("Start Time") else {
            throw ImportError.validationFailed("Required columns missing")
        }

        var validRows = 0
        var invalidRows = 0

        for line in lines.dropFirst() {
            do {
                if let _ = try parseCSVLine(line, profile: profile) {
                    validRows += 1
                } else {
                    invalidRows += 1
                }
            } catch {
                invalidRows += 1
            }
        }

        guard validRows > 0 else {
            throw ImportError.validationFailed("No valid shifts found in this file")
        }

        return ImportImpact(shiftCount: validRows, patternCount: 0, invalidRowCount: invalidRows)
    }

    // MARK: - JSON Import

    private func importJSON(data: Data) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let backup = try decoder.decode(FullBackupData.self, from: data)

            // Import profiles
            var importedProfiles: [UserProfile] = []
            for profileData in backup.profiles {
                let profile = UserProfile(
                    employeeId: profileData.employeeId,
                    workplace: profileData.workplace ?? profileData.name,
                    jobTitle: profileData.jobTitle,
                    baseRateCents: profileData.baseRateCents,
                    regularHoursPerPay: profileData.regularHoursPerPay
                )
                context.insert(profile)
                importedProfiles.append(profile)
            }

            // Import patterns
            for patternData in backup.patterns {
                let pattern = ShiftPattern(
                    name: patternData.title,
                    scheduleType: patternData.scheduleType == "weekly" ? .weekly : .cycling
                )
                context.insert(pattern)
            }

            // Import shifts
            var importedShifts = 0
            var createdShifts: [Shift] = []
            let owner = importedProfiles.first
            for shiftData in backup.shifts {
                let shift = Shift(
                    scheduledStart: shiftData.scheduledStart,
                    scheduledEnd: shiftData.scheduledEnd,
                    actualStart: shiftData.actualStart,
                    actualEnd: shiftData.actualEnd,
                    breakMinutes: shiftData.breakMinutes,
                    isAdditionalShift: shiftData.isAdditionalShift,
                    notes: shiftData.notes,
                    rateMultiplier: shiftData.rateMultiplier,
                    rateLabel: shiftData.rateLabel,
                    owner: owner
                )
                context.insert(shift)
                createdShifts.append(shift)
                importedShifts += 1
            }

            try context.save()
            let assignmentErrors = assignImportedShifts(createdShifts, profile: owner)

            return ImportResult(
                importedShifts: importedShifts,
                importedPatterns: backup.patterns.count,
                errors: assignmentErrors
            )
        } catch {
            throw ImportError.parsingFailed(error.localizedDescription)
        }
    }

    private func previewJSON(data: Data) throws -> ImportImpact {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let backup = try decoder.decode(FullBackupData.self, from: data)
            let shiftCount = backup.shifts.count
            let patternCount = backup.patterns.count
            guard shiftCount > 0 || patternCount > 0 else {
                throw ImportError.validationFailed("No shifts or patterns found in this backup")
            }
            return ImportImpact(shiftCount: shiftCount, patternCount: patternCount, invalidRowCount: 0)
        } catch {
            throw ImportError.parsingFailed(error.localizedDescription)
        }
    }

    // MARK: - ICS Import

    private func importICS(data: Data, profile: UserProfile?) throws -> ImportResult {
        guard let icsString = String(data: data, encoding: .utf8) else {
            throw ImportError.parsingFailed("Unable to decode ICS")
        }

        let events = try parseICSEvents(icsString)
        var importedShifts = 0
        var createdShifts: [Shift] = []

        for event in events {
            guard let startDate = event.startDate, let endDate = event.endDate else { continue }
            let shift = Shift(
                scheduledStart: startDate,
                scheduledEnd: endDate,
                notes: event.summary,
                owner: profile
            )
            context.insert(shift)
            createdShifts.append(shift)
            importedShifts += 1
        }

        try context.save()
        let assignmentErrors = assignImportedShifts(createdShifts, profile: profile)

        return ImportResult(
            importedShifts: importedShifts,
            importedPatterns: 0,
            errors: assignmentErrors
        )
    }

    private func previewICS(data: Data) throws -> ImportImpact {
        guard let icsString = String(data: data, encoding: .utf8) else {
            throw ImportError.parsingFailed("Unable to decode ICS")
        }

        let events = try parseICSEvents(icsString)
        let validEvents = events.filter { $0.startDate != nil && $0.endDate != nil }
        let invalidEvents = max(events.count - validEvents.count, 0)

        guard !validEvents.isEmpty else {
            throw ImportError.validationFailed("No valid events found to import")
        }

        return ImportImpact(shiftCount: validEvents.count, patternCount: 0, invalidRowCount: invalidEvents)
    }

    // MARK: - Helper Methods

    private func parseCSVLine(_ line: String, profile: UserProfile?) throws -> Shift? {
        let components = line.components(separatedBy: ",")
        guard components.count >= 3 else { return nil }

        // Parse date and times
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        guard let date = dateFormatter.date(from: components[0].trimmingCharacters(in: .whitespaces)) else {
            throw ImportError.parsingFailed("Invalid date format")
        }

        let startTimeStr = components[1].trimmingCharacters(in: .whitespaces)
        let endTimeStr = components[2].trimmingCharacters(in: .whitespaces)

        guard let startTime = timeFormatter.date(from: startTimeStr),
              let endTime = timeFormatter.date(from: endTimeStr) else {
            throw ImportError.parsingFailed("Invalid time format")
        }

        // Combine date with times
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        startComponents.year = dateComponents.year
        startComponents.month = dateComponents.month
        startComponents.day = dateComponents.day

        guard let scheduledStart = calendar.date(from: startComponents) else {
            throw ImportError.parsingFailed("Failed to construct start date")
        }

        var endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        endComponents.year = dateComponents.year
        endComponents.month = dateComponents.month
        endComponents.day = dateComponents.day

        guard var scheduledEnd = calendar.date(from: endComponents) else {
            throw ImportError.parsingFailed("Failed to construct end date")
        }

        // Handle overnight shifts
        if scheduledEnd <= scheduledStart {
            scheduledEnd = calendar.date(byAdding: .day, value: 1, to: scheduledEnd) ?? scheduledEnd
        }

        let shift = Shift(
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            owner: profile
        )

        return shift
    }

    private func assignImportedShifts(_ shifts: [Shift], profile: UserProfile?) -> [String] {
        guard let profile, !shifts.isEmpty else { return [] }
        var errors: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for shift in shifts {
            calculator.updateCalculatedFields(for: shift)
            do {
                try periodEngine.assignToPeriod(shift, type: profile.payPeriodType)
            } catch {
                let date = formatter.string(from: shift.scheduledStart)
                errors.append("Pay period assignment failed for shift on \(date).")
            }
        }
        return errors
    }

    private func parseICSEvents(_ icsString: String) throws -> [ICSEvent] {
        var events: [ICSEvent] = []
        var currentEvent: ICSEvent?

        let lines = icsString.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("BEGIN:VEVENT") {
                currentEvent = ICSEvent()
            } else if trimmed.hasPrefix("END:VEVENT"), let event = currentEvent {
                events.append(event)
                currentEvent = nil
            } else if let event = currentEvent {
                if trimmed.hasPrefix("DTSTART") {
                    if let date = parseICSDate(trimmed) {
                        currentEvent?.startDate = date
                    }
                } else if trimmed.hasPrefix("DTEND") {
                    if let date = parseICSDate(trimmed) {
                        currentEvent?.endDate = date
                    }
                } else if trimmed.hasPrefix("SUMMARY:") {
                    currentEvent?.summary = String(trimmed.dropFirst(8))
                }
            }
        }

        return events
    }

    private func parseICSDate(_ line: String) -> Date? {
        // Parse ICS date format: DTSTART:20231201T090000Z
        let components = line.components(separatedBy: ":")
        guard components.count == 2 else { return nil }

        let dateString = components[1].replacingOccurrences(of: "Z", with: "")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")

        return formatter.date(from: dateString)
    }
}

// MARK: - Supporting Types

struct ImportResult {
    let importedShifts: Int
    let importedPatterns: Int
    let errors: [String]

    var isSuccess: Bool {
        errors.isEmpty
    }

    var summary: String {
        var message = "Imported \(importedShifts) shifts"
        if importedPatterns > 0 {
            message += " and \(importedPatterns) patterns"
        }
        if !errors.isEmpty {
            message += " with \(errors.count) errors"
        }
        return message
    }
}

struct ImportImpact {
    let shiftCount: Int
    let patternCount: Int
    let invalidRowCount: Int

    var summary: String {
        if patternCount > 0 {
            return "\(shiftCount) shifts and \(patternCount) patterns"
        }
        return "\(shiftCount) shifts"
    }
}

struct ICSEvent {
    var startDate: Date?
    var endDate: Date?
    var summary: String?
}
