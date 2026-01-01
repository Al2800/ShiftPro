# ShiftPro - Screen Inventory and IA Map

## Current Screen Inventory (from codebase)
### Root / Navigation
- `ContentView` (onboarding gate)
- `MainTabView` (tab bar)

### Onboarding
- `OnboardingView`
- `WelcomeView`
- `PermissionsView`
- `ProfileSetupView`
- `PayPeriodSetupView`
- `PatternDiscoveryView`
- `CalendarSetupView`
- `CompletionView`

### Dashboard
- `DashboardView`

### Schedule
- `ScheduleView`

### Hours
- `HoursView`
- `HoursDashboard`
- `PayPeriodDetailView`
- `RateMultiplierView`

### Patterns
- `PatternLibraryView`
- `PatternEditorView`
- `PatternPreviewView`

### Analytics
- `AnalyticsDashboard`
- `InsightsView`
- `TrendChartsView`

### Export / Import
- `ExportOptionsView`
- `ImportView`

### Settings
- `SettingsView`
- `NotificationSettingsView`
- `CalendarSettingsView`
- `SecuritySettingsView`
- `PrivacySettingsView`
- `SubscriptionSettingsView`
- `PremiumView`

### Paywall
- `PaywallView`

## Proposed Information Architecture (IA)

### Primary Navigation (Tab Bar)
1) **Dashboard**
   - Current shift status
   - Next/upcoming shifts
   - Quick actions (start/end shift, add shift, log break)
   - Pay period summary card (link to Hours)

2) **Schedule**
   - Calendar (month/week)
   - Shift list
   - Add/Edit shift (modal)

3) **Hours**
   - Pay period overview
   - Rate multipliers
   - Insights + trends (Analytics)
   - Export entry point

4) **Patterns**
   - Pattern library
   - Pattern editor
   - Pattern preview

5) **Settings**
   - Profile
   - Notifications
   - Calendar Sync
   - Security & Privacy
   - Import/Export
   - Subscription / Premium

### Secondary / Detail Navigation
- **Shift Detail**: from Dashboard or Schedule (modal or push)
- **Pay Period Detail**: from Hours
- **Export Options**: from Hours or Settings
- **Import**: from Settings
- **Paywall**: modal when gated feature accessed

### Onboarding Flow (Pre-Tab)
- Welcome -> Permissions -> Profile -> Pay Period -> Pattern Discovery -> Calendar -> Completion

## IA Notes and Gaps
- **Analytics** should live inside Hours (not a separate tab) to reduce tab complexity.
- **Patterns** is a core workflow for rotating schedules; it should be top-level (tab) rather than buried in Settings.
- **Import/Export** should be accessible from Settings and linked from Hours export actions.
- **Shift CRUD** should be reachable within 1-2 taps from Dashboard and Schedule.
- **Neutral terminology** should be applied across all screens (no role-specific labels).
