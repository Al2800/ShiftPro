import SwiftUI

struct PatternLibraryView: View {
    private let templates = PatternTemplates.all
    @State private var showingBuilder = false

    var body: some View {
        List {
            // Quick Create Section
            Section {
                Button {
                    showingBuilder = true
                } label: {
                    HStack(spacing: ShiftProSpacing.medium) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(ShiftProColors.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Build Custom Pattern")
                                .font(ShiftProTypography.headline)
                                .foregroundStyle(ShiftProColors.ink)
                            Text("Tap to design your own shift rotation")
                                .font(ShiftProTypography.caption)
                                .foregroundStyle(ShiftProColors.inkSubtle)
                        }
                    }
                    .padding(.vertical, ShiftProSpacing.small)
                }
            } header: {
                Text("Create Your Own")
            } footer: {
                Text("Design a custom pattern by tapping on a calendar grid")
            }

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
        .sheet(isPresented: $showingBuilder) {
            SimplePatternBuilderView()
        }
    }
}

#Preview {
    NavigationStack {
        PatternLibraryView()
    }
}
