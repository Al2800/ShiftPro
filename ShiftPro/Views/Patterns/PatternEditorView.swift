import SwiftUI

struct PatternEditorView: View {
    @State private var definition = PatternTemplates.weeklyNineToFive

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
                Stepper("Start Minute: \(definition.startMinuteOfDay)", value: $definition.startMinuteOfDay, in: 0...1439)
                Stepper("Duration: \(definition.durationMinutes) min", value: $definition.durationMinutes, in: 60...1440, step: 30)
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
                    Text("Cycle length: \(definition.rotationDays.count) days")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    ForEach(definition.rotationDays, id: \.id) { day in
                        HStack {
                            Text("Day \(day.index + 1)")
                            Spacer()
                            Text(day.isWorkDay ? "Work" : "Off")
                                .foregroundStyle(day.isWorkDay ? ShiftProColors.success : ShiftProColors.inkSubtle)
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
    }
}

#Preview {
    NavigationStack {
        PatternEditorView()
    }
}
