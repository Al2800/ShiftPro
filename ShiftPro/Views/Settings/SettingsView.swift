import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    @Query(
        filter: #Predicate<ShiftPattern> { $0.deletedAt == nil && $0.isActive },
        sort: [SortDescriptor(\ShiftPattern.createdAt, order: .forward)]
    )
    private var patterns: [ShiftPattern]

    @Query(filter: #Predicate<PayPeriod> { $0.deletedAt == nil }, sort: [SortDescriptor(\PayPeriod.startDate, order: .reverse)])
    private var payPeriods: [PayPeriod]

    @Query(filter: #Predicate<Shift> { $0.deletedAt == nil }, sort: [SortDescriptor(\Shift.scheduledStart, order: .forward)])
    private var shifts: [Shift]

    private let calculator = PayPeriodCalculator()

    @State private var showProfileEditor = false
    @State private var draftProfile: UserProfile?

    var body: some View {
        List {
            Section("Profile") {
                if let profile = profile {
                    NavigationLink {
                        ProfileDetailView(profile: profile)
                    } label: {
                        settingRow(icon: "person.crop.circle", title: "My Profile", detail: profile.displayName)
                    }

                    settingRow(icon: "briefcase", title: "Workplace", detail: profile.workplace ?? "Not set")
                    settingRow(icon: "person.text.rectangle", title: "Role", detail: profile.jobTitle ?? "Not set")
                    settingRow(icon: "number", title: "Employee ID", detail: profile.employeeId ?? "Not set")
                } else {
                    Button {
                        createProfileAndEdit()
                    } label: {
                        settingRow(icon: "person.crop.circle.badge.plus", title: "Set Up Profile", detail: "Add workplace and pay details")
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Preferences") {
                settingRow(icon: "calendar", title: "Default Pattern", detail: defaultPatternName)
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    settingRow(icon: "bell", title: "Notifications", detail: "Schedule & alerts")
                }
            }

            Section("Account") {
                settingRow(icon: "icloud", title: "iCloud Sync", detail: "Not connected")

                NavigationLink {
                    SecuritySettingsView()
                } label: {
                    settingRow(icon: "lock.shield", title: "Security", detail: "PIN & Face ID")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsSecurity)

                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    settingRow(icon: "hand.raised", title: "Privacy", detail: "Data & permissions")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsPrivacy)
            }

            Section("Subscription") {
                NavigationLink {
                    SubscriptionSettingsView()
                } label: {
                    settingRow(icon: "star.circle", title: "Subscription", detail: "Manage plan")
                }
                .accessibilityIdentifier("settings.subscription")
            }

            Section("Integrations") {
                NavigationLink {
                    CalendarSettingsView()
                } label: {
                    settingRow(icon: "calendar.badge.clock", title: "Calendar Settings", detail: "Sync & permissions")
                }
            }

            Section("Data & Reports") {
                NavigationLink {
                    AnalyticsDashboard()
                } label: {
                    settingRow(icon: "chart.bar.xaxis", title: "Analytics", detail: "Insights & trends")
                }

                NavigationLink {
                    ExportOptionsView(period: currentPeriod, shifts: currentPeriodShifts)
                } label: {
                    settingRow(icon: "square.and.arrow.up", title: "Export Data", detail: "Share reports")
                }

                NavigationLink {
                    ImportView()
                } label: {
                    settingRow(icon: "square.and.arrow.down", title: "Import Data", detail: "Restore backups")
                }
            }

            Section("Premium") {
                NavigationLink {
                    PremiumView()
                } label: {
                    settingRow(icon: "star.circle", title: "ShiftPro Premium", detail: "Unlock advanced features")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showProfileEditor) {
            if let profile = draftProfile {
                NavigationStack {
                    ProfileDetailView(profile: profile)
                }
            }
        }
    }

    private var profile: UserProfile? {
        profiles.first
    }

    private var defaultPatternName: String {
        patterns.first?.name ?? "Not set"
    }

    private var currentPeriod: PayPeriod {
        if let stored = payPeriods.first(where: { $0.isCurrent }) {
            return stored
        }
        return calculator.period(for: Date(), type: profile?.payPeriodType ?? .biweekly, referenceDate: profile?.startDate)
    }

    private var currentPeriodShifts: [Shift] {
        calculator.shifts(in: currentPeriod, from: shifts)
    }

    private func createProfileAndEdit() {
        let profile = UserProfile()
        context.insert(profile)
        draftProfile = profile
        showProfileEditor = true
    }

    private func settingRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: ShiftProSpacing.medium) {
            Image(systemName: icon)
                .foregroundStyle(ShiftProColors.accent)
            VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                Text(title)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.ink)
                Text(detail)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }
        }
        .padding(.vertical, ShiftProSpacing.extraExtraSmall)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
