import SwiftData
import SwiftUI

struct ShiftFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let shift: Shift?

    @State private var scheduledStart: Date
    @State private var scheduledEnd: Date
    @State private var breakMinutes: Int
    @State private var rateMultiplier: Double
    @State private var notes: String
    @State private var isAdditionalShift: Bool

    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage: String = ""

    init(shift: Shift? = nil) {
        self.shift = shift
        let start = shift?.scheduledStart ?? Date()
        let defaultEnd = Calendar.current.date(byAdding: .hour, value: 8, to: start) ?? start
        let end = shift?.scheduledEnd ?? defaultEnd

        _scheduledStart = State(initialValue: start)
        _scheduledEnd = State(initialValue: end)
        _breakMinutes = State(initialValue: shift?.breakMinutes ?? 30)
        _rateMultiplier = State(initialValue: shift?.rateMultiplier ?? 1.0)
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

                    Toggle("Additional Shift", isOn: $isAdditionalShift)
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
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveShift()
                    }
                    .disabled(isSaving || !isValidRange)
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

    private func saveShift() {
        guard isValidRange else { return }
        isSaving = true

        Task { @MainActor in
            let manager = ShiftManager(context: modelContext)
            do {
                if let shift {
                    shift.isAdditionalShift = isAdditionalShift
                    try await manager.updateShift(
                        shift,
                        scheduledStart: scheduledStart,
                        scheduledEnd: scheduledEnd,
                        breakMinutes: breakMinutes,
                        rateMultiplier: rateMultiplier,
                        notes: notes.isEmpty ? nil : notes
                    )
                } else {
                    _ = try await manager.createShift(
                        scheduledStart: scheduledStart,
                        scheduledEnd: scheduledEnd,
                        breakMinutes: breakMinutes,
                        rateMultiplier: rateMultiplier,
                        notes: notes.isEmpty ? nil : notes,
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
