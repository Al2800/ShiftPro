import SwiftUI
import WatchKit

@main
struct ShiftProWatchApp: App {
    @StateObject private var syncManager = WatchSyncManager()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .environmentObject(syncManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var syncManager: WatchSyncManager
    
    var body: some View {
        TabView {
            ShiftStatusView()
                .tag(0)
            
            QuickActionsView()
                .tag(1)
            
            UpcomingShiftsView()
                .tag(2)
            
            HoursSummaryView()
                .tag(3)
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSyncManager())
}
