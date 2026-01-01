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

    enum ExportCategory: CaseIterable, Hashable {
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
            ZStack {
                Form {
                    // Category Selection
                    Section {
                    Picker("Export Type", selection: $selectedCategory) {
                        ForEach(ExportCategory.allCases, id: \.self) { category in
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
                    ForEach([ExportManager.ExportFormat.csv, .pdf], id: \.self) { format in
                        formatRow(format)
                    }
                } header: {
                    Text("File Format")
                } footer: {
                    Text(formatDescription)
                        .font(ShiftProTypography.caption)
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
                        HStack(spacing: ShiftProSpacing.small) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ShiftProColors.danger)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Export Failed")
                                    .font(ShiftProTypography.body)
                                    .foregroundStyle(ShiftProColors.danger)
                                Text(errorMessage)
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                            }
                        }

                        Button("Try Again") {
                            self.errorMessage = nil
                            performExport()
                        }
                        .foregroundStyle(ShiftProColors.accent)
                    }
                }
                }

                // Progress Overlay
                if isExporting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: ShiftProSpacing.medium) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Generating Export...")
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(.white)

                        Text("This may take a moment")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(ShiftProSpacing.extraLarge)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ShiftProColors.midnight.opacity(0.9))
                    )
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

    // MARK: - Format Row

    private func formatRow(_ format: ExportManager.ExportFormat) -> some View {
        let isPremiumLocked = format == .pdf && !entitlementManager.hasAccess(to: .fullExport)
        let isSelected = selectedFormat == format

        return Button {
            if isPremiumLocked {
                showPaywall = true
            } else {
                selectedFormat = format
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: ShiftProSpacing.small) {
                        Text(format == .csv ? "CSV (Spreadsheet)" : "PDF (Document)")
                            .font(ShiftProTypography.body)
                            .foregroundStyle(isPremiumLocked ? ShiftProColors.inkSubtle : ShiftProColors.ink)

                        if isPremiumLocked {
                            Text("PREMIUM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(ShiftProColors.accent)
                                )
                        }
                    }

                    Text(format == .csv
                         ? "Excel, Google Sheets compatible"
                         : "Professional document format")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }

                Spacer()

                if isSelected && !isPremiumLocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ShiftProColors.accent)
                } else if isPremiumLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(ShiftProColors.inkSubtle)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
            }
            .padding(.vertical, ShiftProSpacing.extraSmall)
        }
        .buttonStyle(.plain)
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

// MARK: - Preview

#Preview {
    ExportOptionsView(period: PayPeriod.currentWeek())
        .modelContainer(for: [PayPeriod.self])
        .environmentObject(EntitlementManager())
}
