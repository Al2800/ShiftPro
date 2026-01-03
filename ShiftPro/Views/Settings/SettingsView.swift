import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var entitlementManager = EntitlementManager()
    @StateObject private var cloudKitManager = CloudKitManager()

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

    private var skippedSteps: [OnboardingStep] {
        OnboardingProgressStore.loadSkippedSteps()
    }

    var body: some View {
        List {
            if !skippedSteps.isEmpty {
                Section {
                    Button {
                        resumeOnboarding()
                    } label: {
                        HStack(spacing: ShiftProSpacing.medium) {
                            Image(systemName: "checkmark.circle.badge.questionmark")
                                .foregroundStyle(ShiftProColors.warning)
                            VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                                Text("Complete Setup")
                                    .font(ShiftProTypography.body)
                                    .foregroundStyle(ShiftProColors.ink)
                                Text(skippedStepsDescription)
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                        .padding(.vertical, ShiftProSpacing.extraExtraSmall)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.completeSetup")
                }
            }

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

            Section("Schedule") {
                NavigationLink {
                    if patterns.isEmpty {
                        PatternLibraryView()
                    } else {
                        DefaultPatternPickerView(patterns: patterns)
                    }
                } label: {
                    settingRow(icon: "calendar", title: "Default Pattern", detail: defaultPatternName)
                }
            }

            Section("Integrations & Notifications") {
                NavigationLink {
                    CalendarSettingsView()
                } label: {
                    settingRow(icon: "calendar.badge.clock", title: "Calendar Settings", detail: "Sync & permissions")
                }

                NavigationLink {
                    ICloudSyncStatusView(manager: cloudKitManager)
                } label: {
                    settingRow(icon: "icloud", title: "iCloud Sync", detail: iCloudStatusDetail)
                }

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    settingRow(icon: "bell", title: "Notifications", detail: "Schedule & alerts")
                }
            }

            Section("Security & Privacy") {
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

            Section("Plan") {
                NavigationLink {
                    if entitlementManager.state.tier == .free {
                        PremiumView()
                    } else {
                        SubscriptionSettingsView()
                    }
                } label: {
                    settingRow(
                        icon: "star.circle",
                        title: premiumRowTitle,
                        detail: premiumRowDetail
                    )
                }
                .accessibilityIdentifier("settings.plan")
            }

        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .task {
            await cloudKitManager.refreshStatus()
            cloudKitManager.startMonitoringAccountChanges()
        }
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

    private var iCloudStatusDetail: String {
        switch cloudKitManager.status {
        case .available:
            return "Connected"
        case .noAccount:
            return "Not signed in"
        case .restricted:
            return "Restricted"
        case .temporarilyUnavailable:
            return "Temporarily unavailable"
        case .couldNotDetermine:
            return "Checking..."
        }
    }

    private var premiumRowTitle: String {
        switch entitlementManager.state.tier {
        case .free:
            return "Go Premium"
        case .premium:
            return "Premium"
        case .enterprise:
            return "Enterprise"
        }
    }

    private var premiumRowDetail: String {
        switch entitlementManager.state.tier {
        case .free:
            return "Unlock advanced features"
        case .premium, .enterprise:
            return "Manage subscription"
        }
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

    private var skippedStepsDescription: String {
        let count = skippedSteps.count
        if count == 1 {
            return "1 optional step remaining"
        }
        return "\(count) optional steps remaining"
    }

    private func resumeOnboarding() {
        // Prepare the onboarding manager to resume at skipped steps
        let manager = OnboardingManager()
        manager.resumeAtSkippedSteps()
        // Trigger onboarding view
        NotificationCenter.default.post(name: .resumeOnboarding, object: nil)
    }
}

// MARK: - iCloud Sync Status View

private struct ICloudSyncStatusView: View {
    @ObservedObject var manager: CloudKitManager

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: ShiftProSpacing.extraSmall) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                    Text(guidanceTitle)
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    Text(guidanceMessage)
                        .font(ShiftProTypography.body)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    if manager.status == .noAccount || manager.status == .restricted {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ShiftProColors.accent)
                    }

                    if manager.status == .temporarilyUnavailable || manager.status == .couldNotDetermine {
                        Button("Check Again") {
                            Task {
                                await manager.refreshStatus()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(ShiftProColors.accent)
                    }
                }
                .padding(.vertical, ShiftProSpacing.small)
            } header: {
                Text("Guidance")
            }

            Section {
                VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                    infoRow(icon: "arrow.triangle.2.circlepath", text: "Automatic backup of your shifts and patterns")
                    infoRow(icon: "iphone.and.ipad", text: "Sync across all your Apple devices")
                    infoRow(icon: "lock.shield", text: "Your data is encrypted end-to-end")
                }
            } header: {
                Text("About iCloud Sync")
            }
        }
        .navigationTitle("iCloud Sync")
        .refreshable {
            await manager.refreshStatus()
        }
    }

    private var statusColor: Color {
        switch manager.status {
        case .available:
            return ShiftProColors.success
        case .noAccount, .restricted:
            return ShiftProColors.warning
        case .temporarilyUnavailable, .couldNotDetermine:
            return ShiftProColors.inkSubtle
        }
    }

    private var statusText: String {
        switch manager.status {
        case .available:
            return "Connected"
        case .noAccount:
            return "Not signed in"
        case .restricted:
            return "Restricted"
        case .temporarilyUnavailable:
            return "Temporarily unavailable"
        case .couldNotDetermine:
            return "Checking..."
        }
    }

    private var guidanceTitle: String {
        switch manager.status {
        case .available:
            return "You're all set!"
        case .noAccount:
            return "Sign in to iCloud"
        case .restricted:
            return "iCloud is restricted"
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable"
        case .couldNotDetermine:
            return "Checking status..."
        }
    }

    private var guidanceMessage: String {
        switch manager.status {
        case .available:
            return """
                Your shifts and patterns are automatically synced to iCloud. \
                They'll appear on all your devices signed in with the same Apple ID.
                """
        case .noAccount:
            return "Sign in to your Apple ID in Settings to enable automatic backup and sync across your devices."
        case .restricted:
            return "iCloud access is restricted on this device. Check with your device administrator or parental controls settings."
        case .temporarilyUnavailable:
            return "iCloud services are temporarily unavailable. Please try again later."
        case .couldNotDetermine:
            return "We're checking your iCloud status. Please wait a moment."
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: ShiftProSpacing.medium) {
            Image(systemName: icon)
                .foregroundStyle(ShiftProColors.accent)
                .frame(width: 24)
            Text(text)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
    }
}

// MARK: - Default Pattern Picker

private struct DefaultPatternPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let patterns: [ShiftPattern]

    var body: some View {
        List {
            Section {
                ForEach(patterns, id: \.id) { pattern in
                    Button {
                        setAsDefault(pattern)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                                Text(pattern.name)
                                    .font(ShiftProTypography.body)
                                    .foregroundStyle(ShiftProColors.ink)
                                if let notes = pattern.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(ShiftProTypography.caption)
                                        .foregroundStyle(ShiftProColors.inkSubtle)
                                }
                            }
                            Spacer()
                            if isDefault(pattern) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ShiftProColors.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Your Patterns")
            } footer: {
                Text("The default pattern is used when creating new shifts.")
            }

            Section {
                NavigationLink {
                    PatternLibraryView()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(ShiftProColors.accent)
                        Text("Create from Template")
                            .foregroundStyle(ShiftProColors.accent)
                    }
                }
            }
        }
        .navigationTitle("Default Pattern")
    }

    private func isDefault(_ pattern: ShiftPattern) -> Bool {
        patterns.first?.id == pattern.id
    }

    private func setAsDefault(_ pattern: ShiftPattern) {
        // Move pattern to beginning by updating createdAt
        // This ensures it appears as the "first" pattern
        pattern.createdAt = Date()
        pattern.markUpdated()
        try? context.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
