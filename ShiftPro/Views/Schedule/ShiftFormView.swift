import SwiftData
import SwiftUI

struct ShiftFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<ShiftPattern> { $0.deletedAt == nil },
        sort: [SortDescriptor(\ShiftPattern.name, order: .forward)]
    )
    private var patterns: [ShiftPattern]

    let shift: Shift?
    let prefillPattern: ShiftPattern?
    let prefillDate: Date?

    @State private var scheduledStart: Date
    @State private var scheduledEnd: Date
    @State private var breakMinutes: Int
    @State private var rateMultiplier: Double
    @State private var rateLabel: String
    @State private var location: String
    @State private var selectedPatternId: UUID?
    @State private var notes: String
    @State private var isAdditionalShift: Bool

    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage: String = ""

    init(shift: Shift? = nil, prefillPattern: ShiftPattern? = nil, prefillDate: Date? = nil) {
        self.shift = shift
        self.prefillPattern = prefillPattern
        self.prefillDate = prefillDate

        let calendar = Calendar.current
        let baseDate = prefillDate ?? Date()

        // Calculate start and end times
        let start: Date
        let end: Date

        if let shift {
            start = shift.scheduledStart
            end = shift.scheduledEnd
        } else if let pattern = prefillPattern {
            start = pattern.startDate(on: baseDate, in: calendar)
            end = pattern.endDate(on: baseDate, in: calendar)
        } else {
            start = baseDate
            let defaultEnd = calendar.date(byAdding: .hour, value: 8, to: baseDate) ?? baseDate
            end = defaultEnd
        }

        _scheduledStart = State(initialValue: start)
        _scheduledEnd = State(initialValue: end)
        _breakMinutes = State(initialValue: shift?.breakMinutes ?? prefillPattern?.defaultBreakMinutes ?? 30)
        _rateMultiplier = State(initialValue: shift?.rateMultiplier ?? 1.0)
        _rateLabel = State(initialValue: shift?.rateLabel ?? "")
        _location = State(initialValue: shift?.location ?? shift?.owner?.workplace ?? "")
        _selectedPatternId = State(initialValue: shift?.pattern?.id ?? prefillPattern?.id)
        _notes = State(initialValue: shift?.notes ?? "")
        _isAdditionalShift = State(initialValue: shift?.isAdditionalShift ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    DatePicker(
                        "Start",
                        selection: $scheduledStart,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "End",
                        selection: $scheduledEnd,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    if !isValidRange {
                        Text("End time must be after start time.")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.danger)
                    }
                }

                Section("Details") {
                    TextField("Worksite (optional)", text: $location)
                        .textInputAutocapitalization(.words)

                    Picker("Break", selection: $breakMinutes) {
                        ForEach([0, 15, 30, 45, 60], id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }

                    Picker("Rate", selection: $rateMultiplier) {
                        Text("Regular 1.0x").tag(1.0)
                        Text("Premium 1.3x").tag(1.3)
                        Text("Overtime 1.5x").tag(1.5)
                        Text("Double 2.0x").tag(2.0)
                    }

                    TextField("Rate label (optional)", text: $rateLabel)
                        .textInputAutocapitalization(.words)

                    Toggle("Additional Shift", isOn: $isAdditionalShift)
                }

                if !availablePatterns.isEmpty {
                    Section("Pattern") {
                        Picker("Shift Pattern", selection: $selectedPatternId) {
                            Text("None").tag(UUID?.none)
                            ForEach(availablePatterns, id: \.id) { pattern in
                                Text("\(pattern.name) • \(pattern.timeRangeFormatted)")
                                    .tag(Optional(pattern.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedPatternId) { _, newValue in
                            applyPatternTimes(patternId: newValue)
                        }

                        if selectedPattern != nil {
                            Button("Apply Pattern Times") {
                                applyPatternTimes(patternId: selectedPatternId)
                            }
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.accent)
                            .shiftProPressable(scale: 0.98, opacity: 0.9, haptic: .selection)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Add notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Summary") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(durationText)
                            .foregroundStyle(ShiftProColors.inkSubtle)
                    }
                }
            }
            .navigationTitle(shift == nil ? "Add Shift" : "Edit Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .shiftProPressable(scale: 0.98, opacity: 0.9, haptic: .selection)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveShift()
                    }
                    .disabled(isSaving || !isValidRange)
                    .shiftProPressable(scale: 0.98, opacity: 0.9, haptic: .impactLight)
                }
            }
            .alert("Unable to Save", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isValidRange: Bool {
        scheduledEnd > scheduledStart
    }

    private var durationText: String {
        let minutes = Int(scheduledEnd.timeIntervalSince(scheduledStart) / 60)
        guard minutes > 0 else { return "—" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainder)m"
    }

    private var selectedPattern: ShiftPattern? {
        guard let selectedPatternId else { return nil }
        return availablePatterns.first { $0.id == selectedPatternId }
    }

    private var availablePatterns: [ShiftPattern] {
        let activePatterns = patterns.filter { $0.isActive }
        guard let selectedPatternId,
              let selected = patterns.first(where: { $0.id == selectedPatternId }),
              selected.isActive == false else {
            return activePatterns
        }
        return activePatterns + [selected]
    }

    private func applyPatternTimes(patternId: UUID?) {
        guard let patternId,
              let pattern = availablePatterns.first(where: { $0.id == patternId }) else {
            return
        }

        let calendar = Calendar.current
        // Use the current start date's day but apply pattern times
        let baseDate = calendar.startOfDay(for: scheduledStart)
        scheduledStart = pattern.startDate(on: baseDate, in: calendar)
        scheduledEnd = pattern.endDate(on: baseDate, in: calendar)
        breakMinutes = pattern.defaultBreakMinutes
    }

    private func saveShift() {
        guard isValidRange else { return }
        isSaving = true

        Task { @MainActor in
            let manager = await ShiftManager(context: modelContext)
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRateLabel = rateLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let storedNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
            let storedLocation = trimmedLocation.isEmpty ? nil : trimmedLocation
            let storedRateLabel = trimmedRateLabel.isEmpty ? nil : trimmedRateLabel
            let patternUpdate: ShiftPattern?? = availablePatterns.isEmpty ? nil : selectedPattern

            do {
                if let shift {
                    shift.isAdditionalShift = isAdditionalShift
                    try await manager.updateShift(
                        shift,
                        scheduledStart: scheduledStart,
                        scheduledEnd: scheduledEnd,
                        breakMinutes: breakMinutes,
                        rateMultiplier: rateMultiplier,
                        rateLabel: storedRateLabel,
                        notes: storedNotes,
                        location: storedLocation,
                        pattern: patternUpdate
                    )
                } else {
                    _ = try await manager.createShift(
                        scheduledStart: scheduledStart,
                        scheduledEnd: scheduledEnd,
                        pattern: selectedPattern,
                        breakMinutes: breakMinutes,
                        rateMultiplier: rateMultiplier,
                        rateLabel: storedRateLabel,
                        location: storedLocation,
                        notes: storedNotes,
                        isAdditionalShift: isAdditionalShift
                    )
                }
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    ShiftFormView()
}
