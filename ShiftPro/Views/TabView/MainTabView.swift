import SwiftUI

struct MainTabView: View {
    @AppStorage("showAddShiftAfterOnboarding") private var showAddShiftAfterOnboarding = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tag(0)
            .accessibilityIdentifier(AccessibilityIdentifiers.tabDashboard)
            .tabItem {
                Label("Dashboard", systemImage: "gauge")
            }

            NavigationStack {
                ScheduleView()
            }
            .tag(1)
            .accessibilityIdentifier(AccessibilityIdentifiers.tabSchedule)
            .tabItem {
                Label("Schedule", systemImage: "calendar")
            }

            NavigationStack {
                HoursView()
            }
            .tag(2)
            .accessibilityIdentifier(AccessibilityIdentifiers.tabHours)
            .tabItem {
                Label("Hours", systemImage: "clock")
            }

            NavigationStack {
                SettingsView()
            }
            .tag(3)
            .accessibilityIdentifier(AccessibilityIdentifiers.tabSettings)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(ShiftProColors.accent)
        .onAppear {
            // Navigate to Schedule tab if user chose to add their first shift after onboarding
            if showAddShiftAfterOnboarding {
                selectedTab = 1
            }
        }
    }
}

#Preview {
    MainTabView()
}
