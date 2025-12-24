import SwiftUI
import SwiftData

struct RateMultiplierView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    @Query(sort: [SortDescriptor(\PayRuleset.createdAt, order: .forward)])
    private var rulesets: [PayRuleset]

    @State private var rateConfigs: [PayRules.RateMultiplierConfig] = []
    @State private var activeRuleset: PayRuleset?

    var body: some View {
        Form {
            Section("Active Ruleset") {
                Text(activeRuleset?.name ?? "Default Rules")
                    .font(ShiftProTypography.body)
            }

            Section("Rate Multipliers") {
                ForEach(rateConfigs.indices, id: \.self) { index in
                    HStack {
                        TextField("Label", text: Binding(
                            get: { rateConfigs[index].label },
                            set: { newValue in
                                let config = rateConfigs[index]
                                rateConfigs[index] = .init(
                                    id: config.id,
                                    label: newValue,
                                    multiplier: config.multiplier
                                )
                                persistChanges()
                            }
                        ))
                        .font(ShiftProTypography.body)

                        Spacer()

                        Stepper(value: Binding(
                            get: { rateConfigs[index].multiplier },
                            set: { newValue in
                                let config = rateConfigs[index]
                                rateConfigs[index] = .init(
                                    id: config.id,
                                    label: config.label,
                                    multiplier: newValue
                                )
                                persistChanges()
                            }
                        ), in: 1.0...3.0, step: 0.1) {
                            Text(String(format: "%.1fx", rateConfigs[index].multiplier))
                                .font(ShiftProTypography.caption)
                        }
                    }
                }
            }

            Section(footer: Text("Rate changes apply to new or edited shifts only.")) {
                Button("Reset to Defaults") {
                    rateConfigs = PayRules.defaultMultipliers
                    persistChanges()
                }
                .foregroundStyle(ShiftProColors.accent)
            }
        }
        .navigationTitle("Rate Multipliers")
        .task {
            await ensureRuleset()
        }
    }

    @MainActor
    private func ensureRuleset() async {
        if let existing = rulesets.first {
            activeRuleset = existing
            rateConfigs = existing.rateMultipliers
            return
        }

        let owner = profiles.first
        let ruleset = PayRuleset(name: "Standard", owner: owner)
        context.insert(ruleset)
        owner?.activePayRuleset = ruleset
        activeRuleset = ruleset
        rateConfigs = ruleset.rateMultipliers
    }

    private func persistChanges() {
        guard let activeRuleset else { return }
        let currentRules = activeRuleset.rules ?? PayRules.defaults
        let payPeriodType = PayPeriodType(rawValue: currentRules.payPeriodTypeRaw) ?? .biweekly
        let updatedRules = PayRules(
            schemaVersion: currentRules.schemaVersion,
            unpaidBreakMinutes: currentRules.unpaidBreakMinutes,
            rateMultipliers: rateConfigs,
            payPeriodType: payPeriodType
        )
        activeRuleset.rules = updatedRules
        activeRuleset.markUpdated()
    }
}

#Preview {
    NavigationStack {
        RateMultiplierView()
    }
    .modelContainer(ModelContainerFactory.unsafePreviewContainer())
}
