import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export options and configuration interface
struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var entitlementManager: EntitlementManager

    let period: PayPeriod

    @State private var selectedFormat: ExportManager.ExportFormat = .csv
    @State private var selectedCategory: ExportCategory = .hoursSummary
    @State private var usePassword: Bool = false
    @State private var password: String = ""
    @State private var isExporting: Bool = false
    @State private var exportedFileURL: URL?
    @State private var showShareSheet: Bool = false
    @State private var errorMessage: String?
    @State private var showPaywall: Bool = false

    enum ExportCategory {
        case shiftReport
        case hoursSummary
        case payrollReport

        var displayName: String {
            switch self {
            case .shiftReport: return "Shift Report"
            case .hoursSummary: return "Hours Summary"
            case .payrollReport: return "Payroll Report"
            }
        }

        var description: String {
            switch self {
            case .shiftReport:
                return "Detailed list of all shifts in the period"
            case .hoursSummary:
                return "Summary of hours and rate breakdown"
            case .payrollReport:
                return "Professional report for payroll submission"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Category Selection
                Section {
                    Picker("Export Type", selection: $selectedCategory) {
                        ForEach([ExportCategory.shiftReport, .hoursSummary, .payrollReport], id: \.self) { category in
                            VStack(alignment: .leading) {
                                Text(category.displayName)
                                    .font(ShiftProTypography.body)
                                Text(category.description)
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("What to Export")
                }

                // Format Selection
                Section {
                    Picker("Format", selection: $selectedFormat) {
                        Text("CSV (Spreadsheet)").tag(ExportManager.ExportFormat.csv)
                        Text("PDF (Document)").tag(ExportManager.ExportFormat.pdf)
                            .disabled(!entitlementManager.hasAccess(to: .fullExport))
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedFormat) { newValue in
                        if newValue == .pdf && !entitlementManager.hasAccess(to: .fullExport) {
                            selectedFormat = .csv
                            showPaywall = true
                        }
                    }
                } header: {
                    Text("File Format")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(formatDescription)
                            .font(ShiftProTypography.caption)

                        if !entitlementManager.hasAccess(to: .fullExport) {
                            Button("Upgrade to unlock PDF exports") {
                                showPaywall = true
                            }
                            .font(ShiftProTypography.caption)
                        }
                    }
                }

                // Security Options
                Section {
                    Toggle("Password Protect", isOn: $usePassword)

                    if usePassword {
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                    }
                } header: {
                    Text("Security")
                } footer: {
                    if usePassword {
                        Text("Export will be encrypted with AES-256")
                            .font(ShiftProTypography.caption)
                    }
                }

                // Period Info
                Section {
                    HStack {
                        Text("Period")
                        Spacer()
                        Text(period.dateRangeFormatted)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }

                    HStack {
                        Text("Total Hours")
                        Spacer()
                        Text(String(format: "%.1f", period.paidHours))
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }

                    HStack {
                        Text("Shifts")
                        Spacer()
                        Text("\(period.shiftCount)")
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                } header: {
                    Text("Period Information")
                }

                // Error Display
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(ShiftProColors.danger)
                            .font(ShiftProTypography.caption)
                    }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        performExport()
                    }
                    .fontWeight(.semibold)
                    .disabled(isExporting || (usePassword && password.isEmpty))
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showPaywall) {
                NavigationStack {
                    PaywallView()
                }
            }
        }
    }

    // MARK: - Export Logic

    private func performExport() {
        guard entitlementManager.hasAccess(to: .fullExport) || selectedFormat == .csv else {
            showPaywall = true
            return
        }

        isExporting = true
        errorMessage = nil

        Task {
            do {
                let exportManager = ExportManager(context: context)

                let category: ExportManager.ExportCategory
                switch selectedCategory {
                case .shiftReport:
                    category = .shiftReport(period)
                case .hoursSummary:
                    category = .hoursSummary(period)
                case .payrollReport:
                    category = .payrollReport(period)
                }

                let fileURL = try await exportManager.export(
                    category: category,
                    format: selectedFormat,
                    password: usePassword ? password : nil
                )

                await MainActor.run {
                    exportedFileURL = fileURL
                    showShareSheet = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }

    // MARK: - Helper Properties

    private var formatDescription: String {
        switch selectedFormat {
        case .csv:
            return "Compatible with Excel, Google Sheets, and other spreadsheet applications"
        case .pdf:
            return entitlementManager.hasAccess(to: .fullExport)
                ? "Professional document format for printing and archiving"
                : "Premium plan required for PDF exports"
        default:
            return ""
        }
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

// MARK: - Preview

#Preview {
    ExportOptionsView(period: PayPeriod.currentWeek())
        .modelContainer(for: [PayPeriod.self])
        .environmentObject(EntitlementManager())
}
