# Accessibility Contrast Audit (2026-01-03)

Checked core text colors against primary surfaces in light and dark modes.
Ratios use WCAG contrast (L1 + 0.05) / (L2 + 0.05). Target is 4.5+ for normal text.

## Light mode
- ink on background: 15.16
- ink on surface: 16.59
- inkSubtle on background: 5.32
- inkSubtle on surface: 5.81
- accent on background: 6.86
- success on background: 5.15
- warning on background: 4.61
- danger on background: 5.58
- fog on background: 4.57

## Dark mode
- ink on background: 15.62
- ink on surface: 13.32
- inkSubtle on background: 9.33
- inkSubtle on surface: 7.95
- accent on background: 6.15
- success on background: 8.28
- warning on background: 11.25
- danger on background: 6.22
- fog on background: 13.19

## Notes
- Adjusted light-mode success, warning, and fog to meet 4.5+ on background.
- All listed combinations meet 4.5+ after adjustments.
