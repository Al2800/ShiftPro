# ShiftProNotificationExtension

This folder contains the Notification Service Extension template used for rich
notifications. Add it as an app extension target in the generated Xcode project.

Steps (Xcode 15+ on macOS):
1. File > New > Target > Notification Service Extension.
2. Replace the generated `NotificationService.swift` with the file in this folder.
3. Add the extension target to the app's embedded content.
4. Ensure notification categories match `NotificationScheduler` identifiers.
