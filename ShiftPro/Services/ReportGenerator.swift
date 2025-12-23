import Foundation

/// Generates formatted reports for payroll and professional use
final class ReportGenerator {

    private let csvFormatter = CSVFormatter()
    private let pdfGenerator = PDFGenerator()

    // MARK: - Payroll CSV

    func generatePayrollCSV(period: PayPeriod) throws -> Data {
        var csv = "PAYROLL REPORT\n"
        csv += "Pay Period: \(period.dateRangeFormatted)\n"
        csv += "Generated: \(formatDateTime(Date()))\n"
        csv += "\n"

        // Summary section
        csv += "SUMMARY\n"
        csv += "Total Hours,\(String(format: "%.2f", period.paidHours))\n"
        csv += "Regular Hours,\(String(format: "%.2f", period.regularHours))\n"
        csv += "Premium Hours,\(String(format: "%.2f", period.premiumHours))\n"

        if let estimatedPay = period.estimatedPayFormatted {
            csv += "Estimated Pay,\(estimatedPay)\n"
        }
        csv += "\n"

        // Rate breakdown
        csv += "RATE BREAKDOWN\n"
        csv += "Rate Type,Multiplier,Hours,Percentage\n"

        let totalHours = period.paidHours
        let groupedShifts = Dictionary(grouping: period.completedShifts) { $0.rateMultiplier }

        for (multiplier, shifts) in groupedShifts.sorted(by: { $0.key < $1.key }) {
            let totalMinutes = shifts.reduce(0) { $0 + $1.paidMinutes }
            let hours = Double(totalMinutes) / 60.0
            let percentage = totalHours > 0 ? (hours / totalHours) * 100.0 : 0
            let label = shifts.first?.rateLabel ?? rateLabelForMultiplier(multiplier)

            csv += "\(label),\(String(format: "%.1fx", multiplier)),\(String(format: "%.2f", hours)),\(String(format: "%.1f%%", percentage))\n"
        }
        csv += "\n"

        // Detailed shift list
        csv += "SHIFT DETAILS\n"
        csv += "Date,Day,Start,End,Hours,Break (min),Rate,Type\n"

        for shift in period.completedShifts.sorted(by: { $0.scheduledStart < $1.scheduledStart }) {
            let date = formatDate(shift.scheduledStart)
            let day = formatDayOfWeek(shift.scheduledStart)
            let start = formatTime(shift.actualStart ?? shift.scheduledStart)
            let end = formatTime(shift.actualEnd ?? shift.scheduledEnd)
            let hours = String(format: "%.2f", shift.paidHours)
            let breakMins = "\(shift.breakMinutes)"
            let rate = String(format: "%.1fx", shift.rateMultiplier)
            let type = shift.isAdditionalShift ? "Additional" : "Regular"

            csv += "\(date),\(day),\(start),\(end),\(hours),\(breakMins),\(rate),\(type)\n"
        }

        guard let data = csv.data(using: .utf8) else {
            throw ReportError.generationFailed
        }

        return data
    }

    // MARK: - Payroll PDF

    func generatePayrollPDF(period: PayPeriod) throws -> Data {
        return try pdfGenerator.generatePayrollReport(period: period)
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func rateLabelForMultiplier(_ multiplier: Double) -> String {
        switch multiplier {
        case 1.0:
            return "Regular"
        case 1.3:
            return "Overtime"
        case 1.5:
            return "Extra"
        case 2.0:
            return "Bank Holiday"
        default:
            return String(format: "%.1fx", multiplier)
        }
    }

    enum ReportError: Error {
        case generationFailed
    }
}
