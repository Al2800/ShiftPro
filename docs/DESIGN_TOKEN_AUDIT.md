# Design Token Audit Report

Generated: 2026-01-01

## Overview

This audit identifies inconsistencies in ShiftPro's use of design tokens (ShiftProColors, ShiftProTypography, ShiftProSpacing) vs system defaults.

## Summary of Findings

| Category | Violations | Severity |
|----------|------------|----------|
| System Colors | 11 | High |
| System Fonts | 30+ | High |
| System Foreground Styles | 15 | Medium |
| Hardcoded Spacing | 40+ | Medium |

## Detailed Findings

### 1. System Colors (Should use ShiftProColors)

**AnalyticsDashboard.swift** - 11 violations:
- Line 31: `Color(uiColor: .systemGroupedBackground)` → `ShiftProColors.background`
- Line 125, 169, 190, 249: `Color(uiColor: .secondarySystemGroupedBackground)` → `ShiftProColors.surface`
- Line 146, 343: `Color(uiColor: .tertiarySystemGroupedBackground)` → `ShiftProColors.surfaceElevated`
- Lines 210, 224, 238: `Color.accentColor.gradient` → `ShiftProColors.accent.gradient`
- Line 339: `Color.accentColor` → `ShiftProColors.accent`

### 2. System Fonts (Should use ShiftProTypography)

**AnalyticsDashboard.swift** - 12 violations:
- Lines 84, 155, 178, 199: `.font(.headline)` → `.font(ShiftProTypography.headline)`
- Line 138: `.font(.title2)` → `.font(ShiftProTypography.title)` or custom
- Lines 142, 330, 338: `.font(.caption)` → `.font(ShiftProTypography.caption)`
- Lines 159, 326, 374, 382: `.font(.subheadline)` → `.font(ShiftProTypography.subheadline)`

**InsightsView.swift** - 10 violations:
- Line 37: `.font(.largeTitle)` → `.font(ShiftProTypography.title)` or custom
- Lines 41, 70: `.font(.headline)` → `.font(ShiftProTypography.headline)`
- Lines 44, 85, 103: `.font(.subheadline)` → `.font(ShiftProTypography.subheadline)`
- Line 61: `.font(.title2)` → custom or `.font(ShiftProTypography.title)`
- Lines 78, 94: `.font(.caption)` → `.font(ShiftProTypography.caption)`

**TrendChartsView.swift** - 6 violations:
- Lines 39, 74, 100, 173: `.font(.headline)` → `.font(ShiftProTypography.headline)`
- Line 126: `.font(.largeTitle)` → custom
- Lines 130: `.font(.subheadline)` → `.font(ShiftProTypography.subheadline)`

**PrivacySettingsView.swift** - 1 violation:
- Line 83: `.font(.caption)` → `.font(ShiftProTypography.caption)`

### 3. System Foreground Styles (Should use ShiftProColors)

**InsightsView.swift** - 5 violations:
- Lines 38, 45, 79, 86, 96: `.foregroundStyle(.secondary)` → `.foregroundStyle(ShiftProColors.inkSubtle)`

**TrendChartsView.swift** - 5 violations:
- Lines 127, 131, 180, 200, 210: `.foregroundStyle(.secondary)` → `.foregroundStyle(ShiftProColors.inkSubtle)`

**AnalyticsDashboard.swift** - 4 violations:
- Lines 143, 160, 331: `.foregroundStyle(.secondary)` → `.foregroundStyle(ShiftProColors.inkSubtle)`

**ShiftFormView.swift** - 1 violation:
- Line 127: `.foregroundStyle(.secondary)` → `.foregroundStyle(ShiftProColors.inkSubtle)`

### 4. Hardcoded Spacing (Should use ShiftProSpacing)

**Onboarding Views** - Multiple files use hardcoded values:
- `spacing: 16` → `ShiftProSpacing.large`
- `spacing: 12` → `ShiftProSpacing.medium`
- `spacing: 8` → `ShiftProSpacing.small`
- `spacing: 4` → `ShiftProSpacing.extraExtraSmall`

Files affected:
- CalendarSetupView.swift
- PayPeriodSetupView.swift
- ProfileSetupView.swift
- CompletionView.swift
- OnboardingView.swift
- WelcomeView.swift
- PermissionsView.swift
- PatternDiscoveryView.swift

**Analytics Views** - Extensive hardcoded spacing:
- AnalyticsDashboard.swift: 10+ instances
- InsightsView.swift: 7+ instances
- TrendChartsView.swift: 10+ instances

**Export Views**:
- ExportOptionsView.swift: 1 instance
- ImportView.swift: 2 instances

## Recommended Actions

### Priority 1: Analytics Views (Highest Impact)
1. Update AnalyticsDashboard.swift with ShiftProColors, ShiftProTypography, ShiftProSpacing
2. Update InsightsView.swift with design tokens
3. Update TrendChartsView.swift with design tokens

### Priority 2: Onboarding Views
1. Replace all hardcoded spacing with ShiftProSpacing tokens
2. Verify typography and color usage

### Priority 3: Export Views
1. Minor spacing fixes in ExportOptionsView and ImportView

### Priority 4: Settings Views
1. Fix PrivacySettingsView.swift typography

## Token Reference

| System Default | ShiftPro Token |
|----------------|----------------|
| `.systemGroupedBackground` | `ShiftProColors.background` |
| `.secondarySystemGroupedBackground` | `ShiftProColors.surface` |
| `.tertiarySystemGroupedBackground` | `ShiftProColors.surfaceElevated` |
| `Color.accentColor` | `ShiftProColors.accent` |
| `.foregroundStyle(.secondary)` | `.foregroundStyle(ShiftProColors.inkSubtle)` |
| `.font(.headline)` | `.font(ShiftProTypography.headline)` |
| `.font(.subheadline)` | `.font(ShiftProTypography.subheadline)` |
| `.font(.body)` | `.font(ShiftProTypography.body)` |
| `.font(.caption)` | `.font(ShiftProTypography.caption)` |
| `spacing: 16` | `ShiftProSpacing.large` |
| `spacing: 12` | `ShiftProSpacing.medium` |
| `spacing: 8` | `ShiftProSpacing.small` |
| `spacing: 4` | `ShiftProSpacing.extraExtraSmall` |
