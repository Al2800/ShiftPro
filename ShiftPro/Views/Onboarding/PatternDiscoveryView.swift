import SwiftUI

struct PatternDiscoveryView: View {
    @Binding var data: OnboardingData
    @State private var showPreview = false
    @State private var showPatternLibrary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Shift Pattern")
                    .font(ShiftProTypography.title)
                    .foregroundStyle(Color.white)

                Spacer()

                Button {
                    showPreview = true
                } label: {
                    Image(systemName: "eye")
                        .foregroundStyle(ShiftProColors.accent)
                }
                .accessibilityLabel("Preview pattern")
            }

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

                Button(action: { showPatternLibrary = true }) {
                    HStack {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 18))
                        Text("Browse Pattern Library")
                            .font(ShiftProTypography.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ShiftProColors.fog)
                    }
                    .padding(ShiftProSpacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ShiftProColors.card.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(ShiftProColors.divider, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                Text("Start Date")
                    .font(ShiftProTypography.subheadline)
                    .foregroundStyle(ShiftProColors.fog)

                DatePicker(
                    "Pattern starts",
                    selection: $data.patternStartDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .tint(ShiftProColors.accent)
                .labelsHidden()
            }
            .padding(.top, ShiftProSpacing.small)
        }
        .padding(ShiftProSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ShiftProColors.steel)
        )
        .padding(.horizontal, ShiftProSpacing.large)
        .sheet(isPresented: $showPreview) {
            NavigationStack {
                PatternPreviewView(
                    definition: data.selectedPatternDefinition(),
                    initialStartDate: data.patternStartDate,
                    isPreviewOnly: true
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showPreview = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPatternLibrary) {
            NavigationStack {
                PatternLibraryView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showPatternLibrary = false
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    PatternDiscoveryView(data: .constant(OnboardingData()))
        .padding()
        .background(ShiftProColors.heroGradient)
}
