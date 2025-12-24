import SwiftUI

struct AnimatedCounter: View {
    let title: String?
    let value: Double
    var unit: String = ""
    var titleFont: Font = ShiftProTypography.caption
    var titleColor: Color = ShiftProColors.inkSubtle
    var valueFont: Font = ShiftProTypography.subheadline
    var valueColor: Color = ShiftProColors.ink

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.extraExtraSmall) {
            if let title {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(titleColor)
            }

            Text(formattedValue)
                .font(valueFont)
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
                .animation(AnimationManager.shared.animation(for: .standard), value: value)
        }
    }

    private var formattedValue: String {
        if unit.isEmpty {
            return String(format: "%.1f", value)
        }
        return String(format: "%.1f%@", value, unit)
    }
}

struct ExpandableCard<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let content: Content

    init(title: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Button {
                HapticManager.shared.selectionChanged()
                withAnimation(AnimationManager.shared.animation(for: .bouncy)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.ink)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
            }
            .shiftProPressable(scale: 0.98, opacity: 0.96)

            if isExpanded {
                content
                    .transition(ShiftProTransition.cardReveal)
            }
        }
        .padding(ShiftProSpacing.medium)
        .background(ShiftProColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
