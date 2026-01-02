import Foundation
import PDFKit
import UIKit

/// PDF report generation for shift data exports
struct PDFGenerator {

    // MARK: - Constants

    private let pageWidth = 8.5 * 72.0
    private let pageHeight = 11.0 * 72.0
    private let leftMargin: CGFloat = 72.0

    private var pageRect: CGRect {
        CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    }

    // MARK: - Report Types

    enum ReportType {
        case shifts
        case payPeriod
        case hoursSummary
    }

    // MARK: - PDF Generation

    /// Generates a PDF document from shifts data
    func generateShiftsReport(
        shifts: [Shift],
        profile: UserProfile?,
        title: String = "Shift Report"
    ) -> Data? {
        let renderer = makeRenderer(title: title, author: profile?.displayName)

        return renderer.pdfData { context in
            context.beginPage()
            var yPos = drawReportHeader(title: title, profile: profile, in: context)
            yPos = drawShiftsTable(shifts: shifts, startingAt: yPos, in: context)
            drawShiftsSummary(shifts: shifts, at: yPos, in: context)
        }
    }

    private func drawReportHeader(
        title: String,
        profile: UserProfile?,
        in context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var yPos: CGFloat = leftMargin

        yPos = drawText(title, fontSize: 24, bold: true, at: CGPoint(x: leftMargin, y: yPos), in: context)

        if let profile = profile {
            yPos += 20
            yPos = drawProfileInfo(profile, at: yPos, in: context)
        }

        return yPos + 30
    }

    private func drawProfileInfo(
        _ profile: UserProfile,
        at yPosition: CGFloat,
        in context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var yPos = yPosition

        if let workplace = profile.workplace {
            yPos = drawText("Workplace: \(workplace)", fontSize: 12, at: CGPoint(x: leftMargin, y: yPos), in: context)
        }
        if let jobTitle = profile.jobTitle {
            yPos = drawText("Position: \(jobTitle)", fontSize: 12, at: CGPoint(x: leftMargin, y: yPos), in: context)
        }

        return yPos
    }

    private func drawShiftsTable(
        shifts: [Shift],
        startingAt yPosition: CGFloat,
        in context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let headers = ["Date", "Time", "Hours", "Rate", "Status"]
        var yPos = drawTableHeader(headers, at: yPosition, in: context)

        for shift in shifts.sorted(by: { $0.scheduledStart < $1.scheduledStart }) {
            if yPos > pageHeight - 100 {
                context.beginPage()
                yPos = leftMargin
                yPos = drawTableHeader(headers, at: yPos, in: context)
            }
            yPos = drawTableRow(buildShiftRow(shift), at: yPos, in: context)
        }

        return yPos + 20
    }

    private func buildShiftRow(_ shift: Shift) -> [String] {
        [
            formatDate(shift.scheduledStart),
            shift.timeRangeFormatted,
            String(format: "%.1f", shift.paidHours),
            String(format: "%.1fx", shift.rateMultiplier),
            shift.status.displayName
        ]
    }

    @discardableResult
    private func drawShiftsSummary(
        shifts: [Shift],
        at yPosition: CGFloat,
        in context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let totalHours = shifts.reduce(0.0) { $0 + ($1.isCompleted ? $1.paidHours : 0) }
        return drawText(
            "Total Hours: \(String(format: "%.1f", totalHours))",
            fontSize: 14,
            bold: true,
            at: CGPoint(x: leftMargin, y: yPosition),
            in: context
        )
    }

    /// Generates a pay period summary PDF
    func generatePayPeriodReport(
        period: PayPeriod,
        profile: UserProfile?
    ) -> Data? {
        let title = "Pay Period Report: \(period.dateRangeFormatted)"
        return generateShiftsReport(
            shifts: period.activeShifts,
            profile: profile,
            title: title
        )
    }

    /// Generates a comprehensive hours summary PDF
    func generateHoursSummaryReport(
        shifts: [Shift],
        period: PayPeriod?,
        profile: UserProfile?
    ) -> Data? {
        let title = period.map { "Hours Summary: \($0.dateRangeFormatted)" } ?? "Hours Summary"
        let renderer = makeRenderer(title: title, author: profile?.displayName)

        return renderer.pdfData { context in
            context.beginPage()
            var yPos: CGFloat = leftMargin

            yPos = drawText(title, fontSize: 24, bold: true, at: CGPoint(x: leftMargin, y: yPos), in: context)
            yPos += 30
            yPos = drawRateBreakdown(shifts: shifts, at: yPos, in: context)
            drawShiftsSummary(shifts: shifts, at: yPos, in: context)
        }
    }

    private func drawRateBreakdown(
        shifts: [Shift],
        at yPosition: CGFloat,
        in context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var yPos = drawText(
            "Hours by Rate",
            fontSize: 18,
            bold: true,
            at: CGPoint(x: leftMargin, y: yPosition),
            in: context
        )
        yPos += 10

        let calculator = PayPeriodCalculator()
        let breakdown = calculator.rateBreakdown(for: shifts)

        for bucket in breakdown {
            yPos += 15
            let line = "\(bucket.label): \(String(format: "%.1f", bucket.hours)) hours"
            yPos = drawText(line, fontSize: 12, at: CGPoint(x: leftMargin, y: yPos), in: context)
        }

        return yPos + 30
    }

    // MARK: - Renderer Factory

    private func makeRenderer(title: String, author: String?) -> UIGraphicsPDFRenderer {
        let pdfMetaData = [
            kCGPDFContextCreator: "ShiftPro",
            kCGPDFContextAuthor: author ?? "User",
            kCGPDFContextTitle: title
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        return UIGraphicsPDFRenderer(bounds: pageRect, format: format)
    }

    // MARK: - Drawing Helpers

    private func drawText(
        _ text: String,
        fontSize: CGFloat,
        bold: Bool = false,
        at point: CGPoint,
        in context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]

        text.draw(at: point, withAttributes: attributes)

        let textSize = (text as NSString).size(withAttributes: attributes)
        return point.y + textSize.height
    }

    private func drawTableHeader(
        _ headers: [String],
        at yPosition: CGFloat,
        in context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let columnWidth: CGFloat = 100
        var xPosition: CGFloat = 72

        for header in headers {
            drawText(
                header,
                fontSize: 10,
                bold: true,
                at: CGPoint(x: xPosition, y: yPosition),
                in: context
            )
            xPosition += columnWidth
        }

        return yPosition + 15
    }

    private func drawTableRow(
        _ row: [String],
        at yPosition: CGFloat,
        in context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let columnWidth: CGFloat = 100
        var xPosition: CGFloat = 72

        for cell in row {
            drawText(
                cell,
                fontSize: 10,
                at: CGPoint(x: xPosition, y: yPosition),
                in: context
            )
            xPosition += columnWidth
        }

        return yPosition + 12
    }


    // MARK: - Export Manager Compatibility Methods

    /// Generates shift report PDF - wrapper for ExportManager
    func generateShiftReport(shifts: [Shift], period: PayPeriod) throws -> Data {
        guard let data = generateShiftsReport(shifts: shifts, profile: nil, title: "Shift Report: \(period.dateRangeFormatted)") else {
            throw NSError(domain: "PDFGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"])
        }
        return data
    }

    /// Generates hours summary PDF - wrapper for ExportManager
    func generateHoursSummary(period: PayPeriod) throws -> Data {
        guard let data = generateHoursSummaryReport(shifts: period.activeShifts, period: period, profile: nil) else {
            throw NSError(domain: "PDFGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"])
        }
        return data
    }

    func generateHoursSummary(period: PayPeriod, shifts: [Shift]) throws -> Data {
        guard let data = generateHoursSummaryReport(shifts: shifts, period: period, profile: nil) else {
            throw NSError(domain: "PDFGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"])
        }
        return data
    }

    /// Generates payroll report PDF - wrapper for ReportGenerator
    func generatePayrollReport(period: PayPeriod) throws -> Data {
        guard let data = generatePayPeriodReport(period: period, profile: nil) else {
            throw NSError(domain: "PDFGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"])
        }
        return data
    }

    func generatePayrollReport(period: PayPeriod, shifts: [Shift]) throws -> Data {
        guard let data = generatePayPeriodReport(period: period, shifts: shifts, profile: nil) else {
            throw NSError(domain: "PDFGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"])
        }
        return data
    }

    private func generatePayPeriodReport(
        period: PayPeriod,
        shifts: [Shift],
        profile: UserProfile?
    ) -> Data? {
        let title = "Pay Period Report: \(period.dateRangeFormatted)"
        return generateShiftsReport(shifts: shifts, profile: profile, title: title)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
