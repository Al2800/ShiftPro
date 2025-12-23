import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Data import interface
struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    @State private var selectedFormat: ImportManager.ImportFormat = .csv
    @State private var showFilePicker: Bool = false
    @State private var isImporting: Bool = false
    @State private var importResult: ImportManager.ImportResult?
    @State private var errorMessage: String?

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            Form {
                // Format Selection
                Section {
                    Picker("File Format", selection: $selectedFormat) {
                        Text("CSV").tag(ImportManager.ImportFormat.csv)
                        Text("JSON (Backup)").tag(ImportManager.ImportFormat.json)
                        Text("ICS (Calendar)").tag(ImportManager.ImportFormat.ics)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Import Format")
                } footer: {
                    Text(formatDescription)
                        .font(ShiftProTypography.caption)
                }

                // Import Button
                Section {
                    Button {
                        showFilePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Select File to Import")
                        }
                    }
                    .disabled(isImporting)
                } header: {
                    Text("Import Data")
                }

                // Result Display
                if let result = importResult {
                    Section {
                        Label("\(result.importedShifts) shifts imported", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(ShiftProColors.success)

                        if result.importedPatterns > 0 {
                            Label("\(result.importedPatterns) patterns imported", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(ShiftProColors.success)
                        }

                        if !result.errors.isEmpty {
                            Label("\(result.errors.count) errors", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(ShiftProColors.warning)

                            ForEach(result.errors.prefix(5), id: \.self) { error in
                                Text(error)
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                            }

                            if result.errors.count > 5 {
                                Text("... and \(result.errors.count - 5) more")
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                            }
                        }
                    } header: {
                        Text("Import Results")
                    }
                }

                // Error Display
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(ShiftProColors.danger)
                            .font(ShiftProTypography.caption)
                    } header: {
                        Text("Error")
                    }
                }

                // Instructions
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        instructionRow(icon: "1.circle.fill", text: "Select the file format you're importing")
                        instructionRow(icon: "2.circle.fill", text: "Tap 'Select File to Import' and choose your file")
                        instructionRow(icon: "3.circle.fill", text: "Review the import results")
                        instructionRow(icon: "checkmark.circle.fill", text: "Data will be added to your existing shifts")
                    }
                } header: {
                    Text("How to Import")
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: allowedFileTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    // MARK: - Helper Views

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(ShiftProColors.accent)
                .font(.system(size: 16))

            Text(text)
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.ink)
        }
    }

    // MARK: - Import Logic

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            performImport(from: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func performImport(from url: URL) {
        isImporting = true
        errorMessage = nil
        importResult = nil

        Task {
            do {
                let importManager = ImportManager(context: context)
                let result = try await importManager.importData(
                    from: url,
                    format: selectedFormat,
                    profile: profile
                )

                await MainActor.run {
                    importResult = result
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }

    // MARK: - Helper Properties

    private var formatDescription: String {
        switch selectedFormat {
        case .csv:
            return "Import shifts from CSV files exported from other time tracking apps"
        case .json:
            return "Restore a full backup including shifts, patterns, and settings"
        case .ics:
            return "Import calendar events and convert them to shifts"
        }
    }

    private var allowedFileTypes: [UTType] {
        switch selectedFormat {
        case .csv:
            return [.commaSeparatedText, .text]
        case .json:
            return [.json]
        case .ics:
            return [.ics]
        }
    }
}

// MARK: - Preview

#Preview {
    ImportView()
        .modelContainer(for: [Shift.self, UserProfile.self])
}
