import Foundation

/// CSV file generation for shift data exports
struct CSVFormatter {

    // MARK: - Export Types

    enum ExportType {
        case shifts
        case payPeriods
        case hoursSummary
    }

    // MARK: - Shift Export

    /// Exports shifts to CSV format
    func exportShifts(_ shifts: [Shift], profile: UserProfile?) -> String {
        var csv = "Date,Start Time,End Time,Scheduled Hours,Actual Hours,Paid Hours,Break (min),Rate,Rate Label,Status,Notes\n"

        for shift in shifts.sorted(by: { $0.scheduledStart < $1.scheduledStart }) {
            let date = formatDate(shift.scheduledStart)
            let startTime = formatTime(shift.effectiveStart)
            let endTime = formatTime(shift.effectiveEnd)
            let scheduledHours = String(format: "%.2f", Double(shift.scheduledDurationMinutes) / 60.0)
            let actualHours = shift.actualDurationMinutes.map { String(format: "%.2f", Double($0) / 60.0) } ?? ""
            let paidHours = String(format: "%.2f", shift.paidHours)
            let breakMinutes = "\(shift.breakMinutes)"
            let rate = String(format: "%.1f", shift.rateMultiplier)
            let rateLabel = escapeCSV(shift.rateLabel ?? "")
            let status = shift.status.displayName
            let notes = escapeCSV(shift.notes ?? "")

            csv += "\(date),\(startTime),\(endTime),\(scheduledHours),\(actualHours),\(paidHours),\(breakMinutes),\(rate),\(rateLabel),\(status),\(notes)\n"
        }

        return csv
    }

    // MARK: - Pay Period Export

    /// Exports pay periods summary to CSV
    func exportPayPeriods(_ periods: [PayPeriod], profile: UserProfile?) -> String {
        var csv = "Period Start,Period End,Duration (days),Shifts,Total Hours,Regular Hours,Premium Hours,Estimated Pay,Status\n"

        for period in periods.sorted(by: { $0.startDate < $1.startDate }) {
            let startDate = formatDate(period.startDate)
            let endDate = formatDate(period.endDate)
            let duration = "\(period.durationDays)"
            let shiftCount = "\(period.shiftCount)"
            let totalHours = String(format: "%.2f", period.paidHours)
            let regularHours = String(format: "%.2f", period.regularHours)
            let premiumHours = String(format: "%.2f", period.premiumHours)
            let estimatedPay = period.estimatedPayFormatted ?? ""
            let status = period.isComplete ? "Complete" : (period.isCurrent ? "Current" : "Future")

            csv += "\(startDate),\(endDate),\(duration),\(shiftCount),\(totalHours),\(regularHours),\(premiumHours),\(estimatedPay),\(status)\n"
        }

        return csv
    }

    // MARK: - Hours Summary Export

    /// Exports detailed hours summary with rate breakdown
    func exportHoursSummary(
        shifts: [Shift],
        period: PayPeriod?,
        profile: UserProfile?
    ) -> String {
        var csv = "Hours Summary Report\n"

        if let period = period {
            csv += "Pay Period,\(formatDate(period.startDate)) - \(formatDate(period.endDate))\n"
        }

        if let profile = profile {
            csv += "Employee,\(profile.displayName)\n"
            if let badge = profile.badgeNumber {
                csv += "Badge Number,\(badge)\n"
            }
            if let dept = profile.department {
                csv += "Department,\(dept)\n"
            }
        }

        csv += "\n"
        csv += "Rate Breakdown\n"
        csv += "Rate,Multiplier,Hours,Estimated Pay\n"

        // Calculate rate breakdown
        var rateMap: [Double: (label: String, hours: Double, pay: Double)] = [:]

        for shift in shifts where shift.isCompleted {
            let multiplier = shift.rateMultiplier
            let hours = shift.paidHours
            let label = shift.rateLabel ?? rateDisplayLabel(for: multiplier)

            var pay = 0.0
            if let baseRateCents = profile?.baseRateCents {
                pay = (Double(baseRateCents) / 100.0) * hours * multiplier
            }

            if var existing = rateMap[multiplier] {
                existing.hours += hours
                existing.pay += pay
                rateMap[multiplier] = existing
            } else {
                rateMap[multiplier] = (label, hours, pay)
            }
        }

        for (multiplier, data) in rateMap.sorted(by: { $0.key < $1.key }) {
            let rateLabel = escapeCSV(data.label)
            let multiplierStr = String(format: "%.1fx", multiplier)
            let hoursStr = String(format: "%.2f", data.hours)
            let payStr = data.pay > 0 ? String(format: "$%.2f", data.pay) : ""
            csv += "\(rateLabel),\(multiplierStr),\(hoursStr),\(payStr)\n"
        }

        csv += "\n"
        csv += "Totals\n"
        let totalHours = shifts.reduce(0.0) { $0 + ($1.isCompleted ? $1.paidHours : 0) }
        let totalPay = rateMap.values.reduce(0.0) { $0 + $1.pay }
        csv += "Total Hours,\(String(format: "%.2f", totalHours))\n"
        if totalPay > 0 {
            csv += "Total Estimated Pay,\(String(format: "$%.2f", totalPay))\n"
        }

        return csv
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

    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }

    private func rateDisplayLabel(for multiplier: Double) -> String {
        switch multiplier {
        case 2.0: return "Bank Holiday"
        case 1.5: return "Extra"
        case 1.3: return "Overtime"
        case 1.0: return "Regular"
        default: return String(format: "%.1fx", multiplier)
        }
    }
}
