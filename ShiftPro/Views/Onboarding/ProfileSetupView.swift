import SwiftUI

struct ProfileSetupView: View {
    @Binding var data: OnboardingData

    private let departments = [
        "Metro PD",
        "County Sheriff",
        "State Patrol",
        "Transit Authority",
        "Custom"
    ]

    private let ranks = [
        "Officer",
        "Sergeant",
        "Lieutenant",
        "Captain",
        "Detective"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile Setup")
                .font(ShiftProTypography.title)
                .foregroundStyle(Color.white)

            Text("Add your details so schedules and reports are personalized.")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.fog)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Badge Number", text: $data.badgeNumber)
                    .textFieldStyle(.roundedBorder)

                Picker("Department", selection: $data.department) {
                    ForEach(departments, id: \.self) { department in
                        Text(department).tag(department)
                    }
                }
                .pickerStyle(.menu)

                Picker("Rank", selection: $data.rank) {
                    ForEach(ranks, id: \.self) { rank in
                        Text(rank).tag(rank)
                    }
                }
                .pickerStyle(.menu)

                DatePicker(
                    "Start Date",
                    selection: $data.startDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
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
}

#Preview {
    ProfileSetupView(data: .constant(OnboardingData()))
        .padding()
        .background(ShiftProColors.heroGradient)
}
