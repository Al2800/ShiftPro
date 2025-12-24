# App Store Review Preparation Guide

## Demo Account

For App Review testing, use the following:

### Test Credentials
No login required - app works with local data.

### Demo Data Setup
The app includes a "Demo Mode" that can be enabled via launch arguments:
- `DemoMode=true`: Pre-populates sample shift data
- Creates example shifts, patterns, and pay periods

## Feature Walkthrough for Reviewers

### Core Features (Free Tier)

#### 1. Shift Logging
- Tap "Add Shift" to create a new shift
- Set date, start/end times, breaks
- Save to local storage

#### 2. Dashboard
- View current/upcoming shifts
- See hours summary
- Access quick actions

#### 3. Basic Hours Tracking
- View hours for current pay period
- See rate breakdown
- Check progress toward overtime

#### 4. Calendar View
- Navigate weekly/monthly views
- Tap dates to see shift details

### Premium Features

#### 1. Advanced Patterns
- Navigate: Settings > Patterns > Templates
- Select from pre-built rotations
- Apply to schedule

#### 2. Calendar Sync
- Navigate: Settings > Calendar
- Enable sync toggle
- Select target calendar
- Requires calendar permission

#### 3. Export Features
- Navigate: Settings > Export
- Choose format (CSV, PDF, JSON)
- Share via system share sheet

#### 4. Unlimited History
- All shifts retained indefinitely
- Full search across history

## In-App Purchase Testing

### Subscription Products
- Monthly: $4.99 (com.shiftpro.premium.monthly)
- Annual: $39.99 (com.shiftpro.premium.annual)

### Testing Instructions
1. Use sandbox account for purchase testing
2. Subscriptions auto-renew at accelerated rate in sandbox
3. Subscription status visible in Settings > Subscription

## Permission Requests

The app may request the following permissions:

### Calendar Access (Optional)
- **When**: User enables calendar sync in Settings
- **Purpose**: Sync shifts to iOS Calendar
- **NSCalendarsUsageDescription**: "ShiftPro needs calendar access to sync your work shifts to your calendar."

### Notifications (Optional)
- **When**: User enables notifications in onboarding or Settings
- **Purpose**: Shift reminders and overtime warnings
- **NSUserNotificationUsageDescription**: "ShiftPro uses notifications to remind you of upcoming shifts and important schedule changes."

### Face ID / Touch ID (Optional)
- **When**: User enables biometric lock in Settings
- **Purpose**: Secure app access
- **NSFaceIDUsageDescription**: "ShiftPro uses Face ID to secure your work schedule data."

## Data Privacy

### Data Collection
- All data stored locally on device
- Optional iCloud sync (user-controlled)
- No analytics or tracking SDKs
- No data sent to third parties

### Privacy Label Configuration
- Data Used to Track You: None
- Data Linked to You: None (or iCloud identifier if sync enabled)
- Data Not Linked to You: Usage Data (crashes only via Apple)

## Known Limitations

### Platform Requirements
- iOS 17.0 or later
- iPhone and iPad compatible
- Some features require additional permissions

### Intentional Design Decisions
- Offline-first: Works without internet
- No account required: Privacy-focused
- Local storage: User controls their data

## Technical Notes

### SwiftUI + SwiftData
- Built with modern Apple frameworks
- Data persisted via SwiftData
- Responsive design for all screen sizes

### Performance
- Cold launch < 1.5s
- UI interactions < 100ms
- Efficient battery usage

### Accessibility
- Full VoiceOver support
- Dynamic Type support
- High contrast mode compatible
- Reduced motion respected

## Frequently Asked Questions

### Q: Why does the app need calendar access?
A: Calendar sync is an optional premium feature that automatically creates calendar events for your shifts. You can use the app fully without granting calendar access.

### Q: Is an account required?
A: No. The app works entirely with local data. iCloud sync is optional and uses your existing Apple ID.

### Q: What happens to my data if I uninstall?
A: Data is stored locally and will be deleted if you uninstall. Enable iCloud sync to preserve data across devices and reinstalls.

### Q: How accurate are pay calculations?
A: Calculations are based on user-entered data and should be used for estimates only. Official pay records should come from your employer.

## Contact Information

### App Support
- Email: support@shiftpro.app
- Response time: 24-48 hours

### Developer Contact
- Company: ShiftPro LLC
- Location: United States
- Technical Lead: Available for reviewer questions

## Compliance Notes

### App Store Guidelines
- Reviewed against current App Store Review Guidelines
- No private API usage
- No cryptocurrency/NFT functionality
- No gambling features
- COPPA compliant (18+ target audience)

### Legal
- Terms of Service: https://shiftpro.app/terms
- Privacy Policy: https://shiftpro.app/privacy
- EULA: Standard Apple EULA

---

*Last updated: December 2025*
*App Version: 1.0.0*
*Build: 1*
