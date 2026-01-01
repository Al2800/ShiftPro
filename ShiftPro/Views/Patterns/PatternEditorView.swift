import SwiftUI

struct PatternEditorView: View {
    @State private var definition = PatternTemplates.weeklyNineToFive
    private let durationMinuteOptions = [0, 15, 30, 45]

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name", text: $definition.name)
                Picker("Type", selection: $definition.kind) {
                    Text("Weekly").tag(PatternDefinition.Kind.weekly)
                    Text("Rotating").tag(PatternDefinition.Kind.rotating)
                }
            }

            Section("Timing") {
                DatePicker(
                    "Start Time",
                    selection: startTimeBinding,
                    displayedComponents: [.hourAndMinute]
                )

                HStack(spacing: ShiftProSpacing.small) {
                    Picker("Hours", selection: durationHoursBinding) {
                        ForEach(0...24, id: \.self) { hour in
                            Text("\(hour)h").tag(hour)
                        }
                    }

                    Picker("Minutes", selection: durationMinutesBinding) {
                        ForEach(durationMinuteOptions, id: \.self) { minutes in
                            Text("\(minutes)m").tag(minutes)
                        }
                    }
                }

                Text("Ends at \(formattedTime(minutes: endMinuteOfDay))")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
            }

            if definition.kind == .weekly {
                Section("Weekdays") {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Toggle(day.fullName, isOn: Binding(
                            get: { definition.weekdays.contains(day) },
                            set: { isOn in
                                if isOn {
                                    definition.weekdays.append(day)
                                } else {
                                    definition.weekdays.removeAll { $0 == day }
                                }
                            }
                        ))
                    }
                }
            } else {
                Section("Rotation") {
                    Stepper(
                        "Cycle length: \(definition.rotationDays.count) days",
                        value: rotationLengthBinding,
                        in: 2...31
                    )

                    ForEach(definition.rotationDays.indices, id: \.self) { index in
                        Toggle(isOn: rotationDayBinding(for: index)) {
                            Text("Day \(index + 1)")
                        }
                    }
                }
            }

            Section {
                NavigationLink("Preview") {
                    PatternPreviewView(definition: definition)
                }
            }
        }
        .navigationTitle("Pattern Editor")
        .onChange(of: definition.kind) { _, newValue in
            if newValue == .rotating, definition.rotationDays.isEmpty {
                updateRotationLength(4)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PatternEditorView()
    }
}

private extension PatternEditorView {
    var rotationLengthBinding: Binding<Int> {
        Binding(
            get: { definition.rotationDays.count },
            set: { newValue in
                updateRotationLength(newValue)
            }
        )
    }

    var startTimeBinding: Binding<Date> {
        Binding(
            get: { timeFromMinutes(definition.startMinuteOfDay) },
            set: { newValue in
                definition.startMinuteOfDay = minutesFromTime(newValue)
            }
        )
    }

    var durationHoursBinding: Binding<Int> {
        Binding(
            get: { definition.durationMinutes / 60 },
            set: { newValue in
                updateDuration(hours: newValue, minutes: definition.durationMinutes % 60)
            }
        )
    }

    var durationMinutesBinding: Binding<Int> {
        Binding(
            get: {
                let remainder = definition.durationMinutes % 60
                return durationMinuteOptions.contains(remainder) ? remainder : 0
            },
            set: { newValue in
                updateDuration(hours: definition.durationMinutes / 60, minutes: newValue)
            }
        )
    }

    var endMinuteOfDay: Int {
        (definition.startMinuteOfDay + definition.durationMinutes) % 1440
    }

    func updateDuration(hours: Int, minutes: Int) {
        let clampedHours = max(0, min(hours, 24))
        let clampedMinutes = durationMinuteOptions.contains(minutes) ? minutes : 0
        let totalMinutes = max(15, min((clampedHours * 60) + clampedMinutes, 1440))
        definition.durationMinutes = totalMinutes
    }

    func rotationDayBinding(for index: Int) -> Binding<Bool> {
        Binding(
            get: { definition.rotationDays[index].isWorkDay },
            set: { isOn in
                definition.rotationDays[index].isWorkDay = isOn
                definition.rotationDays[index].shiftName = isOn ? "Work" : "Off"
            }
        )
    }

    func updateRotationLength(_ length: Int) {
        let clamped = max(2, min(length, 31))
        if clamped == definition.rotationDays.count { return }

        if clamped < definition.rotationDays.count {
            definition.rotationDays = Array(definition.rotationDays.prefix(clamped))
        } else {
            let startIndex = definition.rotationDays.count
            let newDays = (startIndex..<clamped).map { index in
                PatternDefinition.RotationDayDefinition(
                    index: index,
                    isWorkDay: false,
                    shiftName: "Off"
                )
            }
            definition.rotationDays.append(contentsOf: newDays)
        }
    }

    func timeFromMinutes(_ minutes: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: minutes, to: today) ?? Date()
    }

    func minutesFromTime(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        return max(0, min((hours * 60) + minutes, 1439))
    }

    func formattedTime(minutes: Int) -> String {
        let date = timeFromMinutes(minutes)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
