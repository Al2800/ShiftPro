import SwiftUI

/// View showing pay period hours summary.
struct HoursSummaryView: View {
    @EnvironmentObject private var syncManager: WatchSyncManager
    
    var body: some View {
        ScrollView {
            if let hours = syncManager.data.hoursData {
                hoursContent(hours)
            } else {
                noDataView
            }
        }
        .navigationTitle("Hours")
    }
    
    // MARK: - Hours Content
    
    private func hoursContent(_ hours: WatchHoursData) -> some View {
        VStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: hours.progress)
                    .stroke(progressColor(hours.progress), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text(hours.hoursFormatted)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("/ \(Int(hours.targetHours))h")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)
            
            // Period info
            Text(hours.periodFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Progress percentage
            Text("\(hours.progressPercent)% complete")
                .font(.caption)
                .foregroundStyle(progressColor(hours.progress))
            
            Divider()
            
            // Hours breakdown
            VStack(spacing: 8) {
                hoursRow(label: "Regular", hours: hours.regularHours, color: .blue)
                hoursRow(label: "Premium", hours: hours.premiumHours, color: .orange)
            }
            
            // Estimated pay
            if let pay = hours.estimatedPayFormatted {
                Divider()
                
                VStack(spacing: 2) {
                    Text("Estimated Pay")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(pay)
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
    }
    
    private func hoursRow(label: String, hours: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
            
            Spacer()
            
            Text(String(format: "%.1fh", hours))
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - No Data View
    
    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("No Hours Data")
                .font(.headline)
            
            Text("Complete shifts to track hours")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func progressColor(_ progress: Double) -> Color {
        if progress >= 1.0 {
            return .green
        } else if progress >= 0.9 {
            return .orange
        } else {
            return .blue
        }
    }
}

#Preview {
    HoursSummaryView()
        .environmentObject(WatchSyncManager())
}
