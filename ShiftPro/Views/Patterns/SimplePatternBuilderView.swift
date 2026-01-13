import SwiftUI
import SwiftData

/// A visual pattern builder where users select shift types and stamp them onto days
struct SimplePatternBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: [SortDescriptor(\UserProfile.createdAt, order: .forward)])
    private var profiles: [UserProfile]

    // Pattern configuration
    @State private var patternName = ""
    @State private var cycleLength = 4
    @State private var currentDayInCycle = 0

    // Shift templates palette
    @State private var shiftTemplates: [ShiftTemplate] = ShiftTemplate.defaults
    @State private var selectedTemplate: ShiftTemplate? = ShiftTemplate.defaults.first
    @State private var dayAssignments: [Int: ShiftTemplate] = [:]  // dayIndex -> template
    @State private var explicitlyOffDays: Set<Int> = []  // Days explicitly marked as off

    // UI state
    @State private var isCustomLength = false
    @State private var isApplying = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingAddShiftType = false
    @State private var editingTemplate: ShiftTemplate? = nil
    @State private var generationMonths: Int = 12  // How many months ahead to generate

    private let engine = PatternEngine()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShiftProSpacing.large) {
                    headerSection
                    shiftTypePaletteSection
                    cycleLengthSection
                    dayGridSection
                    previewSection
                    generationDurationSection
                    createButtonSection
                }
                .padding(ShiftProSpacing.medium)
            }
            .background(ShiftProColors.background.ignoresSafeArea())
            .navigationTitle("Build Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddShiftType) {
                ShiftTypeEditorSheet(
                    template: editingTemplate,
                    onSave: { template in
                        if let index = shiftTemplates.firstIndex(where: { $0.id == template.id }) {
                            shiftTemplates[index] = template
                        } else {
                            shiftTemplates.append(template)
                        }
                        selectedTemplate = template
                    }
                )
            }
            .alert("Pattern Created!", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your pattern '\(resolvedPatternName)' has been created and shifts have been scheduled for the next \(generationDurationLabel).")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.extraSmall) {
            Text("Build Your Pattern")
                .font(ShiftProTypography.title)
                .foregroundStyle(ShiftProColors.ink)

            Text("Select a shift type, then tap days to apply it")
                .font(ShiftProTypography.subheadline)
                .foregroundStyle(ShiftProColors.inkSubtle)
        }
    }

    // MARK: - Shift Type Palette

    private var shiftTypePaletteSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            HStack {
                Text("Shift Types")
                    .font(ShiftProTypography.headline)
                    .foregroundStyle(ShiftProColors.ink)

                Spacer()

                Button {
                    editingTemplate = nil
                    showingAddShiftType = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ShiftProSpacing.small) {
                    // Off button (special)
                    shiftTypePill(template: nil, isOff: true)

                    // Shift type pills
                    ForEach(shiftTemplates) { template in
                        shiftTypePill(template: template, isOff: false)
                    }
                }
                .padding(.horizontal, 2)
            }

            if let selected = selectedTemplate {
                HStack(spacing: ShiftProSpacing.extraSmall) {
                    Circle()
                        .fill(selected.color)
                        .frame(width: 8, height: 8)
                    Text("Tap days below to add '\(selected.name)' shifts")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                }
                .padding(.top, ShiftProSpacing.extraSmall)
            } else {
                Text("Tap days below to mark them as Off")
                    .font(ShiftProTypography.caption)
                    .foregroundStyle(ShiftProColors.inkSubtle)
                    .padding(.top, ShiftProSpacing.extraSmall)
            }
        }
    }

    private func shiftTypePill(template: ShiftTemplate?, isOff: Bool) -> some View {
        let isSelected = isOff ? (selectedTemplate == nil) : (selectedTemplate?.id == template?.id)
        let color = template?.color ?? ShiftProColors.inkSubtle
        let name = template?.name ?? "Off"
        let icon = template?.icon ?? "moon.zzz.fill"
        let timeRange = template?.timeRangeFormatted

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTemplate = isOff ? nil : template
            }
            HapticManager.fire(.selection, enabled: !reduceMotion)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))

                Text(name)
                    .font(.system(size: 12, weight: .semibold))

                if let timeRange = timeRange {
                    Text(timeRange)
                        .font(.system(size: 9, weight: .medium))
                        .opacity(0.8)
                }
            }
            .frame(width: 70, height: isOff ? 60 : 72)
            .foregroundStyle(isSelected ? .white : color)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? color : color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? color : .clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let template = template, !isOff {
                Button {
                    editingTemplate = template
                    showingAddShiftType = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    shiftTemplates.removeAll { $0.id == template.id }
                    // Clear any assignments using this template
                    for (day, assigned) in dayAssignments where assigned.id == template.id {
                        dayAssignments.removeValue(forKey: day)
                    }
                    if selectedTemplate?.id == template.id {
                        selectedTemplate = nil
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Cycle Length

    private var cycleLengthSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Cycle Length")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ShiftProSpacing.small) {
                    ForEach([4, 5, 7, 8, 14, 21, 28], id: \.self) { length in
                        cycleLengthButton(for: length)
                    }
                    customLengthButton
                }
            }

            if isCustomLength {
                VStack(alignment: .leading, spacing: ShiftProSpacing.extraSmall) {
                    Text("\(cycleLength) days")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)

                    Slider(
                        value: Binding(
                            get: { Double(cycleLength) },
                            set: { cycleLength = Int($0); normalizeCycleLength() }
                        ),
                        in: 2...42,
                        step: 1
                    )
                }
            }
        }
    }

    private func cycleLengthButton(for length: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                cycleLength = length
                isCustomLength = false
                normalizeCycleLength()
            }
            HapticManager.fire(.selection, enabled: !reduceMotion)
        } label: {
            Text("\(length)")
                .font(ShiftProTypography.headline)
                .frame(width: 48, height: 48)
                .background(cycleLength == length && !isCustomLength ? ShiftProColors.accent : ShiftProColors.surface)
                .foregroundStyle(cycleLength == length && !isCustomLength ? .white : ShiftProColors.ink)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .shiftProPressable(scale: 0.97, opacity: 0.94, haptic: nil)
    }

    private var customLengthButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isCustomLength = true
            }
            HapticManager.fire(.selection, enabled: !reduceMotion)
        } label: {
            Text("Custom")
                .font(ShiftProTypography.subheadline)
                .frame(width: 80, height: 48)
                .background(isCustomLength ? ShiftProColors.accent : ShiftProColors.surface)
                .foregroundStyle(isCustomLength ? .white : ShiftProColors.ink)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .shiftProPressable(scale: 0.97, opacity: 0.94, haptic: nil)
    }

    // MARK: - Day Grid

    private var dayGridSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Tap Days to Assign Shifts")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            dayGrid
        }
    }

    private var dayGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: ShiftProSpacing.small), count: min(cycleLength, 7))

        return LazyVGrid(columns: columns, spacing: ShiftProSpacing.small) {
            ForEach(0..<cycleLength, id: \.self) { day in
                dayCell(for: day)
            }
        }
    }

    private func dayCell(for day: Int) -> some View {
        let assignment = dayAssignments[day]
        let isWorkDay = assignment != nil
        let isExplicitlyOff = explicitlyOffDays.contains(day)
        let color = assignment?.color ?? ShiftProColors.inkSubtle
        let code = assignment?.shortCode ?? (isExplicitlyOff ? "OFF" : "·")
        let icon = assignment?.icon ?? "moon.zzz.fill"

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if let template = selectedTemplate {
                    // Assign selected shift type
                    dayAssignments[day] = template
                    explicitlyOffDays.remove(day)
                } else {
                    // Mark as explicitly off
                    dayAssignments.removeValue(forKey: day)
                    explicitlyOffDays.insert(day)
                }
            }
            HapticManager.fire(.impactMedium, enabled: !reduceMotion)
        } label: {
            VStack(spacing: 4) {
                Text("Day \(day + 1)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isWorkDay ? .white.opacity(0.8) : (isExplicitlyOff ? ShiftProColors.inkSubtle : ShiftProColors.inkSubtle.opacity(0.6)))

                Text(code)
                    .font(.system(size: isExplicitlyOff ? 14 : 22, weight: .bold, design: .rounded))
                    .foregroundStyle(isWorkDay ? .white : (isExplicitlyOff ? ShiftProColors.inkSubtle : ShiftProColors.inkSubtle.opacity(0.5)))

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isWorkDay ? .white.opacity(0.8) : (isExplicitlyOff ? ShiftProColors.inkSubtle : ShiftProColors.inkSubtle.opacity(0.5)))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isWorkDay ? color : (isExplicitlyOff ? ShiftProColors.surfaceMuted : ShiftProColors.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isWorkDay ? color : (isExplicitlyOff ? ShiftProColors.inkSubtle.opacity(0.3) : ShiftProColors.divider), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .shiftProPressable(scale: 0.96, opacity: 0.94, haptic: nil)
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Preview")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
                HStack {
                    Text("Today is Day \(currentDayInCycle + 1) of your cycle")
                        .font(ShiftProTypography.caption)
                        .foregroundStyle(ShiftProColors.inkSubtle)
                    Spacer()
                    Stepper("", value: $currentDayInCycle, in: 0...(max(0, cycleLength - 1)))
                        .labelsHidden()
                }

                previewCalendar

                summaryText
            }
            .padding(ShiftProSpacing.medium)
            .background(ShiftProColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var previewCalendar: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let previewDays = min(21, cycleLength * 2)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(0..<previewDays, id: \.self) { offset in
                    let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
                    let dayInCycle = ((offset + currentDayInCycle) % cycleLength + cycleLength) % cycleLength
                    let assignment = dayAssignments[dayInCycle]
                    let isExplicitlyOff = explicitlyOffDays.contains(dayInCycle)
                    let isToday = offset == 0
                    let code = assignment?.shortCode ?? (isExplicitlyOff ? "—" : "·")
                    let color = assignment?.color ?? ShiftProColors.inkSubtle

                    VStack(spacing: 2) {
                        Text(dayAbbreviation(for: date))
                            .font(.system(size: 9))
                            .foregroundStyle(ShiftProColors.inkSubtle)

                        Text(code)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(assignment != nil ? .white : ShiftProColors.inkSubtle)
                            .frame(width: 24, height: 24)
                            .background(assignment != nil ? color : (isExplicitlyOff ? ShiftProColors.surfaceMuted : ShiftProColors.surface.opacity(0.5)))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(isToday ? ShiftProColors.success : .clear, lineWidth: 2)
                            )
                    }
                }
            }
        }
    }

    private var summaryText: some View {
        let workCount = dayAssignments.count
        let offCount = cycleLength - workCount

        // Group by shift type
        var typeCounts: [String: Int] = [:]
        for (_, template) in dayAssignments {
            typeCounts[template.name, default: 0] += 1
        }

        let typeStrings = typeCounts.map { "\($0.value) \($0.key)" }.joined(separator: ", ")
        let summary = typeStrings.isEmpty ? "\(offCount) off days" : "\(typeStrings), \(offCount) off"

        return Text("\(summary) - repeating every \(cycleLength) days")
            .font(ShiftProTypography.caption)
            .foregroundStyle(ShiftProColors.inkSubtle)
    }

    // MARK: - Generation Duration

    private var generationDurationSection: some View {
        VStack(alignment: .leading, spacing: ShiftProSpacing.small) {
            Text("Generate Ahead")
                .font(ShiftProTypography.headline)
                .foregroundStyle(ShiftProColors.ink)

            Text("How far in advance to schedule your shifts")
                .font(ShiftProTypography.caption)
                .foregroundStyle(ShiftProColors.inkSubtle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ShiftProSpacing.small) {
                    ForEach([3, 6, 12, 24], id: \.self) { months in
                        durationButton(months: months)
                    }
                }
            }
        }
    }

    private func durationButton(months: Int) -> some View {
        let isSelected = generationMonths == months
        let label = months == 12 ? "1 Year" : months == 24 ? "2 Years" : "\(months) Months"

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                generationMonths = months
            }
            HapticManager.fire(.selection, enabled: !reduceMotion)
        } label: {
            Text(label)
                .font(ShiftProTypography.subheadline)
                .padding(.horizontal, ShiftProSpacing.medium)
                .frame(height: 44)
                .background(isSelected ? ShiftProColors.accent : ShiftProColors.surface)
                .foregroundStyle(isSelected ? .white : ShiftProColors.ink)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .shiftProPressable(scale: 0.97, opacity: 0.94, haptic: nil)
    }

    // MARK: - Create Button

    private var createButtonSection: some View {
        VStack(spacing: ShiftProSpacing.small) {
            // Pattern name
            TextField("Pattern name (optional)", text: $patternName)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(ShiftProColors.ink)

            Button {
                createPattern()
            } label: {
                HStack(spacing: 8) {
                    if isApplying {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isApplying ? "Creating..." : "Create Pattern")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(ShiftProSpacing.medium)
                .background(canCreate ? ShiftProColors.accent : ShiftProColors.accent.opacity(0.5))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canCreate || isApplying)
            .shiftProPressable(scale: 0.98, opacity: 0.96, haptic: nil)
        }
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        !dayAssignments.isEmpty  // At least one work day
    }

    private var generationDurationLabel: String {
        switch generationMonths {
        case 12: return "year"
        case 24: return "2 years"
        default: return "\(generationMonths) months"
        }
    }

    private var resolvedPatternName: String {
        let trimmed = patternName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        // Auto-generate name based on shift types used
        let typeNames = Set(dayAssignments.values.map { $0.name })
        if typeNames.count == 1, let name = typeNames.first {
            let workCount = dayAssignments.count
            let offCount = cycleLength - workCount
            return "\(name) \(workCount) on \(offCount) off"
        }
        return "\(dayAssignments.count) on \(cycleLength - dayAssignments.count) off"
    }

    private func normalizeCycleLength() {
        // Remove assignments beyond cycle length
        dayAssignments = dayAssignments.filter { $0.key < cycleLength }
        explicitlyOffDays = explicitlyOffDays.filter { $0 < cycleLength }
        currentDayInCycle = min(currentDayInCycle, max(0, cycleLength - 1))
    }

    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    private func createPattern() {
        guard canCreate else { return }
        isApplying = true

        // Get the primary shift template (most used) for pattern defaults
        let templateCounts = Dictionary(grouping: dayAssignments.values, by: { $0.id }).mapValues { $0.count }
        let primaryTemplateId = templateCounts.max(by: { $0.value < $1.value })?.key
        let primaryTemplate = dayAssignments.values.first { $0.id == primaryTemplateId } ?? ShiftTemplate.day

        // Create rotation days
        var rotationDays: [PatternDefinition.RotationDayDefinition] = []
        for day in 0..<cycleLength {
            if let template = dayAssignments[day] {
                rotationDays.append(PatternDefinition.RotationDayDefinition(
                    index: day,
                    isWorkDay: true,
                    shiftName: template.name,
                    startMinuteOfDay: template.startMinuteOfDay,
                    durationMinutes: template.durationMinutes
                ))
            } else {
                rotationDays.append(PatternDefinition.RotationDayDefinition(
                    index: day,
                    isWorkDay: false,
                    shiftName: "Off",
                    startMinuteOfDay: nil,
                    durationMinutes: nil
                ))
            }
        }

        // Create pattern definition
        let definition = PatternDefinition(
            name: resolvedPatternName,
            kind: .rotating,
            startMinuteOfDay: primaryTemplate.startMinuteOfDay,
            durationMinutes: primaryTemplate.durationMinutes,
            rotationDays: rotationDays,
            notes: nil
        )

        // Calculate cycle start date
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cycleStartDate = calendar.date(byAdding: .day, value: -currentDayInCycle, to: today) ?? today

        // Build and save pattern
        let profile = profiles.first
        let pattern = engine.buildPattern(from: definition, owner: profile)
        pattern.cycleStartDate = cycleStartDate
        pattern.colorHex = primaryTemplate.colorHex
        pattern.shortCode = primaryTemplate.shortCode
        modelContext.insert(pattern)

        for rotationDay in pattern.rotationDays {
            modelContext.insert(rotationDay)
        }

        // Generate shifts for the selected duration
        let endDate = calendar.date(byAdding: .month, value: generationMonths, to: today) ?? today
        let shifts = engine.generateShifts(for: pattern, from: today, to: endDate, owner: profile)
        for shift in shifts {
            modelContext.insert(shift)
        }

        do {
            try modelContext.save()
            isApplying = false
            showSuccess = true
            HapticManager.fire(.notificationSuccess, enabled: !reduceMotion)
        } catch {
            isApplying = false
            errorMessage = "Failed to save pattern: \(error.localizedDescription)"
            showError = true
            HapticManager.fire(.notificationError, enabled: !reduceMotion)
        }
    }
}

// MARK: - Shift Type Editor Sheet

struct ShiftTypeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let template: ShiftTemplate?
    let onSave: (ShiftTemplate) -> Void

    @State private var name: String = ""
    @State private var shortCode: String = ""
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var selectedColorHex: String = ShiftTemplate.availableColors[0]
    @State private var selectedIcon: String = "briefcase.fill"

    var body: some View {
        NavigationStack {
            Form {
                Section("Shift Details") {
                    TextField("Name (e.g., Early, Night)", text: $name)
                        .onChange(of: name) { _, new in
                            if shortCode.isEmpty || shortCode == String(name.prefix(1)).uppercased() {
                                shortCode = String(new.prefix(1)).uppercased()
                            }
                        }

                    TextField("Calendar Label (1 letter)", text: $shortCode)
                        .onChange(of: shortCode) { _, new in
                            shortCode = String(new.prefix(1)).uppercased()
                        }
                }

                Section("Times") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section("Appearance") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(ShiftTemplate.availableColors, id: \.self) { hex in
                            let color = Color(hex: hex) ?? .blue
                            Circle()
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle().strokeBorder(.white, lineWidth: selectedColorHex == hex ? 3 : 0)
                                )
                                .onTapGesture { selectedColorHex = hex }
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(ShiftTemplate.availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .frame(width: 40, height: 40)
                                .background(selectedIcon == icon ? Color(hex: selectedColorHex) ?? .blue : ShiftProColors.surface)
                                .foregroundStyle(selectedIcon == icon ? .white : ShiftProColors.ink)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                }
            }
            .navigationTitle(template == nil ? "New Shift Type" : "Edit Shift Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let template = template {
                    name = template.name
                    shortCode = template.shortCode
                    selectedColorHex = template.colorHex
                    selectedIcon = template.icon
                    // Convert minutes to Date
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    startTime = calendar.date(byAdding: .minute, value: template.startMinuteOfDay, to: today) ?? today
                    endTime = calendar.date(byAdding: .minute, value: template.endMinuteOfDay, to: today) ?? today
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func saveTemplate() {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        let startMinutes = (startComponents.hour ?? 9) * 60 + (startComponents.minute ?? 0)
        var endMinutes = (endComponents.hour ?? 17) * 60 + (endComponents.minute ?? 0)
        if endMinutes <= startMinutes {
            endMinutes += 1440  // Next day
        }
        let durationMinutes = endMinutes - startMinutes

        let newTemplate = ShiftTemplate(
            id: template?.id ?? UUID(),
            name: name,
            shortCode: shortCode.isEmpty ? String(name.prefix(1)).uppercased() : shortCode,
            startMinuteOfDay: startMinutes,
            durationMinutes: durationMinutes,
            colorHex: selectedColorHex,
            icon: selectedIcon
        )

        onSave(newTemplate)
        dismiss()
    }
}

#Preview {
    SimplePatternBuilderView()
        .modelContainer(for: [ShiftPattern.self, Shift.self, UserProfile.self, RotationDay.self])
}
