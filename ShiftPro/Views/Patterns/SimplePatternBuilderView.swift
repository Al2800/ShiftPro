import SwiftUI
import SwiftData

/// A simple, visual pattern builder where users tap on a grid to design their shift cycle
struct SimplePatternBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    @State private var patternName = ""
    @State private var cycleLength = 4
    @State private var workDays: Set<Int> = [0, 1]  // Days that are work days (0-indexed)
    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var currentDayInCycle = 0  // Which day of the pattern are we on today?
    @State private var showingPreview = false
    @State private var isApplying = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let engine = PatternEngine()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                    // Pattern Name
                    VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                        Text("Pattern Name")
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(ShiftProColors.ink)

                        TextField("e.g., My 4-Day Rotation", text: $patternName)
                            .textFieldStyle(.roundedBorder)
                            .foregroundStyle(ShiftProColors.ink)
                    }

                    // Cycle Length
                    VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                        Text("Cycle Length")
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(ShiftProColors.ink)

                        Text("How many days before your pattern repeats?")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)

                        HStack(spacing: ShiftProSpacing.small) {
                            ForEach([4, 5, 6, 7, 8, 14], id: \.self) { length in
                                Button {
                                    withAnimation {
                                        cycleLength = length
                                        // Keep valid work days
                                        workDays = workDays.filter { $0 < length }
                                        currentDayInCycle = min(currentDayInCycle, length - 1)
                                    }
                                } label: {
                                    Text("\(length)")
                                        .font(ShiftProTypography.headline)
                                        .frame(width: 44, height: 44)
                                        .background(cycleLength == length ? ShiftProColors.accent : ShiftProColors.surface)
                                        .foregroundStyle(cycleLength == length ? .white : ShiftProColors.ink)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    // Work Days Grid
                    VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                        Text("Tap Days You Work")
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(ShiftProColors.ink)

                        Text("Tap each day in your cycle that's a work day")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)

                        workDaysGrid
                    }

                    // Shift Timing
                    VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                        Text("Shift Times")
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(ShiftProColors.ink)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Start")
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .foregroundStyle(ShiftProColors.inkSubtle)

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text("End")
                                    .font(ShiftProTypography.caption)
                                    .foregroundStyle(ShiftProColors.inkSubtle)
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                        .padding(ShiftProSpacing.medium)
                        .background(ShiftProColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Current Position in Cycle
                    VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                        Text("Where Are You in the Cycle?")
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(ShiftProColors.ink)

                        Text("Tap which day in your pattern is TODAY")
                            .font(ShiftProTypography.caption)
                            .foregroundStyle(ShiftProColors.inkSubtle)

                        currentDaySelector
                    }

                    // Preview Section
                    VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                        Text("Preview")
                            .font(ShiftProTypography.headline)
                            .foregroundStyle(ShiftProColors.ink)

                        patternPreviewCalendar
                    }

                    // Create Button
                    Button {
                        createPattern()
                    } label: {
                        HStack {
                            if isApplying {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text("Create Pattern")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(ShiftProSpacing.medium)
                        .background(canCreate ? ShiftProColors.accent : ShiftProColors.accent.opacity(0.5))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!canCreate || isApplying)
                }
                .padding(ShiftProSpacing.medium)
            }
            .background(ShiftProColors.background.ignoresSafeArea())
            .navigationTitle("Build Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Pattern Created!", isPresented: $showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your pattern '\(patternName)' has been created and shifts have been scheduled for the next 2 months.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var canCreate: Bool {
        !patternName.isEmpty && !workDays.isEmpty
    }

    private var workDaysGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: ShiftProSpacing.small), count: min(cycleLength, 7))

        return LazyVGrid(columns: columns, spacing: ShiftProSpacing.small) {
            ForEach(0..<cycleLength, id: \.self) { day in
                let isWorkDay = workDays.contains(day)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isWorkDay {
                            workDays.remove(day)
                        } else {
                            workDays.insert(day)
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text("Day \(day + 1)")
                            .font(ShiftProTypography.caption)
                        Image(systemName: isWorkDay ? "briefcase.fill" : "moon.zzz.fill")
                            .font(.system(size: 24))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .background(isWorkDay ? ShiftProColors.accent : ShiftProColors.surface)
                    .foregroundStyle(isWorkDay ? .white : ShiftProColors.inkSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isWorkDay ? ShiftProColors.accent : ShiftProColors.divider, lineWidth: 2)
                    )
                }
            }
        }
    }

    private var currentDaySelector: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: ShiftProSpacing.small), count: min(cycleLength, 7))

        return LazyVGrid(columns: columns, spacing: ShiftProSpacing.small) {
            ForEach(0..<cycleLength, id: \.self) { day in
                let isSelected = currentDayInCycle == day
                let isWorkDay = workDays.contains(day)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentDayInCycle = day
                    }
                } label: {
                    VStack(spacing: 4) {
                        if isSelected {
                            Text("TODAY")
                                .font(.system(size: 9, weight: .bold))
                        } else {
                            Text("Day \(day + 1)")
                                .font(ShiftProTypography.caption)
                        }
                        Text(isWorkDay ? "Work" : "Off")
                            .font(ShiftProTypography.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isSelected ? ShiftProColors.success : ShiftProColors.surface)
                    .foregroundStyle(isSelected ? .white : (isWorkDay ? ShiftProColors.accent : ShiftProColors.inkSubtle))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? ShiftProColors.success : ShiftProColors.divider, lineWidth: isSelected ? 2 : 1)
                    )
                }
            }
        }
    }

    private var patternPreviewCalendar: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let previewDays = 14

        return VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack(spacing: 4) {
                ForEach(0..<previewDays, id: \.self) { offset in
                    let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
                    let dayInCycle = ((offset - currentDayInCycle) % cycleLength + cycleLength) % cycleLength
                    let isWorkDay = workDays.contains(dayInCycle)
                    let isToday = offset == 0

                    VStack(spacing: 2) {
                        Text(dayAbbreviation(for: date))
                            .font(.system(size: 9))
                            .foregroundStyle(ShiftProColors.inkSubtle)

                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 11, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isWorkDay ? .white : ShiftProColors.ink)
                            .frame(width: 22, height: 22)
                            .background(isWorkDay ? ShiftProColors.accent : ShiftProColors.surface)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(isToday ? ShiftProColors.success : .clear, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(ShiftProSpacing.small)
            .background(ShiftProColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Summary text
            let workCount = workDays.count
            let offCount = cycleLength - workCount
            Text("\(workCount) work days, \(offCount) off - repeating every \(cycleLength) days")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
    }

    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    private func createPattern() {
        guard canCreate else { return }
        isApplying = true

        // Calculate start time and duration
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        let startMinutes = (startComponents.hour ?? 9) * 60 + (startComponents.minute ?? 0)
        var endMinutes = (endComponents.hour ?? 17) * 60 + (endComponents.minute ?? 0)
        if endMinutes <= startMinutes {
            endMinutes += 1440  // Next day
        }
        let durationMinutes = endMinutes - startMinutes

        // Create rotation days
        var rotationDays: [PatternDefinition.RotationDayDefinition] = []
        for day in 0..<cycleLength {
            let isWorkDay = workDays.contains(day)
            rotationDays.append(PatternDefinition.RotationDayDefinition(
                index: day,
                isWorkDay: isWorkDay,
                shiftName: isWorkDay ? "Work" : "Off",
                startMinuteOfDay: isWorkDay ? startMinutes : nil,
                durationMinutes: isWorkDay ? durationMinutes : nil
            ))
        }

        // Create pattern definition
        let definition = PatternDefinition(
            name: patternName,
            kind: .rotating,
            startMinuteOfDay: startMinutes,
            durationMinutes: durationMinutes,
            rotationDays: rotationDays,
            notes: "\(workDays.count) on / \(cycleLength - workDays.count) off rotation"
        )

        // Calculate the actual start date based on where user is in cycle
        let today = calendar.startOfDay(for: Date())
        let cycleStartDate = calendar.date(byAdding: .day, value: -currentDayInCycle, to: today) ?? today

        // Build and save pattern
        let profile = profiles.first
        let pattern = engine.buildPattern(from: definition, owner: profile)
        pattern.cycleStartDate = cycleStartDate
        modelContext.insert(pattern)

        for rotationDay in pattern.rotationDays {
            modelContext.insert(rotationDay)
        }

        // Generate shifts for the next 2 months
        let endDate = calendar.date(byAdding: .month, value: 2, to: today) ?? today
        let shifts = engine.generateShifts(for: pattern, from: today, to: endDate, owner: profile)
        for shift in shifts {
            modelContext.insert(shift)
        }

        do {
            try modelContext.save()
            isApplying = false
            showSuccess = true
        } catch {
            isApplying = false
            errorMessage = "Failed to save pattern: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    SimplePatternBuilderView()
        .modelContainer(for: [ShiftPattern.self, Shift.self, UserProfile.self, RotationDay.self])
}
