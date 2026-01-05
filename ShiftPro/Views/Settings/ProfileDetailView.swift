import SwiftUI
import SwiftData

struct ProfileDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var profile: UserProfile

    @State private var showSaveError = false
    @State private var saveError: String?

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Workplace", text: textBinding(\.workplace))
                    .textInputAutocapitalization(.words)
                TextField("Job Title", text: textBinding(\.jobTitle))
                    .textInputAutocapitalization(.words)
                TextField("Employee ID", text: textBinding(\.employeeId))
                    .textInputAutocapitalization(.characters)
            }

            Section("Schedule") {
                DatePicker("Start Date", selection: $profile.startDate, displayedComponents: [.date])

                Picker("Pay Period", selection: payPeriodBinding) {
                    ForEach(PayPeriodType.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }

                Stepper(value: $profile.regularHoursPerPay, in: 0...200, step: 1) {
                    Text("Regular hours per pay period: \(profile.regularHoursPerPay)")
                }
            }

            Section("Pay") {
                TextField("Base Rate", value: baseRateBinding, formatter: currencyFormatter)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveProfile()
                }
            }
        }
        .alert("Unable to Save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {
                showSaveError = false
                saveError = nil
            }
        } message: {
            Text(saveError ?? "An unknown error occurred.")
        }
    }

    private var payPeriodBinding: Binding<PayPeriodType> {
        Binding(
            get: { profile.payPeriodType },
            set: { newValue in
                profile.payPeriodType = newValue
                profile.markUpdated()
            }
        )
    }

    private var baseRateBinding: Binding<Double> {
        Binding(
            get: { profile.baseRateDollars ?? 0 },
            set: { newValue in
                profile.setBaseRate(dollars: newValue)
                profile.markUpdated()
            }
        )
    }

    private func textBinding(_ keyPath: ReferenceWritableKeyPath<UserProfile, String?>) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] ?? "" },
            set: { newValue in
                profile[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
                profile.markUpdated()
            }
        )
    }

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.locale = Locale(identifier: "en_GB")
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private func saveProfile() {
        do {
            try context.save()
            dismiss()
        } catch {
            saveError = error.localizedDescription
            showSaveError = true
        }
    }
}

#Preview {
    Group {
        if let container = ModelContainerFactory.previewContainerOrNil() {
            NavigationStack {
                ProfileDetailView(profile: UserProfile())
            }
            .modelContainer(container)
        } else {
            Text("Preview unavailable")
        }
    }
}
