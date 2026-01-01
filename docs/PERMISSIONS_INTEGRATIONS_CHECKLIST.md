# Permissions & Integrations Regression Checklist

Use this lightweight manual checklist after changes to onboarding, settings, or any permissions-related code.

## Preconditions
- Fresh install (no prior permissions granted)
- Existing user with permissions already granted
- Existing user with permissions denied

## Calendar Permissions & Sync
- [ ] **Onboarding:** Calendar permission screen reflects current status (Not Determined/Denied/Granted)
- [ ] **Onboarding:** Request flow triggers the system prompt exactly once and updates status text after response
- [ ] **Settings > Calendar:** Status badge matches OS permission state (deny/allow)
- [ ] **Settings > Calendar:** “Request Access” is disabled when already authorized
- [ ] **Sync Toggle:** Enabling calendar sync persists preference and reflects immediately in UI
- [ ] **Sync Toggle:** Disabling calendar sync stops future syncs and leaves existing events unchanged
- [ ] **Last Sync:** Last sync timestamp updates after a successful sync
- [ ] **Event Mapping:** Creating a shift and syncing produces a calendar event with correct title/time

## Notification Permissions & Scheduling
- [ ] **Onboarding:** Notification permission screen reflects current status (Not Determined/Denied/Granted)
- [ ] **Onboarding:** Request flow triggers the system prompt and updates UI status after response
- [ ] **Settings > Notifications:** Status badge matches OS permission state
- [ ] **Settings > Notifications:** “Request Access” is disabled when already authorized
- [ ] **Notification Toggles:** Enable/disable settings persist and reflect after app relaunch
- [ ] **Scheduling:** Enabling shift reminders schedules a notification for the next upcoming shift
- [ ] **Reschedule:** Editing or deleting a shift updates or removes its scheduled notifications
- [ ] **Denied State:** When permission is denied, UI shows actionable guidance to enable in Settings

## General Permission UX
- [ ] **Single Source of Truth:** Permission status is consistent across onboarding and settings
- [ ] **No Phantom States:** UI never shows “Granted” if OS permissions are denied
- [ ] **Error Handling:** Permission request failures show a user-visible message (if applicable)
