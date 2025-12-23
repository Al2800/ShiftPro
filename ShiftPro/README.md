# ShiftPro App Modules

This directory mirrors the MVVM + Clean Architecture layout.

- Models: SwiftData models and enums
- Views: SwiftUI presentation layer
- ViewModels: Presentation logic
- Services: Domain services and coordinators
- Repositories: Data access abstractions
- Utils: Shared helpers and extensions

## Background Tasks

ShiftPro uses `BGTaskScheduler` for periodic refresh work. Ensure the app target
includes these Info.plist entries:

- `BGTaskSchedulerPermittedIdentifiers` includes `com.shiftpro.refresh`
- `UIBackgroundModes` includes `fetch`

The scheduling logic lives in `ShiftPro/Services/BackgroundTaskManager.swift`.
