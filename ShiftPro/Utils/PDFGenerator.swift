import Foundation
import PDFKit
import UIKit

/// PDF report generation for shift data exports
struct PDFGenerator {

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
        let pdfMetaData = [
            kCGPDFContextCreator: "ShiftPro",
            kCGPDFContextAuthor: profile?.displayName ?? "User",
            kCGPDFContextTitle: title
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            var yPosition: CGFloat = 72.0

            // Title
            yPosition = drawText(
                title,
                fontSize: 24,
                bold: true,
                at: CGPoint(x: 72, y: yPosition),
                in: context
            )

            // Profile info
            if let profile = profile {
                yPosition += 20
                if let badge = profile.badgeNumber {
                    yPosition = drawText(
                        "Badge: \(badge)",
                        fontSize: 12,
                        at: CGPoint(x: 72, y: yPosition),
                        in: context
                    )
                }
                if let dept = profile.department {
                    yPosition = drawText(
                        "Department: \(dept)",
                        fontSize: 12,
                        at: CGPoint(x: 72, y: yPosition),
                        in: context
                    )
                }
            }

            yPosition += 30

            // Table header
            let headers = ["Date", "Time", "Hours", "Rate", "Status"]
            yPosition = drawTableHeader(headers, at: yPosition, in: context)

            // Shifts
            for shift in shifts.sorted(by: { $0.scheduledStart < $1.scheduledStart }) {
                if yPosition > pageHeight - 100 {
                    context.beginPage()
                    yPosition = 72.0
                    yPosition = drawTableHeader(headers, at: yPosition, in: context)
                }

                let row = [
                    formatDate(shift.scheduledStart),
                    shift.timeRangeFormatted,
                    String(format: "%.1f", shift.paidHours),
                    String(format: "%.1fx", shift.rateMultiplier),
                    shift.status.displayName
                ]

                yPosition = drawTableRow(row, at: yPosition, in: context)
            }

            // Summary
            yPosition += 20
            let totalHours = shifts.reduce(0.0) { $0 + ($1.isCompleted ? $1.paidHours : 0) }
            drawText(
                "Total Hours: \(String(format: "%.1f", totalHours))",
                fontSize: 14,
                bold: true,
                at: CGPoint(x: 72, y: yPosition),
                in: context
            )
        }

        return data
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
        let title = period != nil ? "Hours Summary: \(period!.dateRangeFormatted)" : "Hours Summary"

        let pdfMetaData = [
            kCGPDFContextCreator: "ShiftPro",
            kCGPDFContextAuthor: profile?.displayName ?? "User",
            kCGPDFContextTitle: title
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            var yPosition: CGFloat = 72.0

            yPosition = drawText(
                title,
                fontSize: 24,
                bold: true,
                at: CGPoint(x: 72, y: yPosition),
                in: context
            )

            yPosition += 30

            // Rate breakdown
            yPosition = drawText(
                "Hours by Rate",
                fontSize: 18,
                bold: true,
                at: CGPoint(x: 72, y: yPosition),
                in: context
            )

            yPosition += 10

            let calculator = PayPeriodCalculator()
            let breakdown = calculator.rateBreakdown(for: shifts)

            for bucket in breakdown {
                yPosition += 15
                let line = "\(bucket.label): \(String(format: "%.1f", bucket.hours)) hours"
                yPosition = drawText(
                    line,
                    fontSize: 12,
                    at: CGPoint(x: 72, y: yPosition),
                    in: context
                )
            }

            yPosition += 30

            // Total
            let totalHours = shifts.reduce(0.0) { $0 + ($1.isCompleted ? $1.paidHours : 0) }
            drawText(
                "Total Hours: \(String(format: "%.1f", totalHours))",
                fontSize: 16,
                bold: true,
                at: CGPoint(x: 72, y: yPosition),
                in: context
            )
        }

        return data
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
