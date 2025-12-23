This placeholder exists because Xcode projects must be generated on macOS.
Create the real Xcode project in Xcode 15+ and replace this directory with
ShiftPro.xcodeproj (including project.pbxproj).

When generating the project, copy `ShiftPro/Config/ShiftPro-Info.plist` into
the app target Info.plist (or merge the keys) to enable background refresh
with `BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes`.
