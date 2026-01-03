import SwiftData
import SwiftUI

/// A persistent banner showing shift status across all tabs
struct ShiftStatusBanner: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Shift> { $0.deletedAt == nil }, sort: [SortDescriptor(\Shift.scheduledStart, order: .forward)])
    private var shifts: [Shift]

    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let shift = inProgressShift {
                inProgressBanner(shift: shift)
            } else if let shift = upcomingShift {
                upcomingBanner(shift: shift)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Computed Properties

    private var inProgressShift: Shift? {
        shifts.first { $0.status == .inProgress }
    }

    private var upcomingShift: Shift? {
        let calendar = Calendar.current
        let now = Date()
        // Show upcoming shift if it starts within the next hour
        let oneHourFromNow = calendar.date(byAdding: .hour, value: 1, to: now) ?? now

        return shifts.first { shift in
            shift.status == .scheduled &&
            shift.scheduledStart >= now &&
            shift.scheduledStart <= oneHourFromNow
        }
    }

    // MARK: - In Progress Banner

    private func inProgressBanner(shift: Shift) -> some View {
        HStack(spacing: ShiftProSpacing.small) {
            // Pulsing dot indicator
            Circle()
                .fill(ShiftProColors.success)
                .frame(width: 8, height: 8)
                .modifier(PulseModifier())

            VStack(alignment: .leading, spacing: 2) {
                Text("In Progress")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.success)

                Text(elapsedTimeString(from: shift))
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            Spacer()

            Button {
                Task { await endShift(shift) }
            } label: {
                Text(isProcessing ? "..." : "End Shift")
                    .font(ShiftProTypography.callout)
                    .foregroundStyle(ShiftProColors.midnight)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(ShiftProColors.success)
                    )
            }
            .disabled(isProcessing)
            .accessibilityIdentifier("shiftBanner.endShift")
        }
        .padding(.horizontal, ShiftProSpacing.medium)
        .padding(.vertical, ShiftProSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ShiftProColors.steel)
        )
        .padding(.horizontal, ShiftProSpacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Shift in progress, \(elapsedTimeString(from: shift)) elapsed")
        .accessibilityHint("Double tap to end shift")
    }

    // MARK: - Upcoming Banner

    private func upcomingBanner(shift: Shift) -> some View {
        HStack(spacing: ShiftProSpacing.small) {
            Image(systemName: "clock.badge")
                .font(.system(size: 16))
                .foregroundStyle(ShiftProColors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Starts \(startsInString(from: shift))")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.fog)

                Text(shift.timeRangeFormatted)
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                Task { await startShift(shift) }
            } label: {
                Text(isProcessing ? "..." : "Start Shift")
                    .font(ShiftProTypography.callout)
                    .foregroundStyle(ShiftProColors.midnight)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(ShiftProColors.accent)
                    )
            }
            .disabled(isProcessing)
            .accessibilityIdentifier("shiftBanner.startShift")
        }
        .padding(.horizontal, ShiftProSpacing.medium)
        .padding(.vertical, ShiftProSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ShiftProColors.steel)
        )
        .padding(.horizontal, ShiftProSpacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Shift starts \(startsInString(from: shift))")
        .accessibilityHint("Double tap to start shift now")
    }

    // MARK: - Time Formatting

    private func elapsedTimeString(from shift: Shift) -> String {
        guard let start = shift.actualStart else { return "0:00" }

        let elapsed = currentTime.timeIntervalSince(start)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func startsInString(from shift: Shift) -> String {
        let interval = shift.scheduledStart.timeIntervalSince(currentTime)
        let minutes = Int(interval) / 60

        if minutes <= 0 {
            return "now"
        } else if minutes < 60 {
            return "in \(minutes) min"
        } else {
            let hours = minutes / 60
            return "in \(hours)h \(minutes % 60)m"
        }
    }

    // MARK: - Actions

    private func startShift(_ shift: Shift) async {
        isProcessing = true
        defer { isProcessing = false }

        let manager = await ShiftManager(context: modelContext)
        do {
            try await manager.clockIn(shift: shift)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func endShift(_ shift: Shift) async {
        isProcessing = true
        defer { isProcessing = false }

        let manager = await ShiftManager(context: modelContext)
        do {
            try await manager.clockOut(shift: shift)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Pulse Animation Modifier

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

#Preview("In Progress") {
    VStack {
        ShiftStatusBanner()
        Spacer()
    }
    .background(ShiftProColors.background)
}

#Preview("Upcoming") {
    VStack {
        ShiftStatusBanner()
        Spacer()
    }
    .background(ShiftProColors.background)
}
