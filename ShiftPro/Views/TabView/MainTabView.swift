import SwiftUI

struct MainTabView: View {
    @AppStorage("showAddShiftAfterOnboarding") private var showAddShiftAfterOnboarding = false
    @State private var selectedTab = 0
    @State private var tabBarVisible = true

    private let tabs: [(icon: String, selectedIcon: String, title: String)] = [
        ("gauge", "gauge.with.needle.fill", "Dashboard"),
        ("calendar", "calendar", "Schedule"),
        ("clock", "clock.fill", "Hours"),
        ("gearshape", "gearshape.fill", "Settings")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView()
                }
                .tag(0)
                .accessibilityIdentifier(AccessibilityIdentifiers.tabDashboard)

                NavigationStack {
                    ScheduleView()
                }
                .tag(1)
                .accessibilityIdentifier(AccessibilityIdentifiers.tabSchedule)

                NavigationStack {
                    HoursView()
                }
                .tag(2)
                .accessibilityIdentifier(AccessibilityIdentifiers.tabHours)

                NavigationStack {
                    SettingsView()
                }
                .tag(3)
                .accessibilityIdentifier(AccessibilityIdentifiers.tabSettings)
            }
            .safeAreaInset(edge: .top) {
                ShiftStatusBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Custom tab bar
            if tabBarVisible {
                PremiumTabBar(
                    tabs: tabs,
                    selectedTab: $selectedTab
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Hide default tab bar
            UITabBar.appearance().isHidden = true

            // Navigate to Schedule tab if user chose to add their first shift after onboarding
            if showAddShiftAfterOnboarding {
                selectedTab = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToScheduleTab)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                tabBarVisible = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeIn(duration: 0.3)) {
                tabBarVisible = true
            }
        }
    }
}

// MARK: - Premium Tab Bar

private struct PremiumTabBar: View {
    let tabs: [(icon: String, selectedIcon: String, title: String)]
    @Binding var selectedTab: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                PremiumTabItem(
                    icon: selectedTab == index ? tab.selectedIcon : tab.icon,
                    title: tab.title,
                    isSelected: selectedTab == index
                ) {
                    if selectedTab != index {
                        if !reduceMotion {
                            HapticManager.fire(.impactLight, enabled: true)
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = index
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .background(
            ZStack {
                // Blurred background
                Rectangle()
                    .fill(.ultraThinMaterial)

                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.10).opacity(0.9),
                        Color(red: 0.03, green: 0.04, blue: 0.07).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Top border highlight
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.03),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1)
                    Spacer()
                }
            }
        )
    }
}

// MARK: - Tab Item

private struct PremiumTabItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        ShiftProColors.accent.opacity(0.2),
                                        ShiftProColors.accent.opacity(0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 48, height: 48)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 22 : 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected
                                ? ShiftProColors.accent
                                : ShiftProColors.inkSubtle.opacity(0.7)
                        )
                        .frame(width: 48, height: 48)
                }

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected
                            ? ShiftProColors.accent
                            : ShiftProColors.inkSubtle.opacity(0.7)
                    )
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

#Preview {
    MainTabView()
}
