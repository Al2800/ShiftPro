import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.tabDashboard)
            .tabItem {
                Label("Dashboard", systemImage: "gauge")
            }

            NavigationStack {
                ScheduleView()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.tabSchedule)
            .tabItem {
                Label("Schedule", systemImage: "calendar")
            }

            NavigationStack {
                HoursView()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.tabHours)
            .tabItem {
                Label("Hours", systemImage: "clock")
            }

            NavigationStack {
                PatternLibraryView()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.tabPatterns)
            .tabItem {
                Label("Patterns", systemImage: "repeat")
            }

            NavigationStack {
                SettingsView()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.tabSettings)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(ShiftProColors.accent)
    }
}

#Preview {
    MainTabView()
}
