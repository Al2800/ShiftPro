import SwiftUI
import SwiftData

/// Rate multiplier management and configuration view
struct RateMultiplierView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedMultiplier: RateMultiplier = .regular
    @State private var customMultiplier: Double = 1.0
    @State private var customLabel: String = ""
    @State private var showCustom: Bool = false

    var onSelect: ((Double, String) -> Void)?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(RateMultiplier.allCases, id: \.rawValue) { rate in
                        rateOption(rate: rate)
                    }
                } header: {
                    Text("Standard Rates")
                } footer: {
                    Text("Select the appropriate rate multiplier for this shift. Premium rates apply to overtime, night shifts, and holidays.")
                }

                Section {
                    Toggle("Use Custom Rate", isOn: $showCustom)

                    if showCustom {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Multiplier: \(String(format: "%.1fx", customMultiplier))")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)

                            Slider(value: $customMultiplier, in: 1.0...3.0, step: 0.1)
                                .tint(ShiftProColors.accent)

                            TextField("Label (optional)", text: $customLabel)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Custom Rate")
                } footer: {
                    if showCustom {
                        Text("Custom rates allow you to define specific multipliers for unique situations (e.g., hazard pay, special duty).")
                    }
                }
            }
            .navigationTitle("Rate Multiplier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyRate()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Rate Option

    @ViewBuilder
    private func rateOption(rate: RateMultiplier) -> some View {
        Button {
            selectedMultiplier = rate
            showCustom = false
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rate.displayName)
                        .font(ShiftProTypography.body)
                        .foregroundStyle(ShiftProColors.ink)

                    Text(rateDescription(for: rate))
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }

                Spacer()

                RateBadge(multiplier: rate.rawValue)

                if selectedMultiplier == rate && !showCustom {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ShiftProColors.success)
                }
            }
        }
    }

    // MARK: - Actions

    private func applyRate() {
        if showCustom {
            let label = customLabel.isEmpty ? String(format: "%.1fx", customMultiplier) : customLabel
            onSelect?(customMultiplier, label)
        } else {
            onSelect?(selectedMultiplier.rawValue, selectedMultiplier.displayName)
        }
        dismiss()
    }

    // MARK: - Helpers

    private func rateDescription(for rate: RateMultiplier) -> String {
        switch rate {
        case .regular:
            return "Standard hourly rate"
        case .overtimeBracket:
            return "Time and a third (1.3x)"
        case .extra:
            return "Time and a half (1.5x)"
        case .bankHoliday:
            return "Double time (2.0x)"
        }
    }
}

#Preview {
    RateMultiplierView { multiplier, label in
        print("Selected: \(multiplier)x - \(label)")
    }
}
