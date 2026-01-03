import SwiftUI

/// A value-first preview screen that shows the app's benefits before requesting permissions.
/// Shows example schedule, pay tracking, and reminder benefits to build trust and demonstrate value.
struct ValuePreviewView: View {
    var body: some View {
        VStack(spacing: 20) {
            headerSection

            benefitsStack
        }
        .padding(ShiftProSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ShiftProColors.steel)
        )
        .padding(.horizontal, ShiftProSpacing.large)
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(ShiftProColors.accent)

            Text("See What ShiftPro Can Do")
                .font(ShiftProTypography.title)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)

            Text("Here's how ShiftPro helps shift workers like you track time and earnings effortlessly.")
                .font(ShiftProTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ShiftProColors.fog)
        }
    }

    private var benefitsStack: some View {
        VStack(spacing: 12) {
            benefitCard(
                icon: "calendar.badge.clock",
                title: "Smart Scheduling",
                description: "View your shifts at a glance with week and month views. Never miss a shift again.",
                previewContent: schedulePreview
            )

            benefitCard(
                icon: "dollarsign.circle.fill",
                title: "Accurate Pay Tracking",
                description: "See projected earnings with overtime and rate multipliers calculated automatically.",
                previewContent: payPreview
            )

            benefitCard(
                icon: "bell.badge.fill",
                title: "Timely Reminders",
                description: "Get notified before shifts start so you're always prepared.",
                previewContent: nil
            )
        }
    }

    private func benefitCard(
        icon: String,
        title: String,
        description: String,
        previewContent: AnyView?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(ShiftProColors.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(Color.white)

                    Text(description)
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.fog)
                        .lineLimit(2)
                }
            }

            if let preview = previewContent {
                preview
                    .padding(.leading, 44)
            }
        }
        .padding(ShiftProSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ShiftProColors.card)
        )
    }

    // MARK: - Example Preview Content

    private var schedulePreview: AnyView {
        AnyView(
            HStack(spacing: 6) {
                ForEach(exampleWeekDays, id: \.self) { day in
                    VStack(spacing: 4) {
                        Text(day.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ShiftProColors.fog)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.hasShift ? ShiftProColors.accent.opacity(0.8) : ShiftProColors.steel)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(day.hasShift ? "8h" : "")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(ShiftProColors.midnight)
                            )
                    }
                }
            }
        )
    }

    private var payPreview: AnyView {
        AnyView(
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.system(size: 10))
                        .foregroundStyle(ShiftProColors.fog)
                    Text("$1,240")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hours")
                        .font(.system(size: 10))
                        .foregroundStyle(ShiftProColors.fog)
                    Text("40h")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Overtime")
                        .font(.system(size: 10))
                        .foregroundStyle(ShiftProColors.fog)
                    Text("+$93")
                        .font(ShiftProTypography.headline)
                        .foregroundStyle(ShiftProColors.warning)
                }
            }
        )
    }

    private var exampleWeekDays: [ExampleDay] {
        [
            ExampleDay(label: "M", hasShift: true),
            ExampleDay(label: "T", hasShift: true),
            ExampleDay(label: "W", hasShift: true),
            ExampleDay(label: "T", hasShift: true),
            ExampleDay(label: "F", hasShift: true),
            ExampleDay(label: "S", hasShift: false),
            ExampleDay(label: "S", hasShift: false)
        ]
    }
}

private struct ExampleDay: Hashable {
    let label: String
    let hasShift: Bool
}

#Preview {
    ValuePreviewView()
        .padding()
        .background(ShiftProColors.heroGradient)
}
