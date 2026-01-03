import Foundation
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
    @State private var isValidating: Bool = false
    @State private var selectedFileURL: URL?
    @State private var filePreview: ImportFilePreview?
    @State private var validationState: ValidationState = .idle
    @State private var importResult: ImportResult?
    @State private var errorMessage: String?
    @State private var showImportConfirmation: Bool = false

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
                    .onChange(of: selectedFormat) { _ in
                        if let url = selectedFileURL {
                            preparePreview(from: url)
                        }
                    }
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
                            Text(selectedFileURL == nil ? "Select File to Import" : "Choose Different File")
                        }
                    }
                    .disabled(isImporting)
                } header: {
                    Text("Import Data")
                } footer: {
                    if isValidating {
                        Text("Validating file...")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }

                if let filePreview {
                    Section {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(ShiftProColors.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(filePreview.displayName)
                                    .font(ShiftProTypography.body)
                                Text(filePreview.detailLine)
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                            }
                        }

                        if let snippet = filePreview.previewSnippet, !snippet.isEmpty {
                            Text(snippet)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(ShiftProColors.ink)
                                .lineLimit(6)
                        }

                        validationMessageView
                    } header: {
                        Text("File Preview")
                    }

                    if let impact = filePreview.impact {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("\(impact.shiftCount) shifts will be added", systemImage: "calendar.badge.plus")
                                    .font(ShiftProTypography.body)

                                if impact.patternCount > 0 {
                                    Label("\(impact.patternCount) patterns will be added", systemImage: "arrow.triangle.2.circlepath")
                                        .font(ShiftProTypography.body)
                                }

                                if impact.invalidRowCount > 0 {
                                    Text("\(impact.invalidRowCount) rows could not be parsed and may be skipped.")
                                        .font(ShiftProTypography.caption)
                                        .foregroundStyle(ShiftProColors.inkSubtle)
                                }
                            }
                        } header: {
                            Text("Import Impact")
                        } footer: {
                            Text("Your existing data stays intact.")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                    }

                    Section {
                        Button {
                            showImportConfirmation = true
                        } label: {
                            Label("Import Now", systemImage: "square.and.arrow.down")
                        }
                        .disabled(isImporting || !validationState.isValid)

                        Button(role: .destructive) {
                            clearSelection()
                        } label: {
                            Label("Clear Selection", systemImage: "xmark.circle")
                        }
                    }
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
                        instructionRow(icon: "3.circle.fill", text: "Review the impact summary and confirm import")
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
            .confirmationDialog(importConfirmationTitle, isPresented: $showImportConfirmation, titleVisibility: .visible) {
                Button(importConfirmationActionLabel) {
                    if let url = selectedFileURL {
                        performImport(from: url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(importConfirmationMessage)
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
            preparePreview(from: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func preparePreview(from url: URL) {
        errorMessage = nil
        importResult = nil
        isValidating = true
        selectedFileURL = url
        let format = selectedFormat
        let currentProfile = profile

        Task {
            let (preview, state) = await buildPreview(from: url, format: format, profile: currentProfile)
            await MainActor.run {
                filePreview = preview
                validationState = state
                isValidating = false
            }
        }
    }

    private func performImport(from url: URL) {
        isImporting = true
        errorMessage = nil
        importResult = nil

        let capturedContext = context
        Task {
            do {
                let accessGranted = url.startAccessingSecurityScopedResource()
                defer {
                    if accessGranted {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                guard accessGranted else {
                    throw ImportManager.ImportError.importFailed("Unable to access the selected file.")
                }

                let importManager = await ImportManager(context: capturedContext)
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

    private func clearSelection() {
        selectedFileURL = nil
        filePreview = nil
        validationState = .idle
        showImportConfirmation = false
    }

    private func buildPreview(
        from url: URL,
        format: ImportManager.ImportFormat,
        profile: UserProfile?
    ) async -> (ImportFilePreview?, ValidationState) {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard accessGranted else {
            return (nil, .invalid(message: "Unable to access the selected file."))
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return (nil, .invalid(message: "Unable to read file attributes."))
        }

        let sizeBytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        if sizeBytes == 0 {
            return (nil, .invalid(message: "The selected file is empty."))
        }
        if sizeBytes > 50 * 1024 * 1024 {
            return (nil, .invalid(message: "File is larger than 50 MB. Please choose a smaller file."))
        }

        let previewSnippet = loadPreviewSnippet(from: url)
        let displayName = url.lastPathComponent
        let modifiedAt = attributes[.modificationDate] as? Date

        let allowedExtensions = expectedExtensions(for: format)
        let extensionMatches = allowedExtensions.contains(url.pathExtension.lowercased())
        if !extensionMatches {
            return (
                ImportFilePreview(
                    displayName: displayName,
                    sizeBytes: sizeBytes,
                    modifiedAt: modifiedAt,
                    previewSnippet: previewSnippet,
                    impact: nil
                ),
                .invalid(message: "Selected file does not match the chosen format.")
            )
        }

        do {
            let importManager = await ImportManager(context: context)
            let impact = try await importManager.previewImpact(from: url, format: format, profile: profile)
            let message = "Ready to import \(impact.summary)."
            return (
                ImportFilePreview(
                    displayName: displayName,
                    sizeBytes: sizeBytes,
                    modifiedAt: modifiedAt,
                    previewSnippet: previewSnippet,
                    impact: impact
                ),
                .valid(message: message)
            )
        } catch {
            return (
                ImportFilePreview(
                    displayName: displayName,
                    sizeBytes: sizeBytes,
                    modifiedAt: modifiedAt,
                    previewSnippet: previewSnippet,
                    impact: nil
                ),
                .invalid(message: error.localizedDescription)
            )
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
            return [.calendarEvent]
        }
    }

    private func expectedExtensions(for format: ImportManager.ImportFormat) -> [String] {
        switch format {
        case .csv:
            return ["csv", "txt"]
        case .json:
            return ["json"]
        case .ics:
            return ["ics"]
        }
    }

    private func loadPreviewSnippet(from url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = try? handle.read(upToCount: 2048)
        guard let data, !data.isEmpty else { return nil }
        let raw = String(decoding: data, as: UTF8.self)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
            .components(separatedBy: .newlines)
            .prefix(6)
            .joined(separator: "\n")
    }

    private var importConfirmationTitle: String {
        guard let impact = filePreview?.impact else {
            return "Confirm Import"
        }
        if impact.patternCount > 0 {
            return "Import \(impact.shiftCount) shifts and \(impact.patternCount) patterns?"
        }
        return "Import \(impact.shiftCount) shifts?"
    }

    private var importConfirmationMessage: String {
        guard let impact = filePreview?.impact else {
            return "This will add the selected data to your schedule."
        }
        var message = "This will add \(impact.summary) to your schedule."
        if impact.invalidRowCount > 0 {
            message += " \(impact.invalidRowCount) rows may be skipped due to formatting issues."
        }
        return message
    }

    private var importConfirmationActionLabel: String {
        guard let impact = filePreview?.impact else {
            return "Import"
        }
        return "Import \(impact.summary)"
    }

    private var validationMessageView: some View {
        switch validationState {
        case .idle:
            return AnyView(EmptyView())
        case .valid(let message):
            return AnyView(
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(ShiftProColors.success)
                    .font(ShiftProTypography.caption)
            )
        case .invalid(let message):
            return AnyView(
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(ShiftProColors.warning)
                    .font(ShiftProTypography.caption)
            )
        }
    }
}

private struct ImportFilePreview {
    let displayName: String
    let sizeBytes: Int64
    let modifiedAt: Date?
    let previewSnippet: String?
    let impact: ImportImpact?

    var detailLine: String {
        let size = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
        if let modifiedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "\(size) • Updated \(formatter.string(from: modifiedAt))"
        }
        return size
    }
}

private enum ValidationState {
    case idle
    case valid(message: String)
    case invalid(message: String)

    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .idle, .invalid:
            return false
        }
    }
}

// MARK: - Preview

#Preview {
    ImportView()
        .modelContainer(for: [Shift.self, UserProfile.self])
}
