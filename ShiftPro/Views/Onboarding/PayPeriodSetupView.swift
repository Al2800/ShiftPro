import SwiftUI

struct PayPeriodSetupView: View {
    @Binding var data: OnboardingData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pay Period")
                .font(ShiftProTypography.title)
                .foregroundStyle(Color.white)

            Text("Set your pay cadence and baseline hours to keep totals accurate.")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.fog)

            VStack(alignment: .leading, spacing: 12) {
                Picker("Pay Period", selection: $data.payPeriod) {
                    ForEach(PayPeriodOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(value: $data.regularHours, in: 20...80, step: 1) {
                    Text("Regular Hours: \(Int(data.regularHours))")
                }

                HStack {
                    Text("Base Rate")
                    Spacer()
                    TextField("$0", value: $data.baseRate, formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }
            .font(ShiftProTypography.body)
            .foregroundStyle(Color.white)
            .padding(ShiftProSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ShiftProColors.card)
            )
        }
        .padding(ShiftProSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ShiftProColors.steel)
        )
        .padding(.horizontal, ShiftProSpacing.large)
    }

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

#Preview {
    PayPeriodSetupView(data: .constant(OnboardingData()))
        .padding()
        .background(ShiftProColors.heroGradient)
}
