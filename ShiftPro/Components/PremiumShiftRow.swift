import SwiftUI

// MARK: - Premium Shift Row

struct PremiumShiftRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    let shift: Shift
    let profile: UserProfile?
    var onTap: (() -> Void)?

    private var statusColor: Color {
        switch shift.status {
        case .scheduled: return ShiftProColors.accent
        case .inProgress: return ShiftProColors.success
        case .completed: return ShiftProColors.inkSubtle
        case .cancelled: return ShiftProColors.danger
        }
    }

    private var timeOfDayIcon: String {
        let hour = Calendar.current.component(.hour, from: shift.scheduledStart)
        switch hour {
        case 5..<12: return "sunrise.fill"
        case 12..<17: return "sun.max.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.fill"
        }
    }

    private var estimatedPay: String? {
        guard let baseRateCents = profile?.baseRateCents, baseRateCents > 0 else { return nil }
        let paidMinutes = max(0, shift.scheduledDurationMinutes - shift.breakMinutes)
        let hours = Double(paidMinutes) / 60.0
        let pay = hours * Double(baseRateCents) / 100.0 * shift.rateMultiplier
        guard pay > 0 else { return nil }
        return CurrencyFormatter.format(pay)
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: ShiftProSpacing.medium) {
                // Time of day icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    statusColor.opacity(0.2),
                                    statusColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: timeOfDayIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                // Shift details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(shift.displayTitle)
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(ShiftProColors.ink)

                        if shift.rateMultiplier > 1.0 {
                            Text("\(String(format: "%.1fx", shift.rateMultiplier))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ShiftProColors.warning)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(ShiftProColors.warning.opacity(0.15))
                                )
                        }
                    }

                    Text(dateTimeLabel)
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    HStack(spacing: 12) {
                        if let location = shift.locationDisplay, !location.isEmpty {
                            Label(location, systemImage: "mappin")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }

                        if let pay = estimatedPay {
                            Label(pay, systemImage: CurrencyFormatter.currencySymbolIconName)
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.success)
                        }
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ShiftProColors.inkSubtle.opacity(0.5))
            }
            .padding(ShiftProSpacing.medium)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(ShiftProColors.surface)

                    // Top highlight
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )

                    // Status accent bar
                    HStack {
                        Rectangle()
                            .fill(statusColor)
                            .frame(width: 3)
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    // Border
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
            .shadow(color: statusColor.opacity(0.08), radius: 12, x: 0, y: 6)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        HapticManager.fire(.impactLight, enabled: !reduceMotion)
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }

    private var dateTimeLabel: String {
        let formatter = DateFormatter()

        if Calendar.current.isDateInToday(shift.scheduledStart) {
            formatter.dateFormat = "'Today' • h:mm a"
        } else if Calendar.current.isDateInTomorrow(shift.scheduledStart) {
            formatter.dateFormat = "'Tomorrow' • h:mm a"
        } else {
            formatter.dateFormat = "EEE, MMM d • h:mm a"
        }

        let start = formatter.string(from: shift.scheduledStart)

        formatter.dateFormat = "h:mm a"
        let end = formatter.string(from: shift.scheduledEnd)

        return "\(start) - \(end)"
    }
}

// MARK: - Compact Shift Pill

struct CompactShiftPill: View {
    let shift: Shift

    private var statusColor: Color {
        switch shift.status {
        case .scheduled: return ShiftProColors.accent
        case .inProgress: return ShiftProColors.success
        case .completed: return ShiftProColors.inkSubtle
        case .cancelled: return ShiftProColors.danger
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(timeLabel)
                .font(ShiftProTypography.caption)
                .fontWeight(.medium)
                .foregroundStyle(ShiftProColors.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.12))
        )
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: shift.scheduledStart)
    }
}

// MARK: - Live Shift Card

struct LiveShiftCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    let shift: Shift
    let profile: UserProfile?
    var onEndShift: (() -> Void)?
    var onLogBreak: ((Int) -> Void)?

    private var progress: Double {
        guard let start = shift.actualStart else { return 0 }
        let total = shift.scheduledEnd.timeIntervalSince(shift.scheduledStart)
        let elapsed = elapsedTime
        return min(elapsed / total, 1.0)
    }

    private var elapsedLabel: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var estimatedPay: String? {
        guard let baseRateCents = profile?.baseRateCents, baseRateCents > 0 else { return nil }
        let paidMinutes = max(0, Int(elapsedTime / 60) - shift.breakMinutes)
        let hours = Double(paidMinutes) / 60.0
        let pay = hours * Double(baseRateCents) / 100.0 * shift.rateMultiplier
        guard pay > 0 else { return nil }
        return CurrencyFormatter.format(pay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(ShiftProColors.success)
                        .frame(width: 8, height: 8)
                        .modifier(PulsingDot())

                    Text("Live")
                        .font(ShiftProTypography.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(ShiftProColors.success)
                }

                Spacer()

                Text(shift.displayTitle)
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            // Timer display
            HStack(alignment: .bottom, spacing: 8) {
                Text(elapsedLabel)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(ShiftProColors.ink)
                    .monospacedDigit()

                if let pay = estimatedPay {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Earned")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                        Text(pay)
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(ShiftProColors.success)
                    }
                    .padding(.bottom, 8)
                }
            }

            // Progress bar
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ShiftProColors.success.opacity(0.15))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ShiftProColors.success,
                                    ShiftProColors.success.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 6)

            // Break controls
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 12))
                    Text("\(shift.breakMinutes) min")
                        .font(ShiftProTypography.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(ShiftProColors.inkSubtle)

                Spacer()

                ForEach([5, 15, 30], id: \.self) { minutes in
                    Button {
                        onLogBreak?(minutes)
                    } label: {
                        Text("+\(minutes)m")
                            .font(ShiftProTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(ShiftProColors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(ShiftProColors.accent.opacity(0.12))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // End shift button
            PremiumButton(
                title: "End Shift",
                icon: "stop.fill",
                style: .success,
                fullWidth: true
            ) {
                onEndShift?()
            }
        }
        .padding(ShiftProSpacing.large)
        .depthCard(cornerRadius: 28, elevation: 16)
        .onAppear {
            updateElapsedTime()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateElapsedTime()
        }
    }

    private func updateElapsedTime() {
        guard let start = shift.actualStart else { return }
        elapsedTime = Date().timeIntervalSince(start)
    }
}

// MARK: - Pulsing Dot Modifier

private struct PulsingDot: ViewModifier {
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

#Preview("Shift Row") {
    VStack(spacing: 16) {
        // These would need actual Shift objects in real usage
        Text("Premium Shift Row Preview")
            .foregroundStyle(ShiftProColors.ink)
    }
    .padding()
    .background(ShiftProColors.background)
}
