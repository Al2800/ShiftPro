# Copy Normalization Audit (Shift Worker Language)

Date: 2026-01-01

## Scope
Audited onboarding, dashboard, schedule, settings, and supporting UI copy for law‑enforcement specific terms.

## Search Terms
- precinct, officer, patrol, badge, sergeant, captain, squad, unit

## Findings
- No law‑enforcement‑specific copy remains in UI strings.
- Profile field labels are neutralized: **Workplace**, **Job Title**, **Employee ID**.
- Example shift labels and locations use neutral terms (e.g., “Day Shift”, “Training Center”, “Main Site”).

## Screens Reviewed
- Onboarding: Welcome, Permissions, Profile, Pay Period, Pattern Discovery, Calendar, Completion
- Dashboard
- Schedule
- Hours
- Settings (Profile, Notifications, Calendar, Security, Privacy, Premium)

## Notes
- `UserProfile` model retains legacy attribute names for migration only; UI labels are neutral.
- System icons containing the word “badge” (SF Symbols) are visual assets and not user‑facing copy.

## Action Items
- None required at this time. Continue using neutral terminology for any new UI strings.
