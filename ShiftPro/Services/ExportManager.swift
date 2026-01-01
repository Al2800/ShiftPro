import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Main coordinator for data export operations
@MainActor
final class ExportManager {
    enum ExportFormat: CaseIterable, Hashable {
        case csv
        case pdf
        case ics
        case json
        case excel

        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .pdf: return "pdf"
            case .ics: return "ics"
            case .json: return "json"
            case .excel: return "xlsx"
            }
        }

        var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .pdf: return "application/pdf"
            case .ics: return "text/calendar"
            case .json: return "application/json"
            case .excel: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            }
        }

        var utType: UTType {
            switch self {
            case .csv: return .commaSeparatedText
            case .pdf: return .pdf
            case .ics: return .calendarEvent
            case .json: return .json
            case .excel: return .commaSeparatedText // Simplified
            }
        }
    }

    enum ExportCategory {
        case shiftReport(PayPeriod)
        case hoursSummary(PayPeriod)
        case patternExport(ShiftPattern)
        case fullBackup
        case payrollReport(PayPeriod)
    }

    enum ExportError: LocalizedError {
        case noData
        case formatNotSupported
        case exportFailed(String)
        case encryptionFailed

        var errorDescription: String? {
            switch self {
            case .noData:
                return "No data available to export"
            case .formatNotSupported:
                return "Export format not supported for this data type"
            case .exportFailed(let reason):
                return "Export failed: \(reason)"
            case .encryptionFailed:
                return "Failed to encrypt export data"
            }
        }
    }

    private let context: ModelContext
    private let csvFormatter: CSVFormatter
    private let pdfGenerator: PDFGenerator
    private let reportGenerator: ReportGenerator
    private let encryptionManager: EncryptionManager

    init(context: ModelContext, encryptionManager: EncryptionManager = EncryptionManager()) {
        self.context = context
        self.csvFormatter = CSVFormatter()
        self.pdfGenerator = PDFGenerator()
        self.reportGenerator = ReportGenerator()
        self.encryptionManager = encryptionManager
    }

    // MARK: - Main Export Method

    func export(
        category: ExportCategory,
        format: ExportFormat,
        dateRange: DateInterval? = nil,
        password: String? = nil
    ) throws -> URL {
        // Generate export data based on category and format
        let data: Data

        switch (category, format) {
        case (.shiftReport(let period), .csv):
            data = try exportShiftReportCSV(period: period)
        case (.shiftReport(let period), .pdf):
            data = try exportShiftReportPDF(period: period)
        case (.hoursSummary(let period), .csv):
            data = try exportHoursSummaryCSV(period: period)
        case (.hoursSummary(let period), .pdf):
            data = try exportHoursSummaryPDF(period: period)
        case (.patternExport(let pattern), .json):
            data = try exportPatternJSON(pattern: pattern)
        case (.fullBackup, .json):
            data = try exportFullBackupJSON()
        case (.payrollReport(let period), .csv):
            data = try exportPayrollReportCSV(period: period)
        case (.payrollReport(let period), .pdf):
            data = try exportPayrollReportPDF(period: period)
        default:
            throw ExportError.formatNotSupported
        }

        // Apply encryption if password provided
        let finalData = if let password = password {
            try encryptData(data, password: password)
        } else {
            data
        }

        // Write to temporary file
        let filename = generateFilename(category: category, format: format)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try finalData.write(to: fileURL)

        return fileURL
    }

    // MARK: - Shift Report Exports

    private func exportShiftReportCSV(period: PayPeriod) throws -> Data {
        let shifts = period.activeShifts.sorted { $0.scheduledStart < $1.scheduledStart }
        return try csvFormatter.formatShiftReport(shifts: shifts)
    }

    private func exportShiftReportPDF(period: PayPeriod) throws -> Data {
        let shifts = period.activeShifts.sorted { $0.scheduledStart < $1.scheduledStart }
        return try pdfGenerator.generateShiftReport(shifts: shifts, period: period)
    }

    // MARK: - Hours Summary Exports

    private func exportHoursSummaryCSV(period: PayPeriod) throws -> Data {
        return try csvFormatter.formatHoursSummary(period: period)
    }

    private func exportHoursSummaryPDF(period: PayPeriod) throws -> Data {
        return try pdfGenerator.generateHoursSummary(period: period)
    }

    // MARK: - Pattern Exports

    private func exportPatternJSON(pattern: ShiftPattern) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let exportData = PatternExportData(from: pattern)
        return try encoder.encode(exportData)
    }

    // MARK: - Full Backup

    private func exportFullBackupJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        // Fetch all data
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let shifts = try context.fetch(FetchDescriptor<Shift>())
        let patterns = try context.fetch(FetchDescriptor<ShiftPattern>())
        let periods = try context.fetch(FetchDescriptor<PayPeriod>())

        let backup = FullBackupData(
            version: "1.0",
            exportDate: Date(),
            profiles: profiles.map { ProfileBackupData(from: $0) },
            shifts: shifts.map { ShiftBackupData(from: $0) },
            patterns: patterns.map { PatternBackupData(from: $0) },
            payPeriods: periods.map { PayPeriodBackupData(from: $0) }
        )

        return try encoder.encode(backup)
    }

    // MARK: - Payroll Reports

    private func exportPayrollReportCSV(period: PayPeriod) throws -> Data {
        return try reportGenerator.generatePayrollCSV(period: period)
    }

    private func exportPayrollReportPDF(period: PayPeriod) throws -> Data {
        return try reportGenerator.generatePayrollPDF(period: period)
    }

    // MARK: - Helper Methods

    private func generateFilename(category: ExportCategory, format: ExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        let baseName: String
        switch category {
        case .shiftReport(let period):
            baseName = "shift-report-\(period.dateRangeFormatted.replacingOccurrences(of: " ", with: "-"))"
        case .hoursSummary(let period):
            baseName = "hours-summary-\(period.dateRangeFormatted.replacingOccurrences(of: " ", with: "-"))"
        case .patternExport(let pattern):
            baseName = "pattern-\(pattern.title.replacingOccurrences(of: " ", with: "-"))"
        case .fullBackup:
            baseName = "shiftpro-backup-\(dateString)"
        case .payrollReport(let period):
            baseName = "payroll-\(period.dateRangeFormatted.replacingOccurrences(of: " ", with: "-"))"
        }

        return "\(baseName).\(format.fileExtension)"
    }

    private func encryptData(_ data: Data, password: String) throws -> Data {
        return try encryptionManager.encrypt(data, password: password)
    }
}

// MARK: - Export Data Models

struct PatternExportData: Codable {
    let title: String
    let scheduleType: String
    let defaultStartTime: Date?
    let defaultEndTime: Date?
    let defaultBreakMinutes: Int
    let daysOfWeekMask: Int16
    let cycleDays: Int?

    init(from pattern: ShiftPattern) {
        self.title = pattern.title
        self.scheduleType = pattern.scheduleType == .weekly ? "weekly" : "cycling"
        self.defaultStartTime = pattern.defaultStartTime
        self.defaultEndTime = pattern.defaultEndTime
        self.defaultBreakMinutes = pattern.defaultBreakMinutes
        self.daysOfWeekMask = pattern.daysOfWeekMask
        self.cycleDays = pattern.cycleDays
    }
}

struct FullBackupData: Codable {
    let version: String
    let exportDate: Date
    let profiles: [ProfileBackupData]
    let shifts: [ShiftBackupData]
    let patterns: [PatternBackupData]
    let payPeriods: [PayPeriodBackupData]
}

struct ProfileBackupData: Codable {
    let name: String
    let employeeId: String?
    let workplace: String?
    let jobTitle: String?
    let baseRateCents: Int64?
    let regularHoursPerPay: Int
    let targetWeeklyHours: Int

    init(from profile: UserProfile) {
        self.name = profile.name
        self.employeeId = profile.employeeId
        self.workplace = profile.workplace
        self.jobTitle = profile.jobTitle
        self.baseRateCents = profile.baseRateCents
        self.regularHoursPerPay = profile.regularHoursPerPay
        self.targetWeeklyHours = profile.targetWeeklyHours
    }
}

struct ShiftBackupData: Codable {
    let scheduledStart: Date
    let scheduledEnd: Date
    let actualStart: Date?
    let actualEnd: Date?
    let breakMinutes: Int
    let isAdditionalShift: Bool
    let notes: String?
    let rateMultiplier: Double
    let rateLabel: String?

    init(from shift: Shift) {
        self.scheduledStart = shift.scheduledStart
        self.scheduledEnd = shift.scheduledEnd
        self.actualStart = shift.actualStart
        self.actualEnd = shift.actualEnd
        self.breakMinutes = shift.breakMinutes
        self.isAdditionalShift = shift.isAdditionalShift
        self.notes = shift.notes
        self.rateMultiplier = shift.rateMultiplier
        self.rateLabel = shift.rateLabel
    }
}

struct PatternBackupData: Codable {
    let title: String
    let scheduleType: String
    let defaultStartTime: Date?
    let defaultEndTime: Date?
    let defaultBreakMinutes: Int

    init(from pattern: ShiftPattern) {
        self.title = pattern.title
        self.scheduleType = pattern.scheduleType == .weekly ? "weekly" : "cycling"
        self.defaultStartTime = pattern.defaultStartTime
        self.defaultEndTime = pattern.defaultEndTime
        self.defaultBreakMinutes = pattern.defaultBreakMinutes
    }
}

struct PayPeriodBackupData: Codable {
    let startDate: Date
    let endDate: Date
    let paidMinutes: Int
    let premiumMinutes: Int

    init(from period: PayPeriod) {
        self.startDate = period.startDate
        self.endDate = period.endDate
        self.paidMinutes = period.paidMinutes
        self.premiumMinutes = period.premiumMinutes
    }
}
