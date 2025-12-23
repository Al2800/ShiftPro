import SwiftUI

struct StatusIndicator: View {
    enum Status: String {
        case scheduled
        case inProgress
        case completed
        case missed

        var label: String {
            switch self {
            case .scheduled:
                return "Scheduled"
            case .inProgress:
                return "In Progress"
            case .completed:
                return "Completed"
            case .missed:
                return "Missed"
            }
        }

        var color: Color {
            switch self {
            case .scheduled:
                return ShiftProColors.accent
            case .inProgress:
                return ShiftProColors.warning
            case .completed:
                return ShiftProColors.success
            case .missed:
                return ShiftProColors.danger
            }
        }
    }

    let status: Status

    var body: some View {
        HStack(spacing: ShiftProSpacing.xSmall) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)

            Text(status.label)
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.textSecondary)
        }
        .padding(.horizontal, ShiftProSpacing.small)
        .padding(.vertical, ShiftProSpacing.xSmall)
        .background(
            Capsule(style: .continuous)
                .fill(ShiftProColors.surfaceMuted)
        )
    }
}

#Preview {
    VStack(spacing: ShiftProSpacing.small) {
        StatusIndicator(status: .scheduled)
        StatusIndicator(status: .inProgress)
        StatusIndicator(status: .completed)
        StatusIndicator(status: .missed)
    }
    .padding()
    .background(ShiftProColors.background)
}
