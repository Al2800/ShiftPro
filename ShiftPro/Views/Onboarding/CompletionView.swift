import SwiftUI

struct CompletionView: View {
    let data: OnboardingData

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(ShiftProColors.success)

            Text("All Set")
                .font(ShiftProTypography.title)
                .foregroundStyle(Color.white)

            Text("You’re ready to manage shifts with personalized defaults.")
                .font(ShiftProTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ShiftProColors.fog)

            VStack(alignment: .leading, spacing: 8) {
                if !data.workplace.isEmpty {
                    summaryRow(label: "Workplace", value: data.workplace)
                }
                summaryRow(label: "Pay Period", value: data.payPeriod.title)
                summaryRow(label: "Pattern", value: data.selectedPattern.title)
            }
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

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.fog)
            Spacer()
            Text(value)
                .font(ShiftProTypography.body)
                .foregroundStyle(Color.white)
        }
    }
}

#Preview {
    CompletionView(data: OnboardingData())
        .padding()
        .background(ShiftProColors.heroGradient)
}
