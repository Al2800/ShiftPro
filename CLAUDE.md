# ShiftPro Project - Agent Instructions

## Skills (MUST READ)

Before starting work, read these skill documents:

1. **Beads** (Task Management): ~/.claude/skills/beads/SKILL.md
2. **Agent Mail** (Coordination): ~/.claude/skills/agent-mail/SKILL.md

## Multi-Agent Workflow

### Session Start
1. Register with agent-mail using project_key="/home/agent/projects/shift-app"
2. Check inbox for pending messages
3. Run `bd ready --json` to see available tasks

### Before Working
1. Check `bd list --status in_progress --json` - skip tasks already claimed
2. Claim your task: `bd update <id> --status in_progress --json`
3. Reserve files via agent-mail before editing

### After Completing Work
1. Add detailed comment: `bd comment <id> "IMPLEMENTATION: ..."`
2. Close the bead: `bd close <id> -r "Summary"`
3. Release file reservations
4. Check inbox before picking next task

## Project Context

ShiftPro is an iOS app for shift workers. Key directories:
- ShiftPro/ - Main app code
- ShiftProCore/ - Core functionality
- ShiftProTests/ - Unit tests

## Common Issues & Pitfalls

### Xcode Project Files Not in Build

**Symptom**: "Cannot find 'TypeName' in scope" even though the .swift file exists on disk.

**Cause**: File exists but isn't added to `ShiftPro.xcodeproj/project.pbxproj`.

**Fix**: Add 4 entries to project.pbxproj:
1. `PBXBuildFile` section - `{uuid} /* File.swift in Sources */ = {isa = PBXBuildFile; fileRef = {fileRefUuid}};`
2. `PBXFileReference` section - `{fileRefUuid} /* File.swift */ = {isa = PBXFileReference; ...};`
3. `PBXGroup` section - Add fileRef uuid to the appropriate folder's children array
4. `PBXSourcesBuildPhase` section - Add the PBXBuildFile uuid

### Swift @Binding Syntax

**Wrong**: `data.wrappedValue.someMethod()` when `data` is `@Binding var data: SomeType`

**Right**: `data.someMethod()` - with @Binding, the property already gives you the unwrapped value

### Swift Async Initializers

Some types have async initializers. Check before using:
- `ShiftManager(context:)` is async - use `await ShiftManager(context: modelContext)`

### Lazy Var in Structs

**Symptom**: "cannot use mutating getter on immutable value: 'self' is immutable"

**Cause**: `lazy var` in a struct requires mutation, but method is non-mutating.

**Fix**: Create the instance locally in the method instead of using lazy var.

### Swift 6 Concurrency (Actor Isolation)

**Symptom**: Warnings about "MainActor-isolated property accessed from Sendable closure"

**Cause**: `@MainActor` class using `DispatchQueue` with closures that capture `self`.

**Fix**: Convert `@MainActor final class` to `actor`:
- Remove `@MainActor` attribute
- Change `class` to `actor`
- Remove DispatchQueue synchronization (actors handle this)
- Add `Sendable` to nested types (enums, structs)
- Use `Task { @MainActor in ... }` for MainActor-specific setup (like NotificationCenter observers)

### Conflicting Actor Isolation Attributes

**Wrong**: `@MainActor nonisolated func someMethod()` - these conflict

**Right**: Choose one:
- `@MainActor func someMethod()` - if it needs MainActor (e.g., accesses UIScreen.main)
- `nonisolated func someMethod()` - if it's pure computation with no actor state

## CI Notes

- **Build** and **Static Analysis** jobs must pass
- **Lint** job has pre-existing style violations (line length, identifier names) - not blocking
- **Capture Screenshots** job has intermittent simulator launch failures - CI infrastructure issue
