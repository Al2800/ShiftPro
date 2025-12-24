import SwiftUI

struct PatternPreviewView: View {
    let definition: PatternDefinition
    private let engine = PatternEngine()

    private var previews: [ShiftPreview] {
        engine.preview(definition: definition, startDate: Date(), months: 2)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftProSpacing.medium) {
                header

                ForEach(previews) { preview in
                    HStack {
                        VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                            Text(preview.date.shiftDateFormatted)
                                .font(ShiftProTypography.subheadline)
                                .foregroundStyle(ShiftProColors.ink)
                            Text("\(preview.start.shiftTimeFormatted) - \(preview.end.shiftTimeFormatted)")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }

                        Spacer()

                        Text(preview.title)
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.accent)
                    }
                    .padding(ShiftProSpacing.medium)
                    .background(ShiftProColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(ShiftProSpacing.medium)
        }
        .background(ShiftProColors.background.ignoresSafeArea())
        .navigationTitle("Preview")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.extraSmall) {
            Text(definition.name)
                .font(ShiftProTypography.title)
                .foregroundStyle(ShiftProColors.ink)
            Text(definition.notes ?? "Generated preview for the next 2 months.")
                .font(ShiftProTypography.body)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
    }
}

#Preview {
    NavigationStack {
        PatternPreviewView(definition: PatternTemplates.fourOnFourOff)
    }
}
