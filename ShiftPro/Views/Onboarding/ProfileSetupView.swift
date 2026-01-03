import SwiftUI

struct ProfileSetupView: View {
    @Binding var data: OnboardingData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile Setup")
                .font(ShiftProTypography.title)
                .foregroundStyle(Color.white)

            Text("Add your details so schedules and reports are personalized.")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.fog)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Workplace (optional)", text: $data.workplace)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(ShiftProColors.ink)

                TextField("Job Title (optional)", text: $data.jobTitle)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(ShiftProColors.ink)

                TextField("Employee ID (optional)", text: $data.employeeId)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(ShiftProColors.ink)

                HStack {
                    Text("Start Date")
                        .foregroundStyle(.white)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $data.startDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
            }
            .font(ShiftProTypography.body)
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
}

#Preview {
    ProfileSetupView(data: .constant(OnboardingData()))
        .padding()
        .background(ShiftProColors.heroGradient)
}
