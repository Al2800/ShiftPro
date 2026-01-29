import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @StateObject private var cloudKitManager = CloudKitManager()
    @AppStorage("appearanceMode") private var appearanceMode: Int = AppearanceMode.dark.rawValue

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
        ZStack {
            // Premium animated background
            AnimatedMeshBackground()

            ScrollView {
                VStack(spacing: ShiftProSpacing.large) {
                    // Header
                    premiumHeader
                        .padding(.top, ShiftProSpacing.medium)

                    // Profile Card
                    if let profile = profile {
                        premiumProfileSection(profile: profile)
                    } else {
                        setupProfileCard
                    }

                    // Appearance section
                    PremiumSettingsSection(title: "Appearance", icon: "paintbrush") {
                        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                            Text("Theme")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)

                            HStack(spacing: ShiftProSpacing.small) {
                                ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                                    Button {
                                        appearanceMode = mode.rawValue
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: mode == .system ? "circle.lefthalf.filled" : (mode == .light ? "sun.max.fill" : "moon.fill"))
                                                .font(.system(size: 20))
                                            Text(mode.displayName)
                                                .font(ShiftProTypography.caption)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, ShiftProSpacing.small)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(appearanceMode == mode.rawValue ? ShiftProColors.accent : ShiftProColors.surface)
                                        )
                                        .foregroundStyle(appearanceMode == mode.rawValue ? .white : ShiftProColors.ink)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, ShiftProSpacing.medium)
                        .padding(.vertical, ShiftProSpacing.small)
                    }

                    // Setup reminder
                    if !skippedSteps.isEmpty {
                        setupReminderCard
                    }

                    // Schedule section
                    PremiumSettingsSection(title: "Schedule", icon: "calendar") {
                        NavigationLink {
                            if patterns.isEmpty {
                                PatternLibraryView()
                            } else {
                                DefaultPatternPickerView(patterns: patterns)
                            }
                        } label: {
                            PremiumSettingsRow(
                                icon: "calendar.badge.clock",
                                title: "Default Pattern",
                                detail: defaultPatternName,
                                iconColor: ShiftProColors.accent
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Integrations section
                    PremiumSettingsSection(title: "Integrations", icon: "link") {
                        NavigationLink {
                            CalendarSettingsView()
                        } label: {
                            PremiumSettingsRow(
                                icon: "calendar.badge.plus",
                                title: "Calendar Settings",
                                detail: "Sync & permissions",
                                iconColor: ShiftProColors.success
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        SettingsDivider()

                        NavigationLink {
                            ICloudSyncStatusView(manager: cloudKitManager)
                        } label: {
                            PremiumSettingsRow(
                                icon: "icloud",
                                title: "iCloud Sync",
                                detail: iCloudStatusDetail,
                                iconColor: Color.blue
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        SettingsDivider()

                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            PremiumSettingsRow(
                                icon: "bell.badge",
                                title: "Notifications",
                                detail: "Schedule & alerts",
                                iconColor: ShiftProColors.warning
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Security section
                    PremiumSettingsSection(title: "Security & Privacy", icon: "lock.shield") {
                        NavigationLink {
                            SecuritySettingsView()
                        } label: {
                            PremiumSettingsRow(
                                icon: "faceid",
                                title: "Security",
                                detail: "PIN & Face ID",
                                iconColor: ShiftProColors.success
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier(AccessibilityIdentifiers.settingsSecurity)

                        SettingsDivider()

                        NavigationLink {
                            PrivacySettingsView()
                        } label: {
                            PremiumSettingsRow(
                                icon: "hand.raised.fill",
                                title: "Privacy",
                                detail: "Data & permissions",
                                iconColor: Color.purple
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier(AccessibilityIdentifiers.settingsPrivacy)
                    }

                    // Data section
                    PremiumSettingsSection(title: "Data & Reports", icon: "chart.bar.doc.horizontal") {
                        NavigationLink {
                            AnalyticsDashboard()
                        } label: {
                            PremiumSettingsRow(
                                icon: "chart.bar.xaxis",
                                title: "Analytics",
                                detail: "Insights & trends",
                                iconColor: Color.orange
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        SettingsDivider()

                        NavigationLink {
                            ExportOptionsView(period: currentPeriod, shifts: currentPeriodShifts)
                        } label: {
                            PremiumSettingsRow(
                                icon: "square.and.arrow.up",
                                title: "Export Data",
                                detail: "Share reports",
                                iconColor: ShiftProColors.accent
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        SettingsDivider()

                        NavigationLink {
                            ImportView()
                        } label: {
                            PremiumSettingsRow(
                                icon: "square.and.arrow.down",
                                title: "Import Data",
                                detail: "Restore backups",
                                iconColor: Color.teal
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Plan section
                    PremiumSettingsSection(title: "Plan", icon: "star.circle") {
                        NavigationLink {
                            if entitlementManager.state.tier == .free {
                                PremiumView()
                            } else {
                                SubscriptionSettingsView()
                            }
                        } label: {
                            PremiumSettingsRow(
                                icon: planIcon,
                                title: premiumRowTitle,
                                detail: premiumRowDetail,
                                iconColor: planIconColor,
                                badge: entitlementManager.state.tier == .premium ? "PRO" : nil,
                                badgeColor: ShiftProColors.accent
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("settings.plan")
                    }

                    // App info footer
                    appInfoFooter
                        .padding(.top, ShiftProSpacing.medium)
                        .padding(.bottom, 100) // Extra padding for tab bar
                }
                .padding(.horizontal, ShiftProSpacing.medium)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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

    // MARK: - Premium Header

    private var premiumHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(ShiftProColors.ink)

                Text("Manage your preferences")
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            Spacer()

            // Settings icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ShiftProColors.accent.opacity(0.2),
                                ShiftProColors.accent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ShiftProColors.accent)
            }
        }
        .padding(.horizontal, ShiftProSpacing.small)
    }

    // MARK: - Profile Section

    private func premiumProfileSection(profile: UserProfile) -> some View {
        NavigationLink {
            ProfileDetailView(profile: profile)
        } label: {
            PremiumProfileHeader(
                name: profile.displayName,
                subtitle: profile.workplace ?? profile.jobTitle ?? "Tap to edit profile",
                avatarIcon: "person.crop.circle.fill"
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var setupProfileCard: some View {
        Button {
            createProfileAndEdit()
        } label: {
            HStack(spacing: ShiftProSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ShiftProColors.accent.opacity(0.2),
                                    ShiftProColors.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(ShiftProColors.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Up Profile")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ShiftProColors.ink)

                    Text("Add workplace and pay details")
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ShiftProColors.inkSubtle.opacity(0.5))
            }
            .padding(ShiftProSpacing.medium)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(ShiftProColors.surface)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ShiftProColors.accent.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .scalePress(0.98)
    }

    // MARK: - Setup Reminder

    private var setupReminderCard: some View {
        Button {
            resumeOnboarding()
        } label: {
            HStack(spacing: ShiftProSpacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ShiftProColors.warning.opacity(0.2),
                                    ShiftProColors.warning.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "checkmark.circle.badge.questionmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ShiftProColors.warning)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Complete Setup")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    Text(skippedStepsDescription)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ShiftProColors.inkSubtle.opacity(0.5))
            }
            .padding(ShiftProSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ShiftProColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(ShiftProColors.warning.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: ShiftProColors.warning.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .scalePress(0.98)
        .accessibilityIdentifier("settings.completeSetup")
    }

    // MARK: - App Info Footer

    private var appInfoFooter: some View {
        VStack(spacing: ShiftProSpacing.small) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ShiftProColors.accent, ShiftProColors.accent.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("ShiftPro")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(ShiftProColors.ink)

            Text("Version 1.0.0")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)

            Text("Made with care for shift workers")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle.opacity(0.7))
        }
        .padding(.vertical, ShiftProSpacing.large)
    }

    // MARK: - Computed Properties

    private var profile: UserProfile? {
        profiles.first
    }

    private var defaultPatternName: String {
        patterns.first?.displaySummary ?? "Not set"
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
        case .unavailable:
            return "Unavailable"
        }
    }

    private var planIcon: String {
        switch entitlementManager.state.tier {
        case .free:
            return "star.circle"
        case .premium:
            return "star.circle.fill"
        case .enterprise:
            return "building.2.crop.circle.fill"
        }
    }

    private var planIconColor: Color {
        switch entitlementManager.state.tier {
        case .free:
            return Color.gray
        case .premium:
            return Color(red: 0.85, green: 0.65, blue: 0.25)
        case .enterprise:
            return Color.purple
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

    private var skippedStepsDescription: String {
        let count = skippedSteps.count
        if count == 1 {
            return "1 optional step remaining"
        }
        return "\(count) optional steps remaining"
    }

    private func resumeOnboarding() {
        let manager = OnboardingManager()
        manager.resumeAtSkippedSteps()
        NotificationCenter.default.post(name: .resumeOnboarding, object: nil)
    }
}

// MARK: - iCloud Sync Status View

private struct ICloudSyncStatusView: View {
    @ObservedObject var manager: CloudKitManager

    var body: some View {
        ZStack {
            AnimatedMeshBackground()

            ScrollView {
                VStack(spacing: ShiftProSpacing.large) {
                    // Status card
                    VStack(spacing: ShiftProSpacing.medium) {
                        HStack {
                            Text("Status")
                                .font(ShiftProTypography.headline)
                                .foregroundStyle(ShiftProColors.ink)
                            Spacer()
                            HStack(spacing: ShiftProSpacing.extraSmall) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 10, height: 10)
                                Text(statusText)
                                    .font(ShiftProTypography.body)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                            }
                        }
                    }
                    .padding(ShiftProSpacing.medium)
                    .depthCard(cornerRadius: 20, elevation: 8)

                    // Guidance card
                    VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                        Text(guidanceTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(ShiftProColors.ink)

                        Text(guidanceMessage)
                            .font(ShiftProTypography.body)
                            .foregroundStyle(ShiftProColors.inkSubtle)

                        if manager.status == .noAccount || manager.status == .restricted {
                            PremiumButton(title: "Open Settings", icon: "gear", style: .primary) {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }

                        if manager.status == .temporarilyUnavailable || manager.status == .couldNotDetermine {
                            PremiumButton(title: "Check Again", icon: "arrow.clockwise", style: .secondary) {
                                Task {
                                    await manager.refreshStatus()
                                }
                            }
                        }
                    }
                    .padding(ShiftProSpacing.large)
                    .depthCard(cornerRadius: 24, elevation: 12)

                    // Info section
                    VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                        Text("About iCloud Sync")
                            .font(ShiftProTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                            infoRow(icon: "arrow.triangle.2.circlepath", text: "Automatic backup of your shifts and patterns")
                            infoRow(icon: "iphone.and.ipad", text: "Sync across all your Apple devices")
                            infoRow(icon: "lock.shield", text: "Your data is encrypted end-to-end")
                        }
                        .padding(ShiftProSpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(ShiftProColors.surface)
                        )
                    }
                }
                .padding(ShiftProSpacing.medium)
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
        case .unavailable:
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
        case .unavailable:
            return "Unavailable"
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
        case .unavailable:
            return "iCloud is unavailable"
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
        case .unavailable:
            return "iCloud sync isn't configured for this build of ShiftPro."
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: ShiftProSpacing.medium) {
            Image(systemName: icon)
                .foregroundStyle(ShiftProColors.accent)
                .frame(width: 24)
            Text(text)
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
    }
}

// MARK: - Default Pattern Picker

private struct DefaultPatternPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let patterns: [ShiftPattern]

    @State private var patternToExtend: ShiftPattern?
    @State private var showingExtendSheet = false
    @State private var extensionMonths = 12
    @State private var isExtending = false
    @State private var showExtendSuccess = false
    @State private var patternToDelete: ShiftPattern?
    @State private var showDeleteConfirmation = false

    private let engine = PatternEngine()

    var body: some View {
        ZStack {
            AnimatedMeshBackground()

            ScrollView {
                VStack(spacing: ShiftProSpacing.large) {
                    PremiumSettingsSection(title: "Your Patterns", icon: "calendar.badge.clock") {
                        ForEach(Array(patterns.enumerated()), id: \.element.id) { index, pattern in
                            if index > 0 {
                                SettingsDivider()
                            }

                            HStack {
                                let summary = pattern.displaySummary
                                Button {
                                    setAsDefault(pattern)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(pattern.name)
                                                .font(ShiftProTypography.body)
                                                .foregroundStyle(ShiftProColors.ink)

                                            if summary != pattern.name {
                                                Text(summary)
                                                    .font(ShiftProTypography.caption)
                                                    .foregroundStyle(ShiftProColors.inkSubtle)
                                            }

                                            if let notes = pattern.notes, !notes.isEmpty {
                                                Text(notes)
                                                    .font(ShiftProTypography.caption)
                                                    .foregroundStyle(ShiftProColors.inkSubtle)
                                            }
                                        }
                                        Spacer()
                                        if isDefault(pattern) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(ShiftProColors.accent)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Extend button
                                Button {
                                    patternToExtend = pattern
                                    showingExtendSheet = true
                                } label: {
                                    Image(systemName: "arrow.forward.to.line")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(ShiftProColors.accent)
                                        .padding(10)
                                        .background(ShiftProColors.accent.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(role: .destructive) {
                                    patternToDelete = pattern
                                    showDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(ShiftProColors.danger)
                                        .padding(10)
                                        .background(ShiftProColors.danger.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, ShiftProSpacing.medium)
                            .padding(.vertical, ShiftProSpacing.small)
                        }
                    }

                    // Add pattern
                    NavigationLink {
                        PatternLibraryView()
                    } label: {
                        HStack(spacing: ShiftProSpacing.medium) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                ShiftProColors.accent.opacity(0.2),
                                                ShiftProColors.accent.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)

                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(ShiftProColors.accent)
                            }

                            Text("Create from Template")
                                .font(ShiftProTypography.body)
                                .foregroundStyle(ShiftProColors.accent)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ShiftProColors.inkSubtle.opacity(0.5))
                        }
                        .padding(ShiftProSpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(ShiftProColors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("The default pattern is used when creating new shifts.")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ShiftProSpacing.large)
                }
                .padding(ShiftProSpacing.medium)
            }
        }
        .navigationTitle("Default Pattern")
        .sheet(isPresented: $showingExtendSheet) {
            if let pattern = patternToExtend {
                ExtendPatternSheet(
                    pattern: pattern,
                    months: $extensionMonths,
                    isExtending: $isExtending,
                    onExtend: {
                        extendPattern(pattern)
                    }
                )
            }
        }
        .confirmationDialog("Delete Pattern?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Pattern", role: .destructive) {
                if let pattern = patternToDelete {
                    deletePattern(pattern)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The pattern will be removed from your list. Existing shifts will remain unchanged.")
        }
        .alert("Pattern Extended!", isPresented: $showExtendSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Shifts have been scheduled for the next \(extensionMonthsLabel).")
        }
    }

    private var extensionMonthsLabel: String {
        switch extensionMonths {
        case 12: return "year"
        case 24: return "2 years"
        default: return "\(extensionMonths) months"
        }
    }

    private func isDefault(_ pattern: ShiftPattern) -> Bool {
        patterns.first?.id == pattern.id
    }

    private func setAsDefault(_ pattern: ShiftPattern) {
        pattern.createdAt = Date()
        try? context.save()
        dismiss()
    }

    private func extendPattern(_ pattern: ShiftPattern) {
        isExtending = true

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .month, value: extensionMonths, to: today) ?? today

        // Generate new shifts from today to the extension date
        let newShifts = engine.generateShifts(for: pattern, from: today, to: endDate, owner: nil)

        for shift in newShifts {
            context.insert(shift)
        }

        do {
            try context.save()
            isExtending = false
            showingExtendSheet = false
            showExtendSuccess = true
        } catch {
            isExtending = false
        }
    }

    private func deletePattern(_ pattern: ShiftPattern) {
        let repository = PatternRepository(context: context)
        try? repository.softDelete(pattern)
        if patterns.count <= 1 {
            dismiss()
        }
    }
}

// MARK: - Extend Pattern Sheet

private struct ExtendPatternSheet: View {
    let pattern: ShiftPattern
    @Binding var months: Int
    @Binding var isExtending: Bool
    let onExtend: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: ShiftProSpacing.large) {
                // Header
                VStack(spacing: ShiftProSpacing.small) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(ShiftProColors.accent)

                    Text("Extend Pattern")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(ShiftProColors.ink)

                    Text("Generate more shifts for '\(pattern.name)'")
                        .font(ShiftProTypography.subheadline)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, ShiftProSpacing.large)

                // Duration picker
                VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                    Text("Extend by")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ShiftProSpacing.small) {
                        ForEach([3, 6, 12, 24], id: \.self) { duration in
                            let isSelected = months == duration
                            let label = duration == 12 ? "1 Year" : duration == 24 ? "2 Years" : "\(duration) Months"

                            Button {
                                months = duration
                            } label: {
                                Text(label)
                                    .font(ShiftProTypography.body)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, ShiftProSpacing.medium)
                                    .background(isSelected ? ShiftProColors.accent : ShiftProColors.surface)
                                    .foregroundStyle(isSelected ? .white : ShiftProColors.ink)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(isSelected ? ShiftProColors.accent : ShiftProColors.divider, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, ShiftProSpacing.medium)

                Spacer()

                // Extend button
                Button {
                    onExtend()
                } label: {
                    HStack(spacing: 8) {
                        if isExtending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.forward.to.line")
                        }
                        Text(isExtending ? "Extending..." : "Extend Pattern")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ShiftProSpacing.medium)
                    .background(ShiftProColors.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isExtending)
                .padding(.horizontal, ShiftProSpacing.medium)
                .padding(.bottom, ShiftProSpacing.large)
            }
            .background(ShiftProColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
