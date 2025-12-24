import Charts
import SwiftUI

/// Pie/bar chart showing rate multiplier distribution
struct RateBreakdownChart: View {
    struct RateData: Identifiable {
        let id = UUID()
        let label: String
        let hours: Double
        let multiplier: Double
    }

    let rateData: [RateData]
    let style: ChartStyle

    enum ChartStyle {
        case pie
        case bar
    }

    var totalHours: Double {
        rateData.reduce(0) { $0 + $1.hours }
    }

    var body: some View {
        Group {
            switch style {
            case .pie:
                pieChart
            case .bar:
                barChart
            }
        }
    }

    private var pieChart: some View {
        Chart(rateData) { data in
            SectorMark(
                angle: .value("Hours", data.hours),
                innerRadius: .ratio(0.6),
                angularInset: 2.0
            )
            .foregroundStyle(colorForMultiplier(data.multiplier))
            .annotation(position: .overlay) {
                if data.hours > 2.0 {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", data.hours))
                            .font(ShiftProTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(ShiftProColors.ink)
                        Text("hrs")
                            .font(.system(size: 9))
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            }
        }
        .frame(height: 200)
        .overlay(alignment: .center) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", totalHours))
                    .font(ShiftProTypography.title)
                    .foregroundStyle(ShiftProColors.ink)
                Text("Total Hours")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
    }

    private var barChart: some View {
        Chart(rateData) { data in
            BarMark(
                x: .value("Hours", data.hours)
            )
            .foregroundStyle(colorForMultiplier(data.multiplier))
            .annotation(position: .trailing) {
                Text(String(format: "%.1f", data.hours))
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(Int(hours))h")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self), index < rateData.count {
                        Text(rateData[index].label)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.ink)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    private func colorForMultiplier(_ multiplier: Double) -> Color {
        ShiftProColors.rateColor(multiplier: multiplier)
    }
}

#Preview {
    VStack(spacing: 24) {
        VStack(alignment: .leading) {
            Text("Pie Chart")
                .font(ShiftProTypography.headline)
            RateBreakdownChart(
                rateData: [
                    .init(label: "Regular", hours: 58.0, multiplier: 1.0),
                    .init(label: "Night", hours: 14.0, multiplier: 1.3),
                    .init(label: "Overtime", hours: 10.5, multiplier: 1.5),
                    .init(label: "Holiday", hours: 2.0, multiplier: 2.0)
                ],
                style: .pie
            )
        }

        VStack(alignment: .leading) {
            Text("Bar Chart")
                .font(ShiftProTypography.headline)
            RateBreakdownChart(
                rateData: [
                    .init(label: "Regular", hours: 58.0, multiplier: 1.0),
                    .init(label: "Night", hours: 14.0, multiplier: 1.3),
                    .init(label: "Overtime", hours: 10.5, multiplier: 1.5),
                    .init(label: "Holiday", hours: 2.0, multiplier: 2.0)
                ],
                style: .bar
            )
        }
    }
    .padding()
    .background(ShiftProColors.background)
}
