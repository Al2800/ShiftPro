import SwiftUI

/// View showing upcoming shifts list.
struct UpcomingShiftsView: View {
    @EnvironmentObject private var syncManager: WatchSyncManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if syncManager.data.upcomingShifts.isEmpty {
                    emptyState
                } else {
                    ForEach(syncManager.data.upcomingShifts.prefix(5)) { shift in
                        ShiftRowView(shift: shift)
                    }
                    
                    if syncManager.data.upcomingShifts.count > 5 {
                        Text("+ \(syncManager.data.upcomingShifts.count - 5) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Schedule")
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("No Upcoming Shifts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }
}

// MARK: - Shift Row

struct ShiftRowView: View {
    let shift: WatchShiftData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date header
            HStack {
                Text(shift.dayFormatted.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(isToday ? .blue : .secondary)
                
                Spacer()
                
                if let countdown = shift.countdownFormatted {
                    Text(countdown)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            
            // Shift info
            HStack {
                Text(shift.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Spacer()
                
                if shift.rateMultiplier > 1.0 {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(rateColor)
                }
            }
            
            // Time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(shift.timeRangeFormatted)
                    .font(.caption2)
                
                Spacer()
                
                Text(shift.durationFormatted)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(isToday ? Color.blue.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(shift.scheduledStart)
    }
    
    private var rateColor: Color {
        switch shift.rateMultiplier {
        case 2.0: return .red
        case 1.5: return .orange
        case 1.3: return .blue
        default: return .green
        }
    }
}

#Preview {
    UpcomingShiftsView()
        .environmentObject(WatchSyncManager())
}
