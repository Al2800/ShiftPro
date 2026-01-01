# ShiftPro Component Standards

This document defines the visual standards for ShiftPro UI components.

## Corner Radius Hierarchy

| Size | Radius | Use Cases |
|------|--------|-----------|
| XL | 28 | Hero cards (DashboardView hero) |
| Large | 24 | Feature hero cards, modal containers |
| Standard | 22 | Section cards, content cards |
| Medium | 18 | Inner content cards, large buttons |
| Small | 14 | Calendar cells, compact buttons |
| XS | 12 | Icon backgrounds, small elements |
| XXS | 6 | Badges, chips, small tags |

**Note**: Always use `style: .continuous` for smooth curves.

```swift
// Examples:
.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))  // Standard card
.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))  // Inner card
.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))  // Button
```

## Shadow Usage

Shadows should be used sparingly and only for emphasis.

| Element | Shadow Style |
|---------|-------------|
| Hero cards | `radius: 18, x: 0, y: 12, opacity: 0.25` |
| Action buttons | `radius: 12, x: 0, y: 6, opacity: 0.2` |
| Elevated elements | `radius: 10, x: 0, y: 6, opacity: 0.3` |

**Guidelines**:
- Use `ShiftProColors.accent.opacity(...)` for shadow color
- Avoid shadows on standard content cards
- Shadows create visual hierarchy, use for CTAs and hero elements

## Spacing Hierarchy

Use `ShiftProSpacing` tokens exclusively:

| Token | Value | Use Cases |
|-------|-------|-----------|
| `extraExtraSmall` | 4pt | Tight spacing, inline elements |
| `extraSmall` | 6pt | Icon-text gaps |
| `small` | 8pt | Related elements |
| `medium` | 12pt | Standard content spacing |
| `large` | 16pt | Section spacing |
| `extraLarge` | 24pt | Major section gaps |

## Button Styles

### Primary CTA Button
```swift
.font(ShiftProTypography.headline)
.frame(maxWidth: .infinity)
.padding(.vertical, ShiftProSpacing.medium)
.background(ShiftProColors.accent)
.foregroundStyle(ShiftProColors.midnight)
.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
.shiftProPressable(scale: 0.98, opacity: 0.96, haptic: .selection)
```

### Quick Action Button
Uses QuickActionButton component with consistent styling.

## Card Backgrounds

| Context | Background |
|---------|------------|
| Page background | `ShiftProColors.background` |
| Section cards | `ShiftProColors.surface` |
| Inner/nested cards | `ShiftProColors.surfaceElevated` |

## Typography

Use `ShiftProTypography` tokens:
- `title` - Major headings
- `headline` - Section headings
- `subheadline` - Secondary headings
- `body` - Body text
- `caption` - Small labels

## Color Usage

| Context | Color |
|---------|-------|
| Primary text | `ShiftProColors.ink` |
| Secondary text | `ShiftProColors.inkSubtle` |
| Accent/CTA | `ShiftProColors.accent` |
| Success | `ShiftProColors.success` |
| Warning | `ShiftProColors.warning` |
| Error | `ShiftProColors.danger` |
| Muted accent | `ShiftProColors.accentMuted` |
