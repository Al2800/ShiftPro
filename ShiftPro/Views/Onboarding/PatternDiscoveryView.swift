import SwiftUI

struct PatternDiscoveryView: View {
    @Binding var data: OnboardingData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shift Pattern")
                .font(ShiftProTypography.title)
                .foregroundStyle(Color.white)

            Text("Choose a pattern to prefill your schedule. You can customize later.")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.fog)

            VStack(spacing: 12) {
                ForEach(ShiftPatternOption.allCases) { option in
                    Button(action: { data.selectedPattern = option }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title)
                                    .font(ShiftProTypography.headline)
                                Text(option.summary)
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.fog)
                            }
                            Spacer()
                            if data.selectedPattern == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ShiftProColors.accent)
                            }
                        }
                        .padding(ShiftProSpacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ShiftProColors.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            data.selectedPattern == option ? ShiftProColors.accent : ShiftProColors.divider,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(ShiftProSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ShiftProColors.steel)
        )
        .padding(.horizontal, ShiftProSpacing.large)
    }
}

#Preview {
    PatternDiscoveryView(data: .constant(OnboardingData()))
        .padding()
        .background(ShiftProColors.heroGradient)
}
