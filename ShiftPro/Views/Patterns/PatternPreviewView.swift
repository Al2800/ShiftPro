import SwiftData
import SwiftUI

struct PatternPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    let definition: PatternDefinition
    var onPatternApplied: (() -> Void)?
    var initialStartDate: Date?
    var isPreviewOnly: Bool = false

    @State private var startDate = Date()
    @State private var hasInitialized = false
    @State private var isApplying = false
    @State private var showConfirmation = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let engine = PatternEngine()

    private var previews: [ShiftPreview] {
        engine.preview(definition: definition, startDate: startDate, months: 2)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                header

                startDateSection

                ForEach(previews) { preview in
                    HStack {
                        VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                            Text(preview.date.shiftDateFormatted)
                                .font(ShiftProTypography.subheadline)
                                .foregroundStyle(ShiftProColors.ink)
                            Text("\(preview.start.shiftTimeFormatted) - \(preview.end.shiftTimeFormatted)")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }

                        Spacer()

                        Text(preview.title)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.accent)
                    }
                    .padding(ShiftProSpacing.medium)
                    .background(ShiftProColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if !isPreviewOnly {
                    applyButton
                }
            }
            .padding(ShiftProSpacing.medium)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Preview")
        .onAppear {
            if !hasInitialized, let initial = initialStartDate {
                startDate = initial
                hasInitialized = true
            }
        }
        .confirmationDialog(
            "Use This Pattern?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Use Pattern") {
                applyPattern()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
                This will create a new pattern starting \(startDate.shiftDateFormatted) \
                and generate \(previews.count) shifts for the next 2 months.
                """)
        }
        .alert("Pattern Applied", isPresented: $showSuccess) {
            Button("Done") {
                onPatternApplied?()
                dismiss()
            }
        } message: {
            Text("Your pattern has been created and \(previews.count) shifts have been scheduled.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.extraSmall) {
            Text(definition.name)
                .font(ShiftProTypography.title)
                .foregroundStyle(ShiftProColors.ink)
            Text(definition.notes ?? "Generated preview for the next 2 months.")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
    }

    @ViewBuilder
    private var startDateSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Start Date")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            if isPreviewOnly {
                Text(startDate.shiftDateFormatted)
                    .font(ShiftProTypography.body)
                    .foregroundStyle(ShiftProColors.inkSubtle)
                    .padding(ShiftProSpacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ShiftProColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                DatePicker(
                    "Pattern Start",
                    selection: $startDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(ShiftProColors.accent)
                .padding(ShiftProSpacing.small)
                .background(ShiftProColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var applyButton: some View {
        Button {
            showConfirmation = true
        } label: {
            HStack {
                if isApplying {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text("Use This Pattern")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(ShiftProSpacing.medium)
            .background(ShiftProColors.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(isApplying)
        .padding(.top, ShiftProSpacing.medium)
    }

    private func applyPattern() {
        isApplying = true

        let profile = profiles.first
        let pattern = engine.buildPattern(from: definition, owner: profile)
        pattern.cycleStartDate = startDate
        modelContext.insert(pattern)
        for rotationDay in pattern.rotationDays {
            modelContext.insert(rotationDay)
        }

        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 2, to: startDate) ?? startDate
        let shifts = engine.generateShifts(for: pattern, from: startDate, to: endDate, owner: profile)
        for shift in shifts {
            modelContext.insert(shift)
        }

        do {
            try modelContext.save()
            isApplying = false
            showSuccess = true
        } catch {
            isApplying = false
            errorMessage = "Failed to save pattern: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        PatternPreviewView(definition: PatternTemplates.fourOnFourOff)
            .modelContainer(for: [ShiftPattern.self, Shift.self, UserProfile.self])
    }
}
