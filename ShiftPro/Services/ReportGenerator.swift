import Foundation

/// Generates formatted reports for payroll and professional use
final class ReportGenerator {

    private let csvFormatter = CSVFormatter()
    private let pdfGenerator = PDFGenerator()

    // MARK: - Payroll CSV

    func generatePayrollCSV(period: PayPeriod) throws -> Data {
        return try generatePayrollCSV(period: period, shifts: period.activeShifts)
    }

    func generatePayrollCSV(period: PayPeriod, shifts: [Shift]) throws -> Data {
        var csv = "PAYROLL REPORT\n"
        csv += "Pay Period: \(period.dateRangeFormatted)\n"
        csv += "Generated: \(formatDateTime(Date()))\n"
        csv += "\n"

        let completedShifts = shifts.filter { $0.deletedAt == nil && $0.isCompleted }
        let baseRateCents = shifts.compactMap { $0.owner?.baseRateCents }.first
        let totalPaidMinutes = completedShifts.reduce(0) { $0 + paidMinutes(for: $1) }
        let premiumMinutes = completedShifts.reduce(0) { total, shift in
            shift.rateMultiplier > 1.0 ? total + paidMinutes(for: shift) : total
        }
        let regularMinutes = max(0, totalPaidMinutes - premiumMinutes)
        let totalHours = Double(totalPaidMinutes) / 60.0
        let regularHours = Double(regularMinutes) / 60.0
        let premiumHours = Double(premiumMinutes) / 60.0

        // Summary section
        csv += "SUMMARY\n"
        csv += "Total Hours,\(String(format: "%.2f", totalHours))\n"
        csv += "Regular Hours,\(String(format: "%.2f", regularHours))\n"
        csv += "Premium Hours,\(String(format: "%.2f", premiumHours))\n"

        if let estimatedPay = estimatedPayFormatted(shifts: completedShifts, baseRateCents: baseRateCents) {
            csv += "Estimated Pay,\(estimatedPay)\n"
        }
        csv += "\n"

        // Rate breakdown
        csv += "RATE BREAKDOWN\n"
        csv += "Rate Type,Multiplier,Hours,Percentage\n"

        let groupedShifts = Dictionary(grouping: completedShifts) { $0.rateMultiplier }

        for (multiplier, shifts) in groupedShifts.sorted(by: { $0.key < $1.key }) {
            let totalMinutes = shifts.reduce(0) { $0 + paidMinutes(for: $1) }
            let hours = Double(totalMinutes) / 60.0
            let percentage = totalHours > 0 ? (hours / totalHours) * 100.0 : 0
            let label = shifts.first?.rateLabel ?? rateLabelForMultiplier(multiplier)

            let multiplierStr = String(format: "%.1fx", multiplier)
            let hoursStr = String(format: "%.2f", hours)
            let percentStr = String(format: "%.1f%%", percentage)
            csv += "\(label),\(multiplierStr),\(hoursStr),\(percentStr)\n"
        }
        csv += "\n"

        // Detailed shift list
        csv += "SHIFT DETAILS\n"
        csv += "Date,Day,Start,End,Hours,Break (min),Rate,Type\n"

        for shift in completedShifts.sorted(by: { $0.scheduledStart < $1.scheduledStart }) {
            let date = formatDate(shift.scheduledStart)
            let day = formatDayOfWeek(shift.scheduledStart)
            let start = formatTime(shift.actualStart ?? shift.scheduledStart)
            let end = formatTime(shift.actualEnd ?? shift.scheduledEnd)
            let hours = String(format: "%.2f", Double(paidMinutes(for: shift)) / 60.0)
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

    private func paidMinutes(for shift: Shift) -> Int {
        if shift.paidMinutes > 0 {
            return shift.paidMinutes
        }
        return max(0, shift.effectiveDurationMinutes - shift.breakMinutes)
    }

    private func estimatedPayFormatted(shifts: [Shift], baseRateCents: Int64?) -> String? {
        guard let baseRateCents else { return nil }
        let totalPay = shifts.reduce(0.0) { total, shift in
            let hours = Double(paidMinutes(for: shift)) / 60.0
            return total + (Double(baseRateCents) * hours * shift.rateMultiplier / 100.0)
        }
        return CurrencyFormatter.format(totalPay)
    }

    enum ReportError: Error {
        case generationFailed
    }
}
