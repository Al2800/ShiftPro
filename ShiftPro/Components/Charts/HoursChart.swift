import SwiftUI
import Charts

/// Line chart showing hours accumulation over time
struct HoursChart: View {
    let dataPoints: [(date: Date, hours: Double)]
    let targetHours: Int?

    var body: some View {
        Chart {
            // Main hours line
            ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Hours", point.hours)
                )
                .foregroundStyle(ShiftProColors.accent)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Hours", point.hours)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            ShiftProColors.accent.opacity(0.3),
                            ShiftProColors.accent.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Target line (if provided)
            if let targetHours = targetHours {
                RuleMark(y: .value("Target", Double(targetHours)))
                    .foregroundStyle(ShiftProColors.warning)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Target")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ShiftProColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(Int(hours))h")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(ShiftProColors.divider.opacity(0.5))
            }
        }
        .frame(height: 200)
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let dataPoints = (0..<14).map { day in
        let date = calendar.date(byAdding: .day, value: -14 + day, to: now) ?? now
        let hours = Double(day * 6) + Double.random(in: 0...4)
        return (date: date, hours: hours)
    }

    return VStack {
        HoursChart(dataPoints: dataPoints, targetHours: 80)
            .padding()
    }
    .background(ShiftProColors.background)
}
