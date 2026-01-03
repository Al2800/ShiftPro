import SwiftUI

/// A timeline visualization of shifts for a single day.
/// Shows shifts positioned vertically by their start/end times on a 24-hour scale.
struct DayTimelineView: View {
    let shifts: [Shift]
    let selectedDate: Date
    var onShiftTapped: ((Shift) -> Void)?

    private let hourHeight: CGFloat = 60
    private let calendar = Calendar.current
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Hour grid lines and labels
                    hourGrid

                    // Current time indicator (if today)
                    if calendar.isDateInToday(selectedDate) {
                        currentTimeIndicator
                    }

                    // Shift blocks
                    ForEach(positionedShifts, id: \.shift.id) { positioned in
                        shiftBlock(for: positioned)
                    }
                }
                .frame(height: hourHeight * 24 + 40)
                .padding(.leading, 50) // Space for hour labels
            }
        }
    }

    // MARK: - Hour Grid

    private var hourGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: ShiftProSpacing.extraSmall) {
                    Text(String(format: "%02d:00", hour))
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                        .frame(width: 40, alignment: .trailing)
                        .offset(x: -50) // Position outside the main content area

                    Rectangle()
                        .fill(ShiftProColors.divider)
                        .frame(height: 1)
                }
                .frame(height: hourHeight)
            }
        }
    }

    // MARK: - Current Time Indicator

    private var currentTimeIndicator: some View {
        let now = Date()
        let minutesSinceMidnight = calendar.component(.hour, from: now) * 60
            + calendar.component(.minute, from: now)
        let offset = CGFloat(minutesSinceMidnight) / 60.0 * hourHeight

        return HStack(spacing: 0) {
            Circle()
                .fill(ShiftProColors.danger)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(ShiftProColors.danger)
                .frame(height: 2)
        }
        .offset(x: -4, y: offset)
    }

    // MARK: - Shift Positioning

    private struct PositionedShift {
        let shift: Shift
        let startOffset: CGFloat
        let height: CGFloat
        let columnIndex: Int
        let totalColumns: Int
        let spansNextDay: Bool
    }

    private var positionedShifts: [PositionedShift] {
        let dayStart = calendar.startOfDay(for: selectedDate)

        // Group shifts and calculate overlaps
        var positioned: [PositionedShift] = []
        var columns: [[Shift]] = []

        for shift in shifts.sorted(by: { $0.scheduledStart < $1.scheduledStart }) {
            let startMinutes = minutesSinceDayStart(for: shift.scheduledStart, dayStart: dayStart)
            let endMinutes = minutesSinceDayEnd(for: shift.scheduledEnd, dayStart: dayStart)

            // Find a column where this shift doesn't overlap
            var placedInColumn = false
            for (index, column) in columns.enumerated() {
                let overlaps = column.contains { existing in
                    shiftsOverlap(shift, existing, dayStart: dayStart)
                }
                if !overlaps {
                    columns[index].append(shift)
                    placedInColumn = true

                    let startOffset = CGFloat(startMinutes) / 60.0 * hourHeight
                    let durationMinutes = max(30, endMinutes - startMinutes) // Minimum 30 min visibility
                    let height = CGFloat(durationMinutes) / 60.0 * hourHeight
                    let spansNextDay = !calendar.isDate(shift.scheduledEnd, inSameDayAs: selectedDate)

                    positioned.append(PositionedShift(
                        shift: shift,
                        startOffset: startOffset,
                        height: height,
                        columnIndex: index,
                        totalColumns: 0, // Will be updated later
                        spansNextDay: spansNextDay
                    ))
                    break
                }
            }

            if !placedInColumn {
                columns.append([shift])

                let startOffset = CGFloat(startMinutes) / 60.0 * hourHeight
                let durationMinutes = max(30, endMinutes - startMinutes)
                let height = CGFloat(durationMinutes) / 60.0 * hourHeight
                let spansNextDay = !calendar.isDate(shift.scheduledEnd, inSameDayAs: selectedDate)

                positioned.append(PositionedShift(
                    shift: shift,
                    startOffset: startOffset,
                    height: height,
                    columnIndex: columns.count - 1,
                    totalColumns: 0,
                    spansNextDay: spansNextDay
                ))
            }
        }

        // Update total columns for proper width calculation
        let totalColumns = columns.count
        return positioned.map { item in
            PositionedShift(
                shift: item.shift,
                startOffset: item.startOffset,
                height: item.height,
                columnIndex: item.columnIndex,
                totalColumns: totalColumns,
                spansNextDay: item.spansNextDay
            )
        }
    }

    private func minutesSinceDayStart(for date: Date, dayStart: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func minutesSinceDayEnd(for date: Date, dayStart: Date) -> Int {
        // If shift ends on a different day, cap at midnight (1440 minutes)
        if !calendar.isDate(date, inSameDayAs: dayStart) {
            return 24 * 60
        }
        return minutesSinceDayStart(for: date, dayStart: dayStart)
    }

    private func shiftsOverlap(_ first: Shift, _ second: Shift, dayStart: Date) -> Bool {
        let firstStart = minutesSinceDayStart(for: first.scheduledStart, dayStart: dayStart)
        let firstEnd = minutesSinceDayEnd(for: first.scheduledEnd, dayStart: dayStart)
        let secondStart = minutesSinceDayStart(for: second.scheduledStart, dayStart: dayStart)
        let secondEnd = minutesSinceDayEnd(for: second.scheduledEnd, dayStart: dayStart)

        return firstStart < secondEnd && firstEnd > secondStart
    }

    // MARK: - Shift Block View

    private func shiftBlock(for positioned: PositionedShift) -> some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width - ShiftProSpacing.medium
            let columnWidth = totalWidth / CGFloat(max(1, positioned.totalColumns))
            let xOffset = CGFloat(positioned.columnIndex) * columnWidth

            Button {
                onShiftTapped?(positioned.shift)
            } label: {
                VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                    HStack(spacing: ShiftProSpacing.extraExtraSmall) {
                        statusDot(for: positioned.shift)

                        Text(positioned.shift.pattern?.name ?? "Shift")
                            .font(ShiftProTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(ShiftProColors.ink)
                            .lineLimit(1)
                    }

                    Text(positioned.shift.timeRangeFormatted)
                        .font(ShiftProTypography.footnote)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                        .lineLimit(1)

                    if positioned.height > 50, let location = positioned.shift.locationDisplay {
                        Text(location)
                            .font(ShiftProTypography.footnote)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                            .lineLimit(1)
                    }

                    if positioned.spansNextDay {
                        HStack(spacing: 2) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 8))
                            Text("Overnight")
                                .font(ShiftProTypography.footnote)
                        }
                        .foregroundStyle(ShiftProColors.accent)
                    }
                }
                .padding(ShiftProSpacing.extraSmall)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: positioned.height - 4) // Slight gap between blocks
                .background(backgroundColor(for: positioned.shift))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor(for: positioned.shift), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .frame(width: columnWidth - 4)
            .offset(x: xOffset, y: positioned.startOffset)
        }
    }

    private func statusDot(for shift: Shift) -> some View {
        Circle()
            .fill(statusColor(for: shift))
            .frame(width: 6, height: 6)
    }

    private func statusColor(for shift: Shift) -> Color {
        switch shift.status {
        case .scheduled:
            return ShiftProColors.accent
        case .inProgress:
            return ShiftProColors.success
        case .completed:
            return ShiftProColors.inkSubtle
        case .cancelled:
            return ShiftProColors.danger
        }
    }

    private func backgroundColor(for shift: Shift) -> Color {
        switch shift.status {
        case .scheduled:
            return ShiftProColors.accentMuted
        case .inProgress:
            return ShiftProColors.success.opacity(0.15)
        case .completed:
            return ShiftProColors.surface
        case .cancelled:
            return ShiftProColors.danger.opacity(0.15)
        }
    }

    private func borderColor(for shift: Shift) -> Color {
        switch shift.status {
        case .scheduled:
            return ShiftProColors.accent.opacity(0.3)
        case .inProgress:
            return ShiftProColors.success.opacity(0.3)
        case .completed:
            return ShiftProColors.divider
        case .cancelled:
            return ShiftProColors.danger.opacity(0.3)
        }
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let startOfDay = calendar.startOfDay(for: today)

    // Create mock shifts
    let shift1Start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
    let shift1End = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today)!

    let shift2Start = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!
    let shift2End = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: today)!

    return DayTimelineView(
        shifts: [],
        selectedDate: today
    )
    .padding()
}
