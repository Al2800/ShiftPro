import SwiftUI

/// View showing the current shift status with elapsed/remaining time.
struct ShiftStatusView: View {
    @EnvironmentObject private var syncManager: WatchSyncManager
    
    var body: some View {
        ScrollView {
            if let shift = syncManager.data.currentShift, shift.isInProgress {
                activeShiftView(shift)
            } else if let nextShift = syncManager.data.upcomingShifts.first {
                nextShiftPreview(nextShift)
            } else {
                noShiftView
            }
        }
        .navigationTitle("Shift")
    }
    
    // MARK: - Active Shift View
    
    private func activeShiftView(_ shift: WatchShiftData) -> some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption2)
                Text("In Progress")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            
            // Shift title
            Text(shift.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // Progress ring with time
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.3), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: shiftProgress(shift))
                    .stroke(.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    if let elapsed = shift.elapsedFormatted {
                        Text(elapsed)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("elapsed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 100, height: 100)
            
            // Time range
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(shift.timeRangeFormatted)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            
            // Remaining time
            if let remaining = shift.remainingFormatted {
                Text("\(remaining) left")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            // Rate badge
            if shift.rateMultiplier > 1.0 {
                rateBadge(multiplier: shift.rateMultiplier, label: shift.rateLabel)
            }
        }
        .padding()
    }
    
    // MARK: - Next Shift Preview
    
    private func nextShiftPreview(_ shift: WatchShiftData) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("No Active Shift")
                .font(.headline)
            
            Divider()
            
            Text("Next Shift")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(shift.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(shift.dateFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let countdown = shift.countdownFormatted {
                Text(countdown)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
    }
    
    // MARK: - No Shift View
    
    private var noShiftView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No Shifts")
                .font(.headline)
            
            Text("Open ShiftPro on iPhone to add shifts")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func shiftProgress(_ shift: WatchShiftData) -> CGFloat {
        guard let elapsed = shift.elapsedMinutes else { return 0 }
        let total = shift.durationMinutes
        guard total > 0 else { return 0 }
        return CGFloat(min(1.0, Double(elapsed) / Double(total)))
    }
    
    private func rateBadge(multiplier: Double, label: String?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(label ?? String(format: "%.1fx", multiplier))
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(rateColor(multiplier).opacity(0.2))
        .foregroundStyle(rateColor(multiplier))
        .clipShape(Capsule())
    }
    
    private func rateColor(_ multiplier: Double) -> Color {
        switch multiplier {
        case 2.0: return .red
        case 1.5: return .orange
        case 1.3: return .blue
        default: return .green
        }
    }
}

#Preview {
    ShiftStatusView()
        .environmentObject(WatchSyncManager())
}
