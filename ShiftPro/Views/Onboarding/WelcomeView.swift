import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(ShiftProColors.accent)

            Text("Welcome to ShiftPro")
                .font(ShiftProTypography.title)
                .foregroundStyle(Color.white)

            Text("Built for shift professionals who need fast, accurate scheduling. Let’s personalize your setup in a few steps.")
                .font(ShiftProTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ShiftProColors.fog)
                .padding(.horizontal, ShiftProSpacing.large)
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
    WelcomeView()
        .padding()
        .background(ShiftProColors.heroGradient)
}
