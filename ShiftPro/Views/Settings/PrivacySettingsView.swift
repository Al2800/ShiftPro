import SwiftData
import SwiftUI

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var privacyManager = PrivacyManager()

    @State private var showAuditTrail = false
    @State private var showDeleteConfirmation = false
    @State private var showExportPicker = false
    @State private var showError = false
    @State private var showDeletionSuccess = false
    @State private var errorMessage = ""
    @State private var exportURL: URL?
    @State private var isDeleting = false

    var body: some View {
        Form {
            privacyControlsSection
            auditTrailSection
            dataManagementSection
            complianceSection
        }
        .navigationTitle("Privacy")
        .sheet(isPresented: $showAuditTrail) {
            AuditTrailView(privacyManager: privacyManager)
        }
        .sheet(isPresented: $showExportPicker) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Delete All Data", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete All Data", role: .destructive) {
                handleDeleteAllData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all your shift data, settings, and privacy information. This action cannot be undone.")
        }
        .alert("Data Deleted", isPresented: $showDeletionSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("All your data has been permanently deleted. The app will now return to setup.")
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: ShiftProSpacing.medium) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Deleting all data...")
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(ShiftProSpacing.large)
                    .background(ShiftProColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var privacyControlsSection: some View {
        Section {
            ForEach(PrivacyManager.PrivacyOption.allCases, id: \.self) { option in
                Toggle(isOn: Binding(
                    get: { privacyManager.isEnabled(option) },
                    set: { enabled in
                        handleToggle(option, enabled: enabled)
                    }
                )) {
                    VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                        Text(option.displayName)
                            .font(ShiftProTypography.body)
                        Text(option.description)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            }
        } header: {
            Text("Privacy Controls")
        } footer: {
            Text("Control how your data is used and shared")
                .font(ShiftProTypography.caption)
        }
    }

    private var auditTrailSection: some View {
        Section {
            Button {
                showAuditTrail = true
            } label: {
                HStack {
                    Text("View Audit Trail")
                        .font(ShiftProTypography.body)
                    Spacer()
                    Text("\(privacyManager.auditTrail.count) events")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
            }
            .foregroundStyle(ShiftProColors.ink)

            Button {
                exportAuditTrail()
            } label: {
                Text("Export Audit Trail")
                    .font(ShiftProTypography.body)
            }
        } header: {
            Text("Security Audit Trail")
        } footer: {
            Text("Track all security and privacy-related events for compliance")
                .font(ShiftProTypography.caption)
        }
    }

    private var dataManagementSection: some View {
        Section {
            Button {
                exportPrivacyReport()
            } label: {
                Text("Export Privacy Report")
                    .font(ShiftProTypography.body)
            }

            Button {
                exportAllData()
            } label: {
                Text("Export All Data")
                    .font(ShiftProTypography.body)
            }
        } header: {
            Text("Data Portability")
        } footer: {
            Text("Export your data in machine-readable format (GDPR Article 20)")
                .font(ShiftProTypography.caption)
        }
    }

    private var complianceSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Text("Delete All Data")
                    .font(ShiftProTypography.body)
            }
        } header: {
            Text("Right to Erasure (GDPR/CCPA)")
        } footer: {
            Text("Permanently delete all your data from ShiftPro. This action cannot be undone.")
                .font(ShiftProTypography.caption)
        }
    }

    // MARK: - Actions

    private func handleToggle(_ option: PrivacyManager.PrivacyOption, enabled: Bool) {
        do {
            try privacyManager.setEnabled(option, enabled: enabled)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func exportAuditTrail() {
        do {
            let data = try privacyManager.exportAuditTrail()
            let filename = "shiftpro-audit-\(Date.now.ISO8601Format()).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)

            exportURL = tempURL
            showExportPicker = true

            try privacyManager.logAudit(type: .dataExport, description: "Exported audit trail")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func exportPrivacyReport() {
        do {
            let data = try privacyManager.exportPrivacyReport()
            let filename = "shiftpro-privacy-report-\(Date.now.ISO8601Format()).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)

            exportURL = tempURL
            showExportPicker = true

            try privacyManager.logAudit(type: .dataExport, description: "Exported privacy report")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func exportAllData() {
        do {
            let exportManager = ExportManager(context: modelContext)
            let fileURL = try exportManager.export(category: .fullBackup, format: .json)

            exportURL = fileURL
            showExportPicker = true

            try privacyManager.logAudit(type: .dataExport, description: "Exported full data backup (GDPR portability)")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleDeleteAllData() {
        isDeleting = true

        Task {
            do {
                // Perform comprehensive data deletion (SwiftData, UserDefaults, Keychain, caches)
                _ = try await DataDeletionService.deleteAllData(modelContext: modelContext)

                // Clear privacy manager data as final step (also logs the deletion event)
                try privacyManager.deleteAllUserData()

                await MainActor.run {
                    isDeleting = false
                    showDeletionSuccess = true
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Audit Trail View

struct AuditTrailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var privacyManager: PrivacyManager

    @State private var selectedFilter: PrivacyManager.AuditEventType?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $selectedFilter) {
                        Text("All Events").tag(nil as PrivacyManager.AuditEventType?)
                        ForEach([
                            PrivacyManager.AuditEventType.authenticationAttempt,
                            .dataExport,
                            .dataImport,
                            .privacySettingChanged,
                            .securitySettingChanged
                        ], id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type as PrivacyManager.AuditEventType?)
                        }
                    }
                    .font(ShiftProTypography.body)
                }

                Section {
                    ForEach(filteredEntries) { entry in
                        AuditEntryRow(entry: entry)
                    }
                } header: {
                    Text("\(filteredEntries.count) Events")
                }
            }
            .navigationTitle("Audit Trail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredEntries: [PrivacyManager.AuditEntry] {
        if let filter = selectedFilter {
            return privacyManager.getAuditTrail(type: filter)
        }
        return privacyManager.auditTrail
    }
}

struct AuditEntryRow: View {
    let entry: PrivacyManager.AuditEntry

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
            HStack {
                Text(entry.eventType.rawValue.capitalized)
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(ShiftProColors.ink)
                Spacer()
                Text(entry.timestamp, style: .relative)
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            Text(entry.description)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)

            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
        .padding(.vertical, ShiftProSpacing.extraExtraSmall)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
