# Design System Spec — Mech Buddy

Companion: [IOS26PlatformSpec](IOS26PlatformSpec.md) · [UXVisualPolishSpec](UXVisualPolishSpec.md).

## Two-layer visual model

| Layer | Materials | Brand |
|-------|-----------|-------|
| UI (tabs, toolbars, sheets, menus) | System Liquid Glass | Monochrome symbols; tint sparingly for meaning |
| Content (lists, cards, TN, pips) | Opaque / semantic surfaces that glass can sample | Signal amber, coolant teal, damage/structure reds |

Do **not** rebuild the Alpha Strike HTML’s full-screen “hull chrome” as the app chrome. The walkthrough aesthetic informs **content** readouts (TN gauge, pip tracks, phase labels), not a custom tab bar.

## Token layers

1. **Brand (content)** — `signal`, `coolant`, `damage`, `structure`
2. **Semantic** — `textPrimary`, `textSecondary`, `danger`, `success`, `warning`, `surface`, `surfaceGrouped`
3. **Game** — `armorPip`, `structurePip`, `heatLevel`, `phaseActive`, `sideA`, `sideB`

Side A is coolant. Side B is ember. Signal amber is the “do this now” color on the dock and primary actions.

Non-color cues required for hit/miss, side, phase, heat. Side A is a circle. Side B is a diamond.

## Typography

The brand display face is **SF Pro**, using system width and design variants. There is no custom font.

| Token | Face | Use |
|-------|------|-----|
| `eyebrow` | SF Pro Condensed, caption, semibold | Section labels |
| `stepTitle` | SF Pro Condensed, title2, bold | Content titles |
| `cardTitle` | SF Pro, headline | Card titles |
| `body` / `detail` | SF Pro body / subheadline | Reading text |
| `stat` | SF Pro, subheadline, medium, monospaced digits | Counts |
| `statLabel` | SF Mono, caption, medium | Stat captions |
| `readoutM` | SF Pro Rounded, title, bold, monospaced digits | Dice totals |
| `readoutL` | SF Pro Rounded, bold, 64 pt base | TN and victory numerals |

Code: `DesignSystem/Tokens/TMFont.swift`. Text styles follow Dynamic Type. `readoutL` is `TMFont.readoutL(size:)`; call sites scale a 64 pt base with `@ScaledMetric` relative to `.largeTitle` (`TNGauge`, `VictoryView`).

## Spacing, radius, motion

| Token | Values |
|-------|--------|
| `TMSpace` | 2, 4, 8, 12, 16, 24, 32 (`xxs` through `xxl`) |
| `TMRadius` | chip 8, card 16, readout 20 |
| `TMMotion` | state 0.25 s, reveal 0.35 s, phase 0.4 s, drain 0.45 s. Reduce Motion uses 0.15 s |

`TMHaptics` maps game events to `.sensoryFeedback` and reads `hapticsEnabled` (default on). Files: `DesignSystem/Tokens/TMSpace.swift`, `TMRadius.swift`, `TMMotion.swift`, `TMHaptics.swift`.

## Components (content layer)

| Component | Notes |
|-----------|-------|
| `PipTrack` | Armor/structure; large-text layout variant |
| `DiceReadout` | 2D6 |
| `TNGauge` | Large TN + odds (hero content, not glass) |
| `CoachPrompt` | Text-first coach line (`PhasePromptBanner` name in older notes) |
| `EmptyState` | Title + CTA |
| `ForceUnitCard` | Roster row content |

## Components (UI layer)

| Component | Notes |
|-----------|-------|
| Phase dock | `GlassEffectContainer` + glass controls; interactive only on tappable controls |
| Toolbars | System; monochrome |

Apply `glassEffect` **after** layout modifiers. Match container spacing to layout spacing.

## Touch targets

Minimum 44×44 pt. Primary Roll / Apply larger.

## Implemented tokens (U0)

Asset colors in `Resources/Assets.xcassets/Colors/` (plus `AccentColor` and `LaunchBackground`). Each has Any, Dark, and Increase Contrast appearances. Code: `DesignSystem/Tokens/TMColor.swift`.

| Token | Light | Dark |
|-------|-------|------|
| `brand.signal` / AccentColor | `#C98A00` | `#FFB228` |
| `brand.coolant`, `side.a` | `#1F7F93` | `#4FB0C6` |
| `brand.damage` | `#C8372D` | `#E2564A` |
| `brand.structure` | `#9E2A1F` | `#D0473A` |
| `side.b` | `#D9622B` | `#F07A3E` |
| `surface.readout` | `#F2F4F6` | `#1F262D` |
| `text.onSignal` | `#1A1D21` | `#1A1D21` |
| `text.onSide` | `#FFFFFF` | `#1A1D21` |

Side A badges use `text.onSide`. Side B in light mode uses `text.onSignal`, because white text on `#D9622B` is under 4.5:1 and dark text on that ember passes. Increase Contrast adjusts the fill so that pair stays at least 4.5:1. Signal is a fill behind `text.onSignal`.

Type, spacing, radius, motion, and haptics: `TMFont`, `TMSpace`, `TMRadius`, `TMMotion`, `TMHaptics`. Haptics default on via `AppPreferences` and the Settings toggle. `TMHaptics` reads `hapticsEnabled` and uses `.sensoryFeedback`.

## Components (U1)

| Component | File |
|-----------|------|
| `Eyebrow` | `DesignSystem/Components/Eyebrow.swift` |
| `TMCard` | `DesignSystem/Components/TMCard.swift` |
| `SideBadge` / `SideTag` | `DesignSystem/Components/SideBadge.swift` |
| `PipTrack` | `DesignSystem/Components/PipTrack.swift` |
| `HealthReadout` | `DesignSystem/Components/HealthReadout.swift` |
| `StatStrip` | `DesignSystem/Components/StatStrip.swift` |
| `StatusChip` | `DesignSystem/Components/StatusChip.swift` |
| `UnitCard` / `ForceUnitCard` | `DesignSystem/Components/UnitCard.swift` |
| `DieFacePicker` | `DesignSystem/Components/DieFacePicker.swift` |
| `DiceTray` / `DiceModeLink` | `DesignSystem/Components/DiceTray.swift` |
| `DiceReadout` | `DesignSystem/Components/DiceReadout.swift` |
| `TNGauge` | `DesignSystem/Components/TNGauge.swift` |
| `OutcomeBanner` | `DesignSystem/Components/OutcomeBanner.swift` |
| `PhaseTrack` | `DesignSystem/Components/PhaseTrack.swift` |
| `TurnCounter` | `DesignSystem/Components/TurnCounter.swift` |
| `CoachPrompt` | `DesignSystem/Components/CoachPrompt.swift` |
| `PrimaryActionButton` / `SecondaryActionButton` | `DesignSystem/Components/PrimaryActionButton.swift` |
| `PhaseDock` | `DesignSystem/Components/PhaseDock.swift` |
| `MissionCard` | `DesignSystem/Components/MissionCard.swift` |
| `ResumeCard` | `DesignSystem/Components/ResumeCard.swift` |
| `ChecklistRow` | `DesignSystem/Components/ChecklistRow.swift` |
| `EmptyState` | `DesignSystem/Components/EmptyState.swift` |
| `ErrorBanner` | `DesignSystem/Components/ErrorBanner.swift` |
| `InfoButton` / `InfoContent` | `DesignSystem/InfoButton.swift`, `DesignSystem/Components/InfoContent.swift` |
| `InlineHelp` | `DesignSystem/Components/InlineHelp.swift` |

`WeightGlyph` is not in the tree. Battle, Play, Force, Rules, Settings, and the sheets compose these components. Dice entry is `DieFacePicker` inside `DiceTray`. “Let the app roll” is `DiceModeLink`.

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-10-28 |
| Commit | `b9acebb` (tag `0.2.0`) |
| Code paths | `DesignSystem/Tokens/`, `DesignSystem/Components/`, `DesignSystem/AccessibilityID.swift`, `Resources/Assets.xcassets/Colors/`, `App/AppPreferences.swift`, `App/MechBuddyApp.swift` |
