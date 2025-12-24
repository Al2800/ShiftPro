import SwiftUI

/// View providing quick shift control actions.
struct QuickActionsView: View {
    @EnvironmentObject private var syncManager: WatchSyncManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Quick Actions")
                    .font(.headline)
                
                if syncManager.isPendingAction {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    actionButtons
                }
                
                if let error = syncManager.syncError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                
                connectionStatus
            }
            .padding()
        }
        .navigationTitle("Actions")
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        let hasActiveShift = syncManager.data.currentShift?.isInProgress == true
        
        if hasActiveShift {
            // Active shift actions
            ActionButton(
                title: "End Shift",
                icon: "stop.circle.fill",
                color: .red
            ) {
                syncManager.endShift()
            }
            
            ActionButton(
                title: "Log Break",
                icon: "pause.circle.fill",
                color: .orange
            ) {
                syncManager.logBreak()
            }
            
            ActionButton(
                title: "Overtime",
                icon: "plus.circle.fill",
                color: .purple
            ) {
                syncManager.markOvertime()
            }
        } else {
            // No active shift - show start button if shift is scheduled
            if let nextShift = syncManager.data.upcomingShifts.first,
               isWithinStartWindow(nextShift) {
                VStack(spacing: 8) {
                    Text("Ready to start:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(nextShift.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                ActionButton(
                    title: "Start Shift",
                    icon: "play.circle.fill",
                    color: .green
                ) {
                    syncManager.startShift()
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    Text("No shift ready to start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        
        // Always show refresh
        ActionButton(
            title: "Refresh",
            icon: "arrow.clockwise",
            color: .blue
        ) {
            syncManager.refreshData()
        }
    }
    
    // MARK: - Connection Status
    
    private var connectionStatus: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(syncManager.isReachable ? .green : .orange)
                .frame(width: 6, height: 6)
            
            Text(syncManager.isReachable ? "Connected" : "Offline")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    
    private func isWithinStartWindow(_ shift: WatchShiftData) -> Bool {
        let now = Date()
        let windowStart = shift.scheduledStart.addingTimeInterval(-15 * 60) // 15 min before
        let windowEnd = shift.scheduledStart.addingTimeInterval(30 * 60) // 30 min after
        return now >= windowStart && now <= windowEnd
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickActionsView()
        .environmentObject(WatchSyncManager())
}
