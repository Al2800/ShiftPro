import SwiftUI

struct PatternLibraryView: View {
    private let templates = PatternTemplates.all

    var body: some View {
        List {
            Section("Templates") {
                ForEach(templates) { template in
                    NavigationLink {
                        PatternPreviewView(definition: template)
                    } label: {
                        VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
                            Text(template.name)
                                .font(ShiftProTypography.headline)
                            Text(template.notes ?? "")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pattern Library")
    }
}

#Preview {
    NavigationStack {
        PatternLibraryView()
    }
}
