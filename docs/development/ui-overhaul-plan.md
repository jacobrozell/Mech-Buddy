# UI overhaul plan — Mech Buddy

**Status:** Proposal (not yet authoritative). Promote pieces into `specs/` per [SpecGovernance](../../specs/SpecGovernance.md) as they are accepted.
**Written:** 2026-10-28 against `main` @ `bd4cb5e`.
**Goal:** Move Mech Buddy from "working prototype built from stock `List` rows" to "polished, production-grade iOS 26 app" without breaking the Ridge Line vertical slice, the accessibility-identifier contract, or the platform rules in [IOS26PlatformSpec](../../specs/IOS26PlatformSpec.md).

---

## Table of contents

1. [How to use this plan](#1-how-to-use-this-plan)
2. [Diagnosis: why the app reads as a prototype today](#2-diagnosis-why-the-app-reads-as-a-prototype-today)
3. [Design direction](#3-design-direction)
4. [Foundations: tokens, type, spacing, motion, haptics](#4-foundations-tokens-type-spacing-motion-haptics)
5. [Component library](#5-component-library)
6. [Screen-by-screen overhaul](#6-screen-by-screen-overhaul)
   - 6.1 [App shell, icon, launch](#61-app-shell-icon-launch)
   - 6.2 [Play home](#62-play-home-playhome--asmodehome)
   - 6.3 [Classic coming soon](#63-classic-coming-soon)
   - 6.4 [Getting Started](#64-getting-started-asgettingstarted)
   - 6.5 [How to play Ridge Line](#65-how-to-play-ridge-line-ashowtoplay)
   - 6.6 [Force tab](#66-force-tab-forceaslist)
   - 6.7 [Rules home](#67-rules-home-ruleshome)
   - 6.8 [Rules topic detail](#68-rules-topic-detail)
   - 6.9 [Settings](#69-settings-settingshome)
   - 6.10 [Battle cover shell (nav bar, menu, dock)](#610-battle-cover-shell)
   - 6.11 [Table setup](#611-table-setup-asridgetableprep)
   - 6.12 [Place the miniatures](#612-place-the-miniatures)
   - 6.13 [Initiative (roll dice)](#613-initiative-roll-dice)
   - 6.14 [Movement](#614-movement)
   - 6.15 [Combat (shoot)](#615-combat-shoot)
   - 6.16 [Pending critical state](#616-pending-critical-state)
   - 6.17 [Clean up (end phase)](#617-clean-up-end-phase)
   - 6.18 [Victory](#618-victory-asvictory)
   - 6.19 [Shot solver sheet](#619-shot-solver-sheet-assator)
   - 6.20 [Critical hit sheet](#620-critical-hit-sheet-ascrit)
   - 6.21 [Unit Focus sheet](#621-unit-focus-sheet-asunitfocus)
   - 6.22 [What just happened (event log)](#622-what-just-happened-event-log)
   - 6.23 [Dialogs, alerts, errors, loading](#623-dialogs-alerts-errors-loading)
7. [Cross-cutting: accessibility, Dynamic Type, dark mode, iPad, landscape](#7-cross-cutting-concerns)
8. [Copy and voice pass](#8-copy-and-voice-pass)
9. [Code architecture changes that the UI work needs](#9-code-architecture-changes)
10. [Testing and verification](#10-testing-and-verification)
11. [Phased rollout](#11-phased-rollout)
12. [Spec and doc updates required](#12-spec-and-doc-updates-required)
13. [Risks and mitigations](#13-risks-and-mitigations)
14. [Open decisions for the owner](#14-open-decisions-for-the-owner)
15. [Quick wins (can land first, in a day)](#15-quick-wins)
16. [Appendix: identifier preservation table](#16-appendix-identifier-preservation-table)

---

## 1. How to use this plan

- **Specs still win.** Everything below is designed to stay inside the rules already locked in `specs/`: system Liquid Glass chrome, brand only in content, one brand moment per screen ([UXVisualPolishSpec § Per-screen brand budget](../../specs/UXVisualPolishSpec.md)), non-color cues for hit/miss/side/phase, Dynamic Type through AXXXL, 44 pt targets, physical dice primary, one-device hotseat. Where this plan *does* want a spec change, it says so explicitly in [§12](#12-spec-and-doc-updates-required).
- **Each screen section** has the same shape: *Today* (what the code does, with file/line references), *Problems*, *Target* (layout wireframe + behavior), *Components used*, *Motion & haptics*, *Accessibility*, *Acceptance criteria*. Wireframes are ASCII and describe hierarchy, not pixel positions.
- **Do it in the order in [§11](#11-phased-rollout).** Foundations and components first, then the battle screen (where players spend 90% of a session), then sheets, then the outer tabs.
- **Never rename an existing accessibility identifier** without updating the tests and [AccessibilitySpec](../../specs/AccessibilitySpec.md) in the same PR. [§16](#16-appendix-identifier-preservation-table) lists every identifier in the code today.
- **Domain stays untouched** unless a section explicitly calls out a domain addition (there are three small ones: event kinds, unit weight class, and a hit-odds helper exposed to the UI — see [§9](#9-code-architecture-changes)).

---

## 2. Diagnosis: why the app reads as a prototype today

These are the concrete reasons, verified in code, that the app looks "default SwiftUI" rather than "shipped product".

### 2.1 Every screen is a stock inset-grouped `List`

Play, Getting Started, How to play, Force, Rules, Rules detail, Settings, Table setup, the battle table itself, the event log, and Unit Focus are all `List { Section { … } }`. The two sheets that are not lists are `Form`s (`CombatSolverSheet.swift:75`, `BattleFlowView.swift:955`). The result is a uniform grey-card look on every surface with no visual hierarchy between "the thing you should do now" and "reference text".

The battle table is the clearest case: the whole live game is **one `Section`** (`BattleFlowView.swift:322-338`) containing a `.headline` text line and then a vertical run of mixed text, buttons, pickers and unit rows. There is no header, no phase indicator, no grouping by side, and no visual difference between the active side's units and the opponent's.

### 2.2 The brand palette exists but is never used

`DesignSystem/MechBuddyColors.swift` defines `signal`, `coolant`, `damage`, `structure` — and **nothing references it**. Color in the app today is:

| Where | Color used | Problem |
|-------|-----------|---------|
| Initiative tie hint (`BattleFlowView.swift:826`) | `.orange` | System orange, not a token |
| Die face selected (`BattleFlowView.swift:1198-1201`) | `Color.accentColor` bg + `Color.white` fg | White on amber `#F3B228` is ~1.9:1 contrast — fails WCAG AA |
| Shot solver warnings (`CombatSolverSheet.swift:79, 235, 375`) | `.orange` | Not a token; no icon |
| Miss (`CombatSolverSheet.swift:239, 272`) | `.red` | Not a token |
| Hit (`CombatSolverSheet.swift:265`) | `.primary` | A hit — the best moment in the game — is rendered in plain text color |
| Load errors (`PlayHomeView.swift:73, 336`) | `.red` text in a list row | Reads as a crash, not a recoverable state |
| Pips (`UnitFocusSheet.swift:151`) | `Color.primary` / `secondary.opacity(0.25)` | Armor and structure look identical |

The DesignSystemSpec token layers (brand → semantic → game) are entirely unimplemented.

### 2.3 Numbers are shown as sentences instead of readouts

Health is "Armor 3/5" and "Structure 2/5" as two lines of `.caption` text in every unit row (`BattleFlowView.swift:551-556`, `PlayHomeView.swift:348-353`). The only pip track lives in Unit Focus. A player at arm's length cannot glance at the phone and see who is hurt. The UX spec's MVP item `ux.pipTrack` ("arm's-length pip tracks with counts") is not met on the battle screen, which is where it matters most.

The target number in the shot solver is a 44 pt rounded `"\(tn)+"` (`CombatSolverSheet.swift:248`) — good start — but there is no odds readout, even though the SATOR spec defines the odds table and `ux.tnHero` asks for "large TN numeral + odds bar".

### 2.4 Side identity is text-only and inconsistent

"Side A" / "Side B" (`Identifiers.swift:21-26`) is the only side cue anywhere. No badge, no color, no shape. The specs disagree with the code on the name itself: HotseatSpec and UXVisualPolishSpec say "Lance A / Lance B", the code says "Side A / Side B". `ux.sideIdentity` (MVP) is not met.

### 2.5 No phase indicator, no turn readout

The turn and phase exist only inside the headline string `"Turn 2 of 6 · Side B shoots"` (`BattleFlowView.swift:375-395`). There is no phase track (Roll → Move → Shoot → Clean up), so a new player cannot see where they are in the turn or what comes next. `ux.phasePrompt` (MVP) asks for "phase selected state not color-only" — there is no phase state at all.

### 2.6 The bottom action bar is not the spec'd glass dock

The action area (`BattleFlowView.swift:340-371`) is an `HStack` of `.bordered` / `.borderedProminent` buttons on `.background(.bar)`. The spec (`ux.phaseDockGlass`, BattleTableSpec § Phase dock) calls for a `GlassEffectContainer` with glass controls. No `glassEffect` exists anywhere in the codebase.

### 2.7 Dice entry looks like a number pad, not dice

`DiceFaces` (`BattleFlowView.swift:1180-1212`) draws six grey rounded rectangles with numerals `1`…`6`. SF Symbols ships `die.face.1` … `die.face.6` (and `.fill` variants). Using real die faces is the single cheapest way to make the app *feel* like a tabletop tool.

### 2.8 Zero motion and zero haptics

No `withAnimation`, `.animation`, `contentTransition`, `symbolEffect`, or `sensoryFeedback` anywhere. Phase changes, a hit landing, pips draining, a 'Mech being wrecked — all are instant text swaps. MVP items `ux.motionDice`, `ux.motionPhase`, `ux.motionApply`, and `ux.hitMiss` (haptics) are unmet. There are also no `AccessibilityNotification.Announcement` posts, so VoiceOver users are not told when the phase or active side changes (required by BattleTableSpec § Accessibility and HotseatSpec).

### 2.9 Information is hidden behind popovers

`InfoButton` is used 12 times across the features. Some uses are right (glossary terms), but several hide **primary** information or navigation:

- The only way to reach Getting Started and How to play from Play is *inside the Ridge Line info popover* (`PlayHomeView.swift:132-152`), which then needs a 350 ms `Task.sleep` hack to open a sheet after the popover closes (`PlayHomeView.swift:171-186`).
- The Unit Focus "Card" stats (Skill, Move, TMM, Damage) are hidden in a popover (`UnitFocusSheet.swift` lines 21-44) instead of being the header of the sheet.
- "How you win" on table setup is a popover instead of a visible line.

### 2.10 Empty, error, loading and victory states are generic

- Victory is a `ContentUnavailableView` (`BattleFlowView.swift:908`) — the system's *empty state* component — so the payoff of a 40-minute game looks like "no results".
- Loading is a bare `ProgressView("Loading the mission…")`.
- Errors are red text rows or a generic "Something went wrong" alert.
- The event log is the last 12 raw strings (`BattleFlowView.swift:592`).

### 2.11 Missing product surfaces

- **No app icon** — `AppIcon.appiconset/Contents.json` declares a 1024 slot with no image.
- **Force tab is a placeholder** (`ForcePlaceholderView`).
- **Settings** has only delete + links; no Appearance, Haptics, or "About" (SettingsSpec lists those).
- No first-launch intro (AppShellSpec § Onboarding).

### 2.12 Copy inconsistencies that read as unfinished

- Straight vs curly apostrophes mixed: `'Mechs` (`BattleFlowView.swift:121, 130`; `HowToPlayRidgeLineView.swift` multiple) vs `’Mechs` elsewhere.
- Button verbs vary for the same concept: "Leave" / "Back to Play" / "Done"; "Quit and discard this game" / "Quit and discard".
- "Tap to record…" is a `MovementMode.displayName` (`Identifiers.swift:64`) — UI instruction text living in the domain.
- Move button label "Still" vs record label "Stood still" vs rules "Stand still".

### 2.13 Structural issues that block polish

- `BattleFlowView.swift` is 1,212 lines holding seven views and four helper types; polishing it in place will be painful and conflict-prone.
- `winningSummary` and `tableSteps(for:)` re-decode bundled JSON **on every body evaluation** (`BattleFlowView.swift:299-319`).
- `shotsThisTurn` orders shots by searching `eventLog` for messages that start with the unit's name (`BattleFlowView.swift:475`) — fragile string coupling that a styled shot feed will make worse.
- No SwiftUI `#Preview`s anywhere, so every visual change requires running a full match in the simulator.

---

## 3. Design direction

### 3.1 One-line concept

**"Tactical readout on Liquid Glass."** System iOS 26 chrome (tab bar, nav bars, sheets, menus, dock glass) wrapped around content that borrows the walkthrough HTML's instrument-panel language — condensed uppercase eyebrows, monospaced numerals, amber signal highlights, pip tracks, a phase track — rendered with system fonts so it scales with Dynamic Type.

### 3.2 Principles (ranked; earlier wins on conflict)

1. **Glanceable at arm's length.** The phone sits on a table between two players. The current step, whose turn it is, the next button, and each 'Mech's health must read from ~60 cm in a bright room. This dictates big numerals, pip tracks, high-contrast tokens and a persistent dock.
2. **One obvious next action.** `BattleCoach` already decides the single primary action; the UI's job is to make that one button unmistakable and everything else visibly secondary.
3. **Content-first, system chrome.** No custom tab bar, no custom nav bar, no `presentationBackground`. Brand lives in content cards and readouts (IOS26PlatformSpec § Two-layer interface).
4. **One brand moment per screen.** The UX spec's budget table is the guardrail: TN gauge on the solver, phase prompt on battle, pips on Force/Unit Focus, mission card on Play, nothing loud on Rules.
5. **Every state has a non-color cue.** Side = color + letter badge + shape. Hit/miss = color + icon + word + haptic. Phase = highlight + checkmark + label. Damaged pip = color + hollow/strike shape.
6. **Calm motion.** Short, purposeful transitions on state change; nothing loops; everything degrades under Reduce Motion.
7. **Teach in place, don't hide.** Use visible one-line coach text and inline disclosure; reserve popovers for glossary terms.

### 3.3 Mood references (for whoever designs the icon and marketing)

- Walkthrough HTML (`FutureIdeas/alpha-strike-walkthrough.html`): hull `#1B2026`, plate `#242C35`, readout `#DAE3EA`, signal `#FFB228`, coolant `#4FB0C6`, damage `#E2564A`, struct `#C0392B`; Chakra Petch display, IBM Plex Mono readouts. We translate this to tokens with light/dark variants (§4.1) and to SF Pro width/design variants (§4.2), not custom fonts.
- Apple first-party "instrument" apps on iOS 26 (Weather, Fitness, Stocks) for how big numerals and system glass coexist.
- Board-game companion apps with strong turn trackers (phase track + single CTA pattern).

### 3.4 What we are explicitly *not* doing

Inherited from UXVisualPolishSpec non-goals, restated so nobody drifts:

- No full-bleed cockpit chrome, scanlines, neon panels, particle/heat-haze effects.
- No licensed 'Mech art, no scanned record sheets. Weight-class glyphs (§5.17) are abstract.
- No custom tab bar or nav bar painting; no UIKit appearance proxies.
- No custom display font in 1.0 (SF Pro Condensed/Expanded/Rounded/Mono cover it). `ux.customDisplayFont` stays "Later".

---

## 4. Foundations: tokens, type, spacing, motion, haptics

All of this lives in `DesignSystem/` (already compiled into the app target via `project.yml`). Split into one file per concern.

### 4.1 Color tokens

Replace `MechBuddyColors.swift` with an asset-catalog-backed token set. Every color gets **Any / Dark** appearances and an **Increase Contrast** variant in `Assets.xcassets/Colors/`. Code accesses them via a single namespace so call sites read as intent, not hue.

```
DesignSystem/
  Tokens/
    TMColor.swift        // namespace + ShapeStyle conveniences
    TMFont.swift
    TMSpace.swift
    TMRadius.swift
    TMMotion.swift
    TMHaptics.swift
Resources/Assets.xcassets/Colors/
    brand.signal, brand.coolant, brand.damage, brand.structure
    side.a, side.a.fill, side.b, side.b.fill
    pip.armor, pip.structure, pip.empty, pip.lost
    state.success, state.warning, state.danger, state.info
    surface.card, surface.cardRaised, surface.readout
    text.onSignal, text.onSide
```

**Layer 1 — Brand (content only)**

| Token | Light | Dark | Notes |
|-------|-------|------|-------|
| `brand.signal` | `#C98A00` | `#FFB228` | Darker amber in light mode so text-on-white passes AA. Also the `AccentColor`. |
| `brand.coolant` | `#1F7F93` | `#4FB0C6` | |
| `brand.damage` | `#C8372D` | `#E2564A` | |
| `brand.structure` | `#9E2A1F` | `#D0473A` | Lifted in dark so it separates from damage on charcoal. |

**Layer 2 — Semantic**

| Token | Maps to | Usage |
|-------|---------|-------|
| `state.success` | system green, tuned | Hit outcome, checklist done |
| `state.warning` | `brand.signal` | Tie, "some 'Mechs haven't shot", zero-damage shot |
| `state.danger` | `brand.damage` | Miss, destructive, wrecked |
| `state.info` | `brand.coolant` | Coach tips |
| `surface.card` | `secondarySystemGroupedBackground` | Default card |
| `surface.cardRaised` | card + 4% tint of the side color | Active side's unit cards |
| `surface.readout` | `#F2F4F6` / `#1F262D` | TN gauge, dice tray, stat strips (the "plate" from the HTML) |
| `text.onSignal` | `#1A1D21` both modes | Text on amber fills — **never white** (fixes the 1.9:1 die-face bug) |

**Layer 3 — Game**

| Token | Usage | Non-color cue |
|-------|-------|---------------|
| `side.a` / `side.a.fill` | Side A badge, card edge, dock tint when A is active | Letter "A" + circle badge shape |
| `side.b` / `side.b.fill` | Side B | Letter "B" + diamond (rotated square) badge shape |
| `pip.armor` | Armor pips (filled) | Square pip |
| `pip.structure` | Structure pips (filled) | Square pip on a second row, labelled |
| `pip.empty` | Not-yet-lost capacity in a different track state | — |
| `pip.lost` | Lost pip | Hollow outline + diagonal strike |
| `phase.active` | Current phase segment | Bold label + filled segment |
| `phase.done` | Completed phase segment | Checkmark glyph |

Side color recommendation and alternatives are an open decision ([§14 D2](#14-open-decisions-for-the-owner)). Default proposal: **Side A = coolant teal-blue, Side B = a warm ember orange (`#D9622B` / `#F07A3E`)**; signal amber stays reserved for "the thing to do now". Blue-vs-orange is the most robust pairing under all three common color-vision deficiencies, and the letter + shape badge covers the rest.

**Rules**

- Ban raw `.red`, `.orange`, `.green`, `Color.white`, `Color.accentColor` in `Features/` with a SwiftLint custom rule (`custom_rules: no_raw_colors`), once migration is done.
- Every fill that carries text gets a paired `text.on*` token, checked for ≥ 4.5:1 (≥ 3:1 for ≥ 24 pt bold numerals) in both appearances and with Increase Contrast.

### 4.2 Typography

All system fonts, all Dynamic Type. Brand character comes from **width** and **design** variants, which SF Pro supports natively and which scale.

| Token | Definition | Usage |
|-------|-----------|-------|
| `TMFont.eyebrow` | `.caption.weight(.semibold).width(.condensed)` + `.textCase(.uppercase)` + `tracking(0.8)` | Section labels ("SIDE A — SHOOTING NOW", "IF THIS HITS"). Replaces the many `.caption.weight(.semibold).foregroundStyle(.secondary)` lines. |
| `TMFont.stepTitle` | `.title2.weight(.bold).width(.condensed)` | Battle step headline ("SIDE B SHOOTS") |
| `TMFont.cardTitle` | `.headline` | Unit name, card titles |
| `TMFont.body` | `.body` | Coach text |
| `TMFont.detail` | `.subheadline` + secondary | Supporting lines |
| `TMFont.stat` | `.subheadline.monospacedDigit().weight(.medium)` with `design: .monospaced` for labels | Stat strips (MV 10″ · TMM 2 · S2 M2 L1) |
| `TMFont.readoutL` | `.system(size: 64, weight: .bold, design: .rounded)` via `@ScaledMetric(relativeTo: .largeTitle)` | TN gauge numeral, dice total |
| `TMFont.readoutM` | `.system(.title, design: .rounded).weight(.bold).monospacedDigit()` | Turn counter, initiative totals |

Rules:
- Numerals that change in place (totals, pips counts, turn) always `.monospacedDigit()` + `.contentTransition(.numericText())` so they don't jitter.
- Use `.fontWidth(.condensed)` only on short uppercase labels; never on paragraph text.
- At accessibility sizes, eyebrows drop `.condensed` (wider text wraps better) — handled inside the `Eyebrow` component via `@Environment(\.dynamicTypeSize)`.

### 4.3 Spacing, radius, elevation

| Token | Value | Notes |
|-------|-------|-------|
| `TMSpace.xxs` … `xl` | 2, 4, 8, 12, 16, 24, 32 | 4-pt grid. List row insets standardize on 16. |
| `TMRadius.chip` | 8 | Status chips, die faces |
| `TMRadius.card` | 16 (continuous) | Unit cards, mission card |
| `TMRadius.readout` | 20 (continuous) | TN gauge, dice tray |
| Elevation | none (flat) | Glass provides depth in chrome; content stays flat with a 1-px `separator` hairline (`.strokeBorder(.separator.opacity(0.5))`) on cards in light mode only. |

### 4.4 Motion

`TMMotion` centralizes animations so Reduce Motion is handled once.

| Token | Spec | Used for |
|-------|------|----------|
| `TMMotion.state` | `.snappy(duration: 0.25)` | Selection, chip changes, card reorder |
| `TMMotion.reveal` | `.smooth(duration: 0.35)` | Outcome banner appears, sections expand |
| `TMMotion.drain` | `.easeOut(duration: 0.45)` staggered 40 ms per pip | Pips emptying after damage applies |
| `TMMotion.phase` | `.spring(duration: 0.4, bounce: 0.15)` | Phase track segment advance, step title swap |

Implementation: a `View.tmAnimation(_:value:)` wrapper that reads `@Environment(\.accessibilityReduceMotion)` and substitutes `nil` (or a 0.15 s cross-fade for state changes that need *some* cue). Symbol effects (`.symbolEffect(.bounce)`) are gated the same way.

### 4.5 Haptics

`TMHaptics` maps game events to `sensoryFeedback`, and is gated by the Settings **Haptics** toggle (SettingsSpec; `ux.hapticsSetting`).

| Event | Feedback |
|-------|----------|
| Die face selected | `.selection` |
| Both dice entered / auto roll lands | `.impact(weight: .light)` |
| Hit | `.impact(weight: .medium)` then `.success` |
| Miss | `.error` (soft) — or `.impact(flexibility: .soft)`; test on device, it should not feel punitive |
| Unit wrecked | `.impact(weight: .heavy)` |
| Critical owed | `.warning` |
| Phase advances / side passes | `.impact(weight: .light)` |
| Victory | `.success` |
| Destructive confirm (discard, delete) | none — system dialog |

Use SwiftUI's `.sensoryFeedback(_:trigger:)` on the view that owns the state, never `UIImpactFeedbackGenerator` directly.

### 4.6 Iconography

- SF Symbols only, monochrome in chrome, hierarchical in content.
- Canonical symbol per concept (document in `DesignSystem/README.md`):

| Concept | Symbol |
|---------|--------|
| Roll dice / initiative | `dice` |
| Move | `figure.walk` (walk), `figure.stand` (still), `figure.run` (sprint), `arrow.up.forward` (jump) — or custom SF Symbol later |
| Shoot | `scope` |
| Clean up | `trash` → prefer `checklist` (less destructive connotation) |
| Hit | `checkmark.circle.fill` |
| Miss | `xmark.circle.fill` |
| Critical | `exclamationmark.triangle.fill` |
| Wrecked | `flame.fill` |
| Armor | `shield.fill` |
| Structure | `square.stack.3d.up.fill` (or `cube.fill`) |
| Range | `ruler` |
| Event log | `list.bullet.rectangle` |
| More menu | `ellipsis` (iOS 26 glass toolbar style — not `ellipsis.circle`) |

---

## 5. Component library

Each component lives in `DesignSystem/Components/`, has a `#Preview` covering light/dark, AX5 Dynamic Type, and Reduce Motion, and has no dependency on `MatchStore` (takes plain values). Components that need domain types import `MechBuddyDomain` only for value types.

### 5.1 `Eyebrow`
Uppercase condensed section label with optional trailing accessory (e.g. "Swap" button). Replaces `Section("…")` headers on custom surfaces and the ad-hoc `.caption.weight(.semibold)` labels in `compactHealth` (`BattleFlowView.swift:502-508`). Adds `.accessibilityAddTraits(.isHeader)`.

### 5.2 `TMCard`
Container: `surface.card`, `TMRadius.card`, 16 pt padding, optional leading side-color edge (4 pt bar), optional "raised" state. All custom battle content sits in cards inside a `ScrollView` + `LazyVStack`, not a `List` (see §6.10 for why).

### 5.3 `SideBadge`
`A` in a filled circle (side.a) or `B` in a filled diamond (side.b), 22 pt at default size, scales with `@ScaledMetric`. Variant `SideTag` = badge + "Side A" text. Accessibility: label "Side A".

### 5.4 `PipTrack` (v2 — replaces `UnitFocusSheet.swift` lines 142-170)
- Props: `remaining`, `capacity`, `kind: .armor | .structure`, `size: .compact | .regular | .large`, `showsCount: Bool`.
- Filled pips use `pip.armor` / `pip.structure`; lost pips use `pip.lost` (hollow + strike) — **shape changes, not just color**.
- Count label "3/5" to the trailing side in `TMFont.stat`.
- Wraps to multiple rows with a custom `Layout` (flow layout) when capacity × pip width exceeds available width or at accessibility sizes (spec: "large-text layout variant").
- Animates drain with `TMMotion.drain` when `remaining` decreases; brief `brand.damage` flash on the pips that were just lost.
- Accessibility: one element, label "Armor", value "3 of 5". `accessibilityIdentifier` passthrough so `as.unitFocus.wounds.{id}` keeps working.

### 5.5 `HealthReadout`
Two stacked `PipTrack`s (armor over structure) with tiny icon labels (`shield.fill`, structure symbol). Compact variant for battle unit cards, regular for Unit Focus/Force.

### 5.6 `StatStrip`
Horizontal run of `StatCell(label:value:)`: `MV 10″/6″j`, `TMM 2`, `SKL 4`, `DMG 2·2·1`. Monospaced, `surface.readout` background, wraps via `ViewThatFits` into a 2×2 grid at large type. Tapping a cell shows the glossary popover (reuse `InfoButton` content) — this is where the "Words on the card" glossary from Getting Started becomes useful in context.

### 5.7 `StatusChip`
Small capsule: icon + 1–2 words. Variants and tokens:

| Variant | Text | Icon | Token |
|---------|------|------|-------|
| `.critOwed(n)` | "Crit owed" / "2 crits owed" | `exclamationmark.triangle.fill` | warning |
| `.wrecked` | "Wrecked · still fires" | `flame.fill` | danger |
| `.immobile` | "Can't move" | `figure.stand` | secondary |
| `.sprinted` | "Sprinted · can't fire" | `figure.run` | secondary |
| `.moved(mode)` | "Walked" / "Jumped" / "Stood still" | per §4.6 | secondary |
| `.hit(target, dmg)` | "Hit Locust · 2" | `checkmark.circle.fill` | success |
| `.missed(target)` | "Missed Locust" | `xmark.circle.fill` | danger |
| `.ready` | "Ready to fire" | `scope` | signal |
| `.waiting` | "Waits for other side" | `hourglass` | secondary |

Matches BattleTableSpec § Unit row badges (wording to be reconciled; see §8).

### 5.8 `UnitCard` (battle) and `ForceUnitCard` (Force tab)
```
┌───────────────────────────────────────────┐
│▌ (A)  Shadow Hawk SHD-2H         [chip]  ›│
│▌      ■■■□□  3/5   armor                  │
│▌      ■■■■■  5/5   structure              │
│▌      MV 10″/6″j · TMM 2 · DMG 2·2·1      │  ← Force + Focus only, hidden on battle compact
└───────────────────────────────────────────┘
```
- Leading 4 pt side-color edge + `SideBadge`.
- Trailing status chip (one, highest priority: crit owed > wrecked > immobile > sprinted > shot result > ready).
- Whole card is one button → Unit Focus. `accessibilityIdentifier("as.battle.unit.\(id)")` preserved.
- States: `active side` (raised), `other side` (flat, 85% opacity on secondary text only — never dim the pips), `wrecked` (flame chip; name gets `strikethrough` *only* after removal), `removed` (not shown in battle; shown in Force with "Off the table").
- Accessibility label composed exactly as `unitAccessibilityLabel` does today (`BattleFlowView.swift:566-583`), moved into the component.

### 5.9 `DieFacePicker` (replaces `DiceFaces`, `BattleFlowView.swift:1180-1212`)
- Six buttons rendered with `Image(systemName: "die.face.\(n)")` / `.fill` when selected, at ~36 pt symbol size, in a 6-across row; wraps to 3×2 at accessibility sizes.
- Selected: `brand.signal` fill with `text.onSignal` glyph (fixes contrast), `.symbolEffect(.bounce, value:)` on select, `.selection` haptic.
- Title row: "First die" + selected value in `TMFont.stat`.
- Accessibility: keep per-face labels ("First die 4") and `.isSelected` trait; container gets `accessibilityIdentifier` passthrough (`as.crit.die1`, `as.sator.die1`, etc. — preserved).
- Optional later: an *adjustable* accessibility action (`accessibilityAdjustableAction`) so VoiceOver users can swipe up/down through faces instead of hunting six buttons.

### 5.10 `DiceTray` (replaces `DiceRollEntry`, `BattleFlowView.swift:1057-1118`)
Combines: mode picker (Real dice / In the app), two `DieFacePicker`s (manual) **or** a big "Roll" glass button that animates two dice tumbling and settling (auto), plus a `DiceReadout` showing the two faces and the total.
- Manual is the default and visually primary (product lock: physical dice primary).
- Auto mode moves to a less prominent position: a small "Let the app roll" text button beneath the faces, which flips the session's dice mode. The segmented picker remains available in Settings / the battle menu (see §14 D5).
- Total readout uses `TMFont.readoutM` + `.numericText()` transition.

### 5.11 `DiceReadout`
Two static die-face glyphs + "= 9". Used in event log rows, shot feed, initiative result, crit result. Accessibility: "Rolled 4 and 5, total 9".

### 5.12 `TNGauge` (spec component; `ux.tnHero`)
```
┌─────────────────────────────────────┐
│  NEED                               │
│   7+          58% to hit            │
│  ▁▂▃▅▆█▆▅▃▂▁   (2…12 histogram,     │
│  2 · · · · 7 · · · · 12  bars ≥ TN  │
│                         highlighted)│
└─────────────────────────────────────┘
```
- Big numeral (`TMFont.readoutL`), "or higher" sublabel, odds percentage (`WAYS_AT_LEAST` from SATORAttackSpec — expose via domain helper, §9).
- 2D6 distribution histogram: 11 bars, bars ≥ TN filled `brand.signal`, below TN `pip.empty`. When a roll is entered, the bar for the rolled total gets a marker. This makes "what does 7+ mean" self-explanatory for new players and is the single brand moment on the solver.
- Auto-miss state (TN > 12): numeral replaced by "Can't hit" + histogram all empty + one-line reason.
- `.contentTransition(.numericText())` on TN changes; VoiceOver announcement "Target number 7 or higher, 58 percent" when it changes (`ux.satorRunningTN`).
- Identifier: `as.sator.tnPreview` (keep) and add `as.sator.tn` (spec).

### 5.13 `OutcomeBanner`
Full-width card that appears after dice are entered: **HIT** (success token, `checkmark.circle.fill`, `.symbolEffect(.bounce)`) or **MISS** (danger token, `xmark.circle.fill`). Includes "Rolled 9 vs 7+" sublabel. Haptic per §4.5. Identifier `as.sator.outcome` preserved. VoiceOver: `.isHeader` + announcement.

### 5.14 `PhaseTrack` (spec `chrome.phaseChip`, `ux.phasePrompt`)
```
 ROLL ✓ ── MOVE ✓ ── SHOOT ● ── CLEAN UP
```
Four segments with icon + short label; states: done (checkmark, secondary), current (filled `brand.signal` capsule, `text.onSignal`, bold), upcoming (outline). Not interactive in 1.0 (spec allows phase jump with confirm — keep that out; the coach decides). Identifiers `as.battle.phase.initiative|movement|combat|end` on each segment with `.isSelected` on current. At AX sizes collapses to "Step 3 of 4 · Shoot".

### 5.15 `TurnCounter`
"TURN 3 / 6" — eyebrow-style label + `readoutM` numeral; optional thin progress ring (turn / maxTurns). On the final turn, shows a "LAST TURN" chip (warning token) — replaces the hidden `InfoButton` in Clean up (`BattleFlowView.swift:425-431`).

### 5.16 `CoachPrompt` (spec `PhasePromptBanner`)
Step title (`TMFont.stepTitle`) + one line of coach copy + optional `InlineHelp` disclosure ("Why?") that expands in place. Active-side badge leads the title when a side owns the step. This is the battle screen's brand moment.

### 5.17 `WeightGlyph` (Later tier, but cheap)
Abstract silhouette by size class (`sz` 1–4): small/medium/heavy/assault as simple geometric shapes. Not licensed art. Used on unit cards and Victory. Flagged "Later" in the UX spec; include only if time allows.

### 5.18 `PrimaryActionButton` / `SecondaryActionButton`
Button styles, not ad-hoc modifiers. Primary = `.glassProminent` in the dock (tinted by active side or signal; see §6.10), `.borderedProminent` + `controlSize(.large)` in content. Min height 50 pt. Secondary = `.glass` in dock, `.bordered` in content. Destructive variants via `role:`. Removes the repeated `.frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.borderedProminent).controlSize(.large).listRowInsets(...).listRowBackground(.clear)` block (appears 7 times).

### 5.19 `PhaseDock` (spec `as.battle.phaseDock`)
`GlassEffectContainer(spacing: 12)` containing up to three glass controls: optional leading utility (Units/Log on iPhone), optional secondary (Done shooting / Skip moves), primary. Placed with `.safeAreaInset(edge: .bottom)`. `glassEffect` applied after layout modifiers (DesignSystemSpec). Under Reduce Transparency the system glass falls back automatically; verify legibility. Identifiers: container `as.battle.phaseDock`, primary keeps `as.battle.primary` **and** gains `as.battle.phaseDock.next` (spec), secondary keeps `as.battle.doneShooting` **and** gains `as.battle.phaseDock.doneSide`.

### 5.20 `MissionCard` (Play hero)
Large card: eyebrow "ALPHA STRIKE · BEGINNER MISSION", title "Ridge Line", subtitle from content JSON (`"Beginner mission · 2 vs 2 · about 40 minutes"`), facts row (`person.2` 2 players · `clock` 40 min · `dice` 2D6 · `ruler` tape), Side A vs Side B roster preview with badges, primary CTA, secondary links (How to play · New here?). One brand moment: a subtle `brand.signal` → clear gradient wash in the card's top edge.

### 5.21 `ResumeCard`
Card with eyebrow "IN PROGRESS", "Ridge Line", `TurnCounter` + mini `PhaseTrack` (static), both sides' remaining structure as two tiny bars, "Continue" primary button. Identifier `as.modeHome.resume`.

### 5.22 `ChecklistRow`
Tappable row with a check circle (persisted — GettingStartedSpec wants persisted booleans), title, optional detail disclosure, optional external link with "Opens in Safari" a11y hint.

### 5.23 `EmptyState` / `ErrorBanner`
- `EmptyState`: symbol, title, one line, CTA. Used for Force with no session, event log with no events.
- `ErrorBanner`: inline card with `exclamationmark.triangle.fill`, message, "Try again" action; replaces red-text rows (`PlayHomeView.swift:70-75, 333-338`).

### 5.24 `InfoButton` (refine, keep)
Keep the component (`DesignSystem/InfoButton.swift`). Changes: use `info.circle` hierarchical rendering, tint `.secondary`; standardize popover content via an `InfoContent(title:body:links:)` view so every popover looks the same; **stop using it for navigation** (see §6.2).

### 5.25 `InlineHelp`
"Why?" / "More" disclosure that expands one or two lines of `TMFont.detail` in place with `TMMotion.reveal`. For coach detail that's useful but not primary (placement rules, last-turn rule, what happens next).

---

## 6. Screen-by-screen overhaul

### 6.1 App shell, icon, launch

**Today.** `RootTabView.swift`: four `Tab`s, `.sidebarAdaptable`, `.tabBarMinimizeBehavior(.onScrollDown)` — correct per spec. Force tab uses a `forceLoads` counter to trigger reload. No icon image. Launch screen is the generated blank (`INFOPLIST_KEY_UILaunchScreen_Generation: YES`).

**Problems.** No icon = can't ship, and the home screen/Spotlight/Settings show a placeholder. Blank white launch flash before a (planned) darker content style. Tab symbols are fine but `book` reads generic.

**Target.**
1. **App icon** — commission or design a layered iOS 26 icon (Icon Composer `.icon` file, which supports Liquid Glass layering, light/dark/tinted/clear variants). Concept: an amber "signal" chevron or abstract 'Mech visor glyph over a charcoal plate, with a single d6 pip motif. Deliver: `AppIcon` (Icon Composer), plus a 1024 PNG fallback. No BattleTech marks.
2. **Launch** — set `UILaunchScreen` background color to `surface` charcoal-ish in dark, near-white in light (asset color `LaunchBackground`) so there's no flash mismatch. No logo on launch (Apple HIG).
3. **Tabs** — keep Play/Force/Rules/Settings. Consider `book.pages` for Rules and `person.2.badge.gearshape`… no — keep `gearshape`. Use filled variants automatically (system does this). Keep `.sidebarAdaptable`.
4. **iPad sidebar** — add a sidebar header (app name) via `TabSection` only if Classic or Free Battle become visible; for 1.0 keep flat.
5. Replace `forceLoads` counter with the Force view observing the repository (see §9) so the tab doesn't need a reload token.
6. **Global tint**: set `.tint(TMColor.brandSignal)` once at the root; remove per-control tints.

**Acceptance.** Icon renders in all four appearances; no launch flash in dark mode; tab bar minimizes on scroll on all four tabs (Settings and Rules are lists — already true).

---

### 6.2 Play home (`play.home` / `as.modeHome`)

**Today** (`PlayHomeView.swift:16-130`). A `List` with up to four sections: a "Continue" button row with a detail string; an "Alpha Strike" section with one row "Play Ridge Line" + an info button that hides Getting Started and How to play; a "Classic BattleTech — Coming soon" row with an info popover; an optional red error row. Getting Started and How to play are reached by `pendingInfo` + `onDismiss` + `Task.sleep(350ms)` (`:171-186`).

**Problems.**
- The first screen of the app is three plain rows. Nothing says what the app is, what Ridge Line is, or what you need.
- The two onboarding destinations are invisible unless you tap a small `i`.
- Resume is a plain text button with no visual priority even though ModeHomeSpec says it is *primary* when present.
- Sleep-based sheet sequencing is a timing hack that will flake on slow devices and in UI tests.

**Target layout (iPhone portrait, scrolling `ScrollView` + `LazyVStack`, large title "Play"):**

```
Play                                         (large title)

┌ IN PROGRESS ─────────────────────────────┐   ← ResumeCard, only if active session
│ Ridge Line                               │
│ TURN 3 / 6   ROLL ✓ MOVE ✓ SHOOT ● CLEAN │
│ (A) ■■■■■■■□□□  (B) ■■■■□□□□□□  struct  │
│ [        Continue        ]  (primary)    │
└──────────────────────────────────────────┘

ALPHA STRIKE
┌──────────────────────────────────────────┐   ← MissionCard
│ BEGINNER MISSION                         │
│ Ridge Line                               │
│ 2 vs 2 · about 40 min                    │
│ 👥 2 players  🎲 2 dice  📏 tape  4 minis │
│ (A) Shadow Hawk · Commando               │
│ (B) Wolverine · Locust                   │
│ [   Play Ridge Line   ]  (primary, or    │
│                           secondary when │
│                           resume exists) │
│ How to play ›         New here? ›        │
└──────────────────────────────────────────┘

MORE MODES
┌──────────────────────────────────────────┐
│ Classic BattleTech        COMING SOON  › │   ← opens sheet (§6.3)
└──────────────────────────────────────────┘

(ErrorBanner here if content fails to load)
```

**Behavior.**
- When a resume exists, ResumeCard's Continue is the prominent CTA and MissionCard's button drops to `.bordered` ("Start new Ridge Line"). Keep the replace confirmation dialog (`:107-118`) — copy tweak in §8.
- "How to play" and "New here?" are visible `NavigationLink`s (push, not sheet) — removes the popover→sheet sequencing and the `Task.sleep`. Push keeps the tab bar and back gesture, which is more conventional for reference content. (If the owner prefers sheets, use `.sheet(item:)` driven directly by the button, no popover in between.)
- Getting Started completion (§6.4) feeds a soft emphasis: if checklist incomplete and no session ever played, MissionCard shows "New here? Start with the 2-minute checklist" as the secondary line (GettingStartedSpec: "soft — never hard-block").
- MissionCard roster preview reads from `ridgeLineScenario()` once in `.task` (already loaded for the title).
- Starting a match: tap → brief `TMMotion.reveal` scale on the card → `fullScreenCover`. Consider `.navigationTransition(.zoom(sourceID:in:))` from the card into the battle cover for a premium feel (iOS 18+ API, available on 26). Gate with Reduce Motion.
- Pull-to-refresh: not needed.

**Accessibility.** ResumeCard combines into one element with label "Continue Ridge Line, turn 3 of 6, Shoot step" and the Continue button as the activation. MissionCard: heading trait on title; facts row combined ("2 players, 2 dice, tape measure, 4 miniatures"). Preserve `as.modeHome.resume`, `as.modeHome.ridgeLine`, `as.modeHome.gettingStarted`, `as.modeHome.howToPlay`, `play.classicComingSoon`, `classic.comingSoon.playAS`, `play.home`.

**iPad.** Two-column `Grid`: ResumeCard + MissionCard side-by-side at regular width; readable max width 720 pt otherwise.

**Acceptance.**
- Fresh install: How to play and New here are reachable in one tap without opening a popover.
- With a saved match: Continue is the only prominent button on screen.
- No `Task.sleep` left in `PlayHomeView`.
- VoiceOver reads the resume card as a single coherent sentence.

---

### 6.3 Classic coming soon

**Today.** A list row with "Coming soon" secondary text and an info popover (`PlayHomeView.swift:52-68, 154-169`) whose button routes to Ridge Line via the sleep hack.

**Target.** Row with a `COMING SOON` capsule (secondary token, not amber — it's not actionable) → tap opens a medium-detent sheet (AppShellSpec § Sheet stack: "Classic coming soon | medium | Exclusive"):

```
Classic BattleTech                 [Close]
───────────────────────────────────────────
(hex-grid illustration in SF Symbols:
 `hexagon` pattern, monochrome)

Coming later
Classic uses paper record sheets, heat,
and hit locations. Mech Buddy will guide
those too.

For a first night, play Ridge Line.
[  Play the beginner game  ]   (primary)
```

Primary button dismisses the sheet and calls `requestNewRidgeLine()` from the sheet's `onDismiss` via an enum (no sleep). Identifier `classic.comingSoon.playAS` preserved; sheet gets `classic.modeHome` (ScreenCatalog ID).

---

### 6.4 Getting Started (`as.gettingStarted`)

**Today** (`PlayHomeView.swift:258-323`). Intro paragraph; "Before you sit down" numbered rows each with an info popover holding the detail; a "Words on the card" section with six terms each behind a popover.

**Problems.** Detail for every step is hidden; the numbered list is not a checklist (GettingStartedSpec says persisted checklist with `N / 6` progress); the glossary is six identical rows with six popovers — the content *is* the definition, so hiding it makes the screen useless.

**Target.**

```
New here                                (large title)
3 of 7 ready                             (subtitle / progress capsule)

You don't need to know BattleTech yet. Gather a few
things, then start Ridge Line. The app coaches every step.

BEFORE YOU SIT DOWN
┌──────────────────────────────────────────┐
│ ◯  This app is a helper — the game is on │
│    the table                           ⌄ │  ← tap circle toggles; tap row expands detail
│ ✓  Get four miniatures and their cards   │
│ ✓  Get two six-sided dice                │
│ ◯  Get a measuring tape that shows inches│
│ ◯  Clear a table about 3 feet across     │
│ ◯  Optional: download the free Quick-    │
│    Start PDF               Open in Safari↗│
└──────────────────────────────────────────┘

READING A UNIT CARD
┌──────────────────────────────────────────┐
│  (illustrative mock card built from      │
│   StatStrip + HealthReadout with sample  │
│   Shadow Hawk numbers, each field        │
│   numbered ①②③…)                         │
│ ① MV — How many inches it can walk       │
│ ② TMM — Extra "harder to hit" when moved │
│ ③ Armor — Outer hit points               │
│ ④ Structure — Inner hit points; 0 = wreck│
│ ⑤ Skill — Starting shot difficulty (4)   │
│ ⑥ S / M / L — Damage at short/med/long   │
└──────────────────────────────────────────┘

[        Play Ridge Line        ]   (primary; when all checked shows ✓ “You’re ready”)
```

- Checklist state persisted (new tiny store — `UserDefaults`/`@AppStorage` keyed by item id is acceptable for 1.0; SettingsSpec "Delete all local data" must clear it).
- Progress in nav subtitle (`.navigationSubtitle` is available on iOS 26) or a capsule under the title.
- The final JSON item "Then tap Play Ridge Line" becomes the bottom CTA instead of a checklist row (content JSON tweak or filter by id `roster`).
- "Reading a unit card" turns the glossary into an annotated sample card — this doubles as the visual introduction to the components players will see in battle.
- Identifiers: keep `as.gettingStarted.screen`, `as.gettingStarted.check.{id}`.

---

### 6.5 How to play Ridge Line (`as.howToPlay`)

**Today** (`HowToPlayRidgeLineView.swift`). Long `List` of sections with headline/subheadline text pairs. Content is good; presentation is a wall of text.

**Target.** A visual walkthrough that previews the real UI:

1. **Header card**: "Two players · four 'Mechs · about 40 minutes. The phone tells you the next tap."
2. **"The four tabs"** → a compact 2×2 grid of tiles with each tab's SF Symbol and one line.
3. **"A turn has four steps"** → render the real `PhaseTrack` component, then four step cards each with the phase icon, title, and the existing copy. Each card includes a miniature, non-interactive rendering of the relevant component (e.g. `DieFacePicker` with 4 and 3 selected for Roll; three move buttons for Move; `TNGauge` at 7+ for Shoot; a wrecked `UnitCard` for Clean up). Components are the same code as the battle screen, fed with sample values — no screenshots to maintain.
4. **"How you win"** → card with trophy symbol; the two rules as bullets; "6 turns max" as a `TurnCounter` visual.
5. **"Leave and come back"** → small card showing a `ResumeCard` sample.
6. Bottom CTA: "Play Ridge Line" (when pushed from Play).

Keep `as.howToPlay.screen`. Fix straight apostrophes (§8).

**Optional (1.x):** paged `TabView(.page)` version for first-launch intro (AppShellSpec § Onboarding), reusing these cards.

---

### 6.6 Force tab (`force.as.list`)

**Today** (`PlayHomeView.swift:325-398`). Two sections (Side A/B) of rows: name, "Armor x/y", "Structure x/y", info popover with stats. Loads the active session's units, else the Ridge Line fixtures. Title "Force".

**Problems.** It's a placeholder per the spec (RosterSpec describes a full roster editor, which is out of scope for this overhaul). But the *display* can be production quality now without building editing.

**Target (1.0 display-only).**

```
Force                                      (large title)
[ In this match ▾ ]   ← context capsule: "In this match" when a session exists,
                         "Ridge Line roster" otherwise. Not a picker in 1.0, just a label.

SIDE A  (A)                               PV 47
┌──────────────────────────────────────────┐
│▌ Shadow Hawk SHD-2H        SZ 2      ›  │
│▌ MV 10″/6″j · TMM 2 · SKL 4 · DMG 2·2·1  │
│▌ ■■■■■ 5/5 armor   ■■■■■ 5/5 structure   │
│▌ IF0* · JMPW1                            │
└──────────────────────────────────────────┘
┌ Commando COM-2D … ┐

SIDE B  (B)                               PV 50
…

PV balance  (A) ███████████░░░░ (B)   gap 3 — even
```

- `ForceUnitCard` (§5.8) with full `StatStrip`, `HealthReadout`, abilities line (monospaced, tappable for glossary later).
- Side headers use `Eyebrow` + `SideBadge` + PV total (`pv` already on `MatchUnitState`).
- PV balance bar at the bottom (`ux.pvMeter`, tier 1.x — cheap to do now since data exists).
- Tap card → `UnitFocusSheet` in read-only mode (UnitFocusSpec: "Force tab row → Open focus"). Actions section hidden outside battle.
- Status chips when in a live match (wrecked, crit owed).
- `EmptyState` if content fails: "Couldn't load the roster" + Try again.
- Identifiers: keep `force.as.list`, `force.as.unit.{name}` (note: spec says `{id}`; keep name for now, add id variant — see §16).

---

### 6.7 Rules home (`rules.home`)

**Today** (`PlayHomeView.swift:400-435`). Intro paragraph, nine plain `NavigationLink` rows, disclaimer footer.

**Target.**
- Group the nine topics into three sections with icons (content IDs from `as-rules-topics.json`):
  - **START HERE**: `how-to-play` (`questionmark.circle`), `turn` (`arrow.triangle.2.circlepath`)
  - **DURING A GAME**: `movement` (`figure.walk`), `combat` (`scope`), `sator` (`target`), `damage` (`shield.lefthalf.filled`)
  - **QUICK REFERENCE**: `tables` (`tablecells`), `abbreviations` (`textformat.abc`), `odds` (`chart.bar`)
  (Grouping can live in the JSON as a `group` field — ContentPackSpec bump — or in a small Swift map keyed by topic id for 1.0.)
- Each row: icon in a tinted rounded square (system Settings style), title, one-line summary (first sentence of first section, or a new `summary` field).
- Add `.searchable` (RulesReferenceSpec: "Search optional v1.x") — cheap since all content is local; search titles + headings + bodies. This is the single biggest "production app" signal on a reference screen.
- Disclaimer stays as section footer, `.footnote`.
- Brand budget: minimal — icon tiles use `.secondary` tint, not amber.
- Identifiers: keep `rules.home`, `rules.as.{id}`.

---

### 6.8 Rules topic detail

**Today** (`PlayHomeView.swift:437-449`). `List` with a `Section(heading)` and one `Text(body)` per section.

**Problems.** Section headers render as small grey uppercase text (default `List` header style), so the hierarchy is inverted — headings are less prominent than body text. Long bodies in a cell with insets read cramped. Tables (Quick numbers, odds, abbreviations) are flattened into paragraphs.

**Target.**
- `ScrollView` with readable width (max ~640 pt), large title = topic title.
- Headings in `.title3.weight(.semibold)`, body in `.body` with `lineSpacing(3)`; numbered headings ("1. Roll dice") get a leading number badge.
- **Structured blocks** (ContentPackSpec addition, optional for 1.0): allow sections to carry `table` (rows/columns) and `callout` types. Render `table` with `Grid`, monospaced numeric columns. Topics that benefit: `tables`, `abbreviations`, `odds`, `sator`.
  - For `odds`: render the same 2D6 histogram used by `TNGauge` with "7+ = 58%" labels — the reference and the in-game gauge then teach the same picture.
  - For `sator`: render S·A·T·O·R as five labelled rows with their modifiers.
- "In a game? Open the shot solver" contextual button on `sator`/`combat` only if a match is active (RulesReferenceSpec "Open in battle" — 1.x, note only).
- Text selection enabled (`.textSelection(.enabled)`).
- Share/print (`ux.rulesShare`) — Later.
- Identifier: keep `rules.as.detail.{id}`.

---

### 6.9 Settings (`settings.home`)

**Today** (`PlayHomeView.swift:451-508`). "Delete saved games" button, three links under "Legal", trademark footer.

**Target** (`Form`/`List` is correct here — Settings should look like system Settings):

```
Settings

GAMEPLAY
  Dice                    Real dice ▸     (Real dice / Let the app roll — default for new matches)
  Haptics                 [on]
  Keep screen awake       [on]           (today hard-coded in BattleFlowView:36)

APPEARANCE
  Theme                   System ▸        (System / Light / Dark)

ABOUT
  How to play Ridge Line             ›
  New here checklist                  ›
  Version                 1.0.0 (1)

SUPPORT & LEGAL
  Support                            ↗
  Privacy Policy                     ↗
  Accessibility                      ↗
  footer: Unofficial fan aid. BattleTech and Alpha Strike are
          trademarks of their respective owners.

DATA
  Delete saved games                     (destructive, red)
  footer: Removes the game in progress and your checklist.
```

- Row icons in tinted rounded squares (system style) for a polished feel.
- External links get `arrow.up.right` trailing glyph and the "Opens in Safari" hint (GettingStartedSpec a11y note applies here too).
- Theme applies `.preferredColorScheme` at the root.
- Haptics toggle drives `TMHaptics` (§4.5).
- "Delete" moves to the bottom (destructive actions last — HIG). Keep `settings.deleteAll`, `settings.home`.
- Default MechWarrior skill (SettingsSpec) — skip in 1.0 UI unless Free Battle ships; note in §14.

---

### 6.10 Battle cover shell

**Today** (`BattleFlowView.swift:26-199`). `NavigationStack` in a `fullScreenCover`; inline title "Ridge Line"; "Leave" in `cancellationAction`; `ellipsis.circle` menu with Back / Undo / Swap / Skip / What just happened / Quit; five confirmation dialogs; four sheets; error alert. Body switches between `VictoryView`, `tableReady`, and `battleTable`, each a `List`.

**Structural decision: `List` → `ScrollView` + cards for the battle table.**
The battle table is a live dashboard, not a list of homogeneous rows. `List` fights custom card layout (row insets, separators, background hacks like `listRowBackground(Color.clear)` used 7 times). Use `ScrollView { LazyVStack(spacing: 12) { … } }` with `TMCard`s and `.scrollEdgeEffectStyle(.soft, for: .bottom)` (iOS 26) so content fades under the glass dock. Keep `List` for Table setup only if it stays a checklist (it won't, see §6.11).

**Target structure (all non-victory steps):**

```
[Leave]        Ridge Line           [≡ log] [⋯]     ← system glass toolbar
──────────────────────────────────────────────────
TURN 3 / 6                    (A) Side A is up     ← header strip (content, pinned via
ROLL ✓ ── MOVE ✓ ── SHOOT ● ── CLEAN UP               safeAreaInset(edge: .top) under nav bar)
──────────────────────────────────────────────────
(step-specific content: CoachPrompt + tools + unit cards; see §6.11–6.17)

               ┌─────────────── glass dock ───────────────┐
               │ [Done shooting]   [   Solve a shot   ]   │
               └──────────────────────────────────────────┘
```

- **Toolbar**: "Leave" stays a text button (clear meaning: saves and exits). Add a dedicated `list.bullet.rectangle` button for the event log (currently buried in the menu and it's useful mid-game). Menu icon → `ellipsis` (iOS 26 style). Menu ordering: Undo last change (with the action name if available, e.g. "Undo Walked"), Go back a step, Swap sides, Skip remaining moves, divider, Quit and discard (destructive, last).
- **Header strip**: `TurnCounter` + `PhaseTrack` + active-side `SideTag`. Pinned at top. On Table setup and Victory it is hidden.
- **Active-side theming**: when a side owns the step (move/shoot/place), the header's side tag, the active cards' leading edges, and the dock primary tint use that side's color. This is the hotseat "pass the phone" cue the spec asks for ("Header shows Playing: {side}"). Signal amber remains the tint when no side owns the step (initiative, clean up).
- **Side-change interstitial** (new, small): when `activeSide` flips during movement/combat, show a 1.2 s non-blocking banner sliding from the header — "(B) Side B's turn — pass the phone" — with a light haptic and a VoiceOver announcement. Reduce Motion: cross-fade. This addresses the most common hotseat failure (the next player doesn't notice it's their turn).
- **Dock**: `PhaseDock` (§5.19). Primary title from `primaryTitle` (`BattleFlowView.swift:616-633`) — titles reviewed in §8.
- **Idle timer**: keep `isIdleTimerDisabled` but drive from the Settings "Keep screen awake" toggle.
- **Phase-change announcements**: post `AccessibilityNotification.Announcement("Turn 3, Shoot. Side A shoots.")` on `coach.step`/`activeSide` change.
- **Loading**: replace `ProgressView("Loading the mission…")` with a skeleton of the header + two redacted unit cards (`.redacted(reason: .placeholder)`), which is near-instant anyway.
- **Errors**: keep the alert for unexpected failures, but title it by context ("Couldn't save the shot") where the store can tell us.

**iPad / landscape**: see §7.4.

---

### 6.11 Table setup (`as.ridge.tablePrep`)

**Today** (`BattleFlowView.swift:223-297`). List: numbered "Set the table" steps; "Who's who" with side names and unit names + a Swap button in the header; "How you win" behind an info popover; a "Start" prominent button in a list row.

**Target.** This is the "pre-flight" screen. Make it feel like a mission briefing.

```
Ridge Line                                       [Leave]

MISSION BRIEFING
Set up the table, pick sides, then start.

WHO'S WHO                                  [⇄ Swap]
┌───────────────────┐  ┌───────────────────┐
│ (A) SIDE A        │  │ (B) SIDE B        │
│ Shadow Hawk       │  │ Wolverine         │
│ Commando          │  │ Locust            │
│ ■■■■■■■ 7 struct  │  │ ■■■■■■■ 7 struct  │
└───────────────────┘  └───────────────────┘
  (side-by-side at all widths; stacked at AX sizes)

SET THE TABLE                                 2 of 5
┌──────────────────────────────────────────┐
│ ✓ 1. Put both maps grassland-side up…    │
│ ◯ 2. Keep a tape measure …               │
│ ◯ 3. …                                   │
└──────────────────────────────────────────┘
 (tappable checks — local, not persisted beyond the session;
  purely a helper, never blocks Start)

HOW YOU WIN
┌──────────────────────────────────────────┐
│ 🏆 Knock out both enemy 'Mechs.          │
│ ⏱ After turn 6, more structure left wins.│
└──────────────────────────────────────────┘

            ┌──────── glass dock ────────┐
            │ [      Start battle      ] │
            └────────────────────────────┘
```

- "How you win" becomes visible text (from `winningSummary`), not a popover.
- Swap animates the two side cards trading places (`matchedGeometryEffect` on unit names) with `TMMotion.state`.
- Start moves into the dock for consistency with every other step. Keep `as.ridge.tableReady` on the button and add `as.mission.startBattle` (spec). Keep `as.ridge.tablePrep` on the screen; add `as.mission.setup`.
- Checks are optional UX sugar; if the owner wants zero new state, render as numbered list with no checks (§14 D6).

---

### 6.12 Place the miniatures

**Today** (`BattleFlowView.swift:442-454` via `movementStep`). Headline "Place the miniatures", one line "Place each side on its own short edge. Side A places first." + info popover "within 6 inches". Primary "Placed".

**Target.**
- `CoachPrompt`: title "PLACE THE MINIATURES", line "Each side sets its 'Mechs within 6″ of its own short edge. (A) Side A places first."
- A simple schematic card: a rectangle (the table) with a 6″ shaded strip on each short edge labelled with the side badges — drawn with SwiftUI shapes, 120 pt tall. This one diagram removes the need for the popover entirely and is a great "production" touch.
- Dock primary: "Miniatures placed" (was "Placed" — ambiguous).

---

### 6.13 Initiative (roll dice)

**Today** (`BattleFlowView.swift:810-839`). Segmented "Real dice / In the app" picker; for manual: "Side A" label, two `DiceFaces` rows, total line, "Side B" label, two rows, total line, tie hint in orange or "{side} goes first" text. Primary in the bottom bar: "{side} goes first" or "Use rolls" (disabled until valid). Auto: one line + "Roll" primary.

**Problems.** Very long vertical scroll on iPhone (four 6-button rows + labels + totals); both sides look identical; the tie state is orange text only; the rule "higher goes **last**" (counter-intuitive for new players) is only in How to play.

**Target.**

```
TURN 1 / 6        ROLL ● ── MOVE ── SHOOT ── CLEAN UP

ROLL FOR INITIATIVE
Each side rolls two dice. Higher total moves last —
that's the advantage.                           [Why?]

┌ (A) SIDE A ─────────────────── 7 ┐
│ ⚀ ⚁ ⚂ ⚃ ⚄ ⚅    first die        │
│ ⚀ ⚁ ⚂ ⚃ ⚄ ⚅    second die       │
└──────────────────────────────────┘
┌ (B) SIDE B ─────────────────── 9 ┐
│ ⚀ ⚁ ⚂ ⚃ ⚄ ⚅                     │
│ ⚀ ⚁ ⚂ ⚃ ⚄ ⚅                     │
└──────────────────────────────────┘

┌──────────────────────────────────┐   ← result card, animates in when all 4 set
│ (B) Side B wins initiative        │
│ (A) Side A moves first.           │
└──────────────────────────────────┘
   or (tie):
┌ ⚠ Tie at 8 — both sides roll again ┐   (warning token + icon; dice clear on tap “Clear”)

Let the app roll instead                         ← small text button (flips dice mode)

        [ Side B wins — start moving ]   ← dock primary
```

- Each side's card carries its side color edge and badge; total appears top-right of the card in `readoutM` with `.numericText()`.
- Result card wording makes the consequence explicit: who **moves first** (the loser) — because that's what the players need to do next.
- Tie: warning card + "Clear dice" button that resets all four (today the user must re-tap each).
- Auto mode: the two side cards show a "Roll" glass button each? No — one dock "Roll both sides" button; after rolling, the cards show the rolled faces (via `DiceReadout`) with a short tumble animation, then the result card. Then the dock primary becomes "Start moving". (Today auto applies immediately on Roll; consider a one-beat reveal before advancing — needs `MatchStore` to separate "roll" from "apply", see §9.)
- Compact layout for small phones: put the two dice rows for a side side-by-side as two 3×2 grids when width allows (`ViewThatFits`).
- Identifiers: keep `as.battle.rollInit` (picker) and `as.initiative.tieHint`; add spec ids `as.initiative.lanceA.die1`… on the four pickers, `as.initiative.confirm` on the dock primary (in addition to `as.battle.primary`).

**Spec note.** BattleTableSpec describes initiative as a sheet (`as.initiative`) with steppers. The inline design above is better for hotseat (both players see one screen) — update the spec to "inline step" (§12).

---

### 6.14 Movement

**Today** (`BattleFlowView.swift:441-469, 694-807`). Headline "Turn 1 of 6 · Side A moves"; "Measure, then tap how it moved."; optional "Wrecks stay. They can still shoot."; checkmark labels for recorded moves; current mover name + info popover; printed move summary in `.title2`; one bordered button per legal mode ("Walk · 10″", "Sprint · about 15″"…); a `DisclosureGroup` "Change a recorded move" with a `Menu` per unit. Primary appears only when all moves are done: "Start shooting".

**Problems.** The current mover is just a headline-sized name; the move options are four identical grey buttons without icons; the recorded moves are plain labels; you can't see the other side's units at all during movement; the change-move disclosure is a hidden power feature styled like a settings row.

**Target.**

```
TURN 1 / 6        ROLL ✓ ── MOVE ● ── SHOOT ── CLEAN UP
                                     (A) Side A is up

(A) SIDE A MOVES
Measure on the table, then tap how it moved.

┌ NOW MOVING ──────────────────────────────┐
│▌ (A) Shadow Hawk SHD-2H                  │
│▌     10″ walk · 6″ jump                  │   ← readoutM
│▌ ┌────────────┐ ┌────────────┐           │
│▌ │ 🧍 Still    │ │ 🚶 Walk     │           │   ← 2×2 grid of large tiles,
│▌ │ under 1″   │ │ up to 10″  │           │     icon + verb + distance
│▌ └────────────┘ └────────────┘           │
│▌ ┌────────────┐ ┌────────────┐           │
│▌ │ 🏃 Sprint   │ │ ↗ Jump      │           │
│▌ │ ~15″ · no  │ │ up to 6″   │           │
│▌ │ shooting   │ │ harder shot│           │
│▌ └────────────┘ └────────────┘           │
└──────────────────────────────────────────┘

MOVE ORDER THIS TURN
 (A) Shadow Hawk   ● now
 (B) Wolverine     ○ next
 (A) Commando      ○
 (B) Locust        ✓ Walked    [Change]
 (sequence derived from activeSide alternation; recorded ones show chip + Change)

ON THE TABLE                                   ← compact HealthReadout cards for all units,
 (A) Shadow Hawk ■■■■■/■■■■■   (B) Wolverine …    collapsed by default on iPhone
```

- **Move tiles**: icon + verb + distance + consequence (Sprint: "can't shoot", Jump: "harder shot") — the consequence text replaces the info popover (`BattleFlowView.swift:705-711`). Tiles are buttons with `.bordered` style at rest, side-tinted on press. 2×2 on phone, 4-across on iPad/landscape, 1-column at AX sizes. Identifiers `as.battle.move.{mode}` preserved.
- On tap: tile fills, checkmark `symbolEffect`, light haptic, card collapses into a "✓ Shadow Hawk · Walked" row in Move order with `TMMotion.state`, and the next mover's card slides in. If the side flips, the side-change banner (§6.10) fires.
- **Immobile**: card shows "Can't move this turn" with `StatusChip(.immobile)` and a single "Stays put" tile.
- **Change a recorded move**: inline "Change" button on each recorded row → `Menu` with legal modes (same `store.reviseMove`). Removes the `DisclosureGroup`.
- **Wrecked still standing** notice becomes a `StatusChip` on the relevant unit, not a free-floating line.
- Dock: when moves remain → secondary "Skip remaining" (moved from the ⋯ menu, with the existing confirm) and no primary; when complete → primary "Start shooting" (side-tinted for the side that shoots first).

**Domain note.** "Move order" needs the alternation sequence. `BattleCoach` already knows `otherMechStillToMove`; the view can derive "who's next" from `activeSide` + remaining movers per side. No domain change required for a "now / next" indicator; a full predicted order would need a small engine helper (optional).

---

### 6.15 Combat (shoot)

**Today** (`BattleFlowView.swift:416-418, 472-564`). Headline "Turn 1 of 6 · Side A shoots"; "Shots this turn" list (text: "Shadow Hawk hit Locust" + "Rolled 9, needed 6."); "Side A — shooting now" caption + unit rows; "Side B — shoots next" caption + unit rows; each unit row: name, one status line, Armor x/y, Structure x/y. Dock: "Done shooting" (bordered) + "Solve a shot" (prominent).

**Target.**

```
TURN 1 / 6        ROLL ✓ ── MOVE ✓ ── SHOOT ● ── CLEAN UP
                                     (A) Side A is up

(A) SIDE A SHOOTS
Measure to the target, then solve a shot. Side B fires next.

SHOOTERS — SIDE A                                ← Eyebrow
┌──────────────────────────────────────────┐
│▌ (A) Shadow Hawk     [◎ Ready to fire]  ›│   ← tap = Unit Focus;
│▌ ■■■■■ 5/5   ■■■■■ 5/5                   │     trailing “Shoot” glass mini-button
│▌                              [ Shoot › ]│     opens solver prefilled
└──────────────────────────────────────────┘
┌──────────────────────────────────────────┐
│▌ (A) Commando        [✓ Hit Locust · 2]  │
│▌ ■■□□ 2/2   ■■ 2/2                       │
└──────────────────────────────────────────┘

TARGETS — SIDE B  · fires next
┌ (B) Wolverine  ■■■■■■ 6/6  ■■■■■ 5/5 ┐
┌ (B) Locust     □□ 0/2      ■□ 1/2   [⚠ Crit owed] ┐   ← just-damaged pips flash

SHOT FEED                                         (collapsed after 3)
 ⚀⚄ 9 vs 6+  ✓ Commando hit Locust for 2
 ⚁⚁ 4 vs 7+  ✗ Shadow Hawk missed Wolverine

     [ Done shooting ]   [   Solve a shot   ]   ← dock; primary side-tinted
```

- **Per-shooter "Shoot" button** on cards that `canAttackThisTurn` — direct path into the solver with the attacker preset (today you must go through Unit Focus → "Solve a shot with this 'Mech…" → sheet dismiss → solver). Uses the existing `prefillAttackerId` + `showSATOR`.
- **Shooters vs targets** are clearly labelled groups; the opponent group carries its state ("fires next" / "already fired") as the eyebrow suffix (today's `otherSideHeading`).
- **Shot feed** replaces "Shots this turn" with dice glyphs + TN + outcome icon; ordered by a proper per-shot timestamp/sequence (§9) instead of event-log string matching.
- **Damage landing**: when a shot is applied and the sheet dismisses, the target card scrolls into view, its pips drain with `TMMotion.drain`, and the card briefly pulses `brand.damage`. If wrecked: heavy haptic + flame chip appears with `symbolEffect(.bounce)`.
- **Done shooting** confirm dialog unchanged (`BattleFlowView.swift:108-119`); copy reviewed in §8.
- Identifiers: keep `as.battle.unit.{id}`, `as.battle.shot.hit|miss`, `as.battle.doneShooting`, `as.battle.primary`, `as.battle.activeSide`, `as.battle.table`, `as.battle.screen`.

---

### 6.16 Pending critical state

**Today** (`BattleFlowView.swift:376, 399-410`). Headline becomes "Critical hit"; line "{unit} took a serious hit. Roll two dice before anyone else shoots."; "{n} criticals are waiting" caption; primary "Critical" / "Critical (2)".

**Target.**
- `CoachPrompt` with warning styling: icon `exclamationmark.triangle.fill` (warning token), title "CRITICAL HIT", line "(B) Locust took a serious hit. Roll two dice before anyone else shoots."
- Affected unit card pinned at the top with `StatusChip(.critOwed(n))`.
- Queue indicator when `count > 1`: "1 of 2" capsule.
- Dock primary: "Roll critical" / "Roll critical (1 of 2)" (was "Critical" — not a verb). Warning-tinted, not side-tinted (the crit belongs to the *target's* side but it's a shared moment).
- Haptic `.warning` when the state is entered.

---

### 6.17 Clean up (end phase)

**Today** (`BattleFlowView.swift:419-434`). "Take wrecks off the table." + last-turn info popover + all unit rows. Primary "Continue".

**Target.**

```
TURN 3 / 6       ROLL ✓ ── MOVE ✓ ── SHOOT ✓ ── CLEAN UP ●
                                                    [LAST TURN]   ← if turn == max

CLEAN UP
Take wrecked 'Mechs off the table.

REMOVE FROM THE TABLE                     ← only if any destroyedPendingEnd
 ┌ (B) Locust   🔥 Wrecked  — pick up this miniature ┐

STANDING                                     ← remaining units, compact HealthReadout
 (A) Shadow Hawk ■■■□□ ■■■■■   (A) Commando …
 (B) Wolverine   ■■■■■■ ■■■□□

SCORE IF THE GAME ENDED NOW                 ← only on last turn: structure totals per side
 (A) 7   vs   (B) 3      → Side A would win

            [ Next turn ]  or  [ Finish the game ]   ← dock primary
```

- The last-turn rule becomes visible (LAST TURN chip + "score if it ended now" card) instead of a popover (`:425-431`).
- Primary title: "Next turn" when the game continues, "See result" when `VictoryEvaluator` would end it — the view can check via the same evaluator used by the reducer (read-only), or `BattleCoach` can expose `endWouldFinishMatch` (§9).
- Removing wrecks: card per wreck with "Pick up this miniature" — players physically act; optional per-card "Done" check is pure UI sugar.

---

### 6.18 Victory (`as.victory`)

**Today** (`BattleFlowView.swift:900-944`). `ContentUnavailableView` with flag icon, "We have a winner" / "Draw" / "Game over", description "Side A wins after turn 4.\nSide A structure left: 7 · Side B: 3", buttons "Wait — go back", "Play again (same mission)" (prominent), "Back to Play"; rematch confirm.

**Problems.** Uses the system *empty state*; the winner is in body text; "Wait — go back" is the first button (reads like the main action); no celebration.

**Target.**

```
                 (no step header)

             🏆   (large, symbolEffect .bounce once)
          SIDE A WINS                 ← side color + badge, readout font
     Both enemy 'Mechs destroyed · Turn 4 of 6

┌ FINAL TALLY ─────────────────────────────┐
│ (A) Side A            7 structure left   │
│   Shadow Hawk  ■■■□□ ■■■■■               │
│   Commando     🔥 wrecked                │
│ (B) Side B            0                  │
│   Wolverine    🔥 wrecked turn 3         │
│   Locust       🔥 wrecked turn 2         │
└──────────────────────────────────────────┘
┌ MATCH STATS ─────────────────────────────┐   ← from eventLog / turnShot history
│ Shots 14 · Hits 9 (64%) · Crits 3        │
│ Best shot: Shadow Hawk → Wolverine, 3 dmg│
└──────────────────────────────────────────┘

[        Play again        ]   (primary)
[       Back to Play       ]   (secondary)
 Undo the last step            (tertiary text button, bottom)
```

- Draw variant: `equal.circle` symbol, "DRAW", neutral color.
- Turn-limit win variant: "More structure left after turn 6" subtitle.
- Celebration: `.success` haptic + symbol bounce; no confetti (non-goal: decorative particles). Reduce Motion → static.
- "Wait — go back" → "Undo the last step" as a low-emphasis text button at the bottom (it's an escape hatch, not a choice).
- Match stats require per-shot history; today `turnShot` resets each turn and `eventLog` holds strings. Either parse nothing and show only tallies we have (structure), or add structured events (§9). Stats card is optional for the first pass.
- Identifiers: keep `as.victory`, `as.victory.back`, `as.victory.rematch`, `as.victory.done`; add `as.victory.screen` (spec).

---

### 6.19 Shot solver sheet (`as.sator`)

**Today** (`CombatSolverSheet.swift`). `Form`, large detent, title "Shot solver". Step 1: two `Picker`s "Shooter" / "Target". Step 2: "{A} → {B}" headline; segmented Short/Medium/Long + caption; recorded-move line; `DisclosureGroup` "Anything unusual?" with a picker and five toggles plus a "More than 42 inches" button; `DiceRollEntry`; outcome section with TN numeral, Hit/Miss label, "Apply …" button; "If this hits" damage card with "What happens next" popover. Toolbar: Close, Change.

**Problems.**
- Default `Picker` rows for choosing 'Mechs hide the options behind a menu — two extra taps, and no health/status context.
- The TN (the screen's hero) sits *below* the dice entry and the modifier controls, so on iPhone it's often off-screen when you enter dice.
- No odds, no breakdown of how the TN was built (SATOR is the teaching core of the app).
- Hit is plain text color; no haptic; no animation.
- "Out of range" lives inside "Anything unusual?" as a button.
- Apply button sits in a list row mid-form instead of a fixed location.

**Target — step 1: pick the pair** (only when not prefilled):

```
Solve a shot                                [Close]

WHO'S SHOOTING?            (A) Side A
┌───────────────┐ ┌───────────────┐
│ Shadow Hawk   │ │ Commando      │   ← selectable UnitCards (compact), 2-up;
│ ■■■■■ ■■■■■   │ │ ✓ already shot│     disabled ones shown dimmed with reason
└───────────────┘ └───────────────┘

AT WHICH TARGET?           (B) Side B
┌───────────────┐ ┌───────────────┐
│ Wolverine     │ │ Locust        │
│ moved: Jumped │ │ moved: Walked │
└───────────────┘ └───────────────┘
```

Auto-advance to step 2 once both chosen (`TMMotion.reveal`). Identifiers `as.sator.attacker` / `as.sator.target` move to the two groups.

**Target — step 2: the shot.** Layout order puts the hero first and the apply button in a fixed bottom bar:

```
Shadow Hawk → Wolverine                    [Change] [Close]

┌ TNGauge ─────────────────────────────────┐
│  NEED  8+        42% to hit              │
│  ▁▂▃▅▆█▆▅▃▂▁  (bars ≥ 8 lit)             │
└──────────────────────────────────────────┘
  4 skill + 0 walked + 3 target jumped + 2 medium = 8     ← SATOR breakdown,
  (each term a chip: S 4 · A +0 · T +3 · O +0 · R +2)      tap a chip → explanation

RANGE   [ Short ≤6″ | Medium 7–24″ | Long 25–42″ ]  [>42″]
TARGET MOVED   Jumped (from the record)         [Change]
CONDITIONS     [Woods] [Partial cover] [Rear shot]   ← toggle chips, not Form toggles
               More…  (line of sight, front arc — rarely changed)

ROLL
  ⚀ ⚁ ⚂ ⚃ ⚄ ⚅   first die
  ⚀ ⚁ ⚂ ⚃ ⚄ ⚅   second die
  Let the app roll instead

┌ OutcomeBanner ───────────────────────────┐   ← appears when both dice set
│ ✓ HIT   rolled 9 vs 8+                   │
└──────────────────────────────────────────┘
┌ IF THIS HITS / DAMAGE ───────────────────┐
│ 2 damage to Wolverine                    │
│ Armor     ■■■■■■ 6 → ■■■■□□ 4            │   ← before/after PipTracks
│ Structure ■■■■■ 5 → 5                    │
│ Armor absorbs it. A critical only        │
│ happens on two 6s.                       │
└──────────────────────────────────────────┘

──────────── bottom bar (safeAreaInset, glass) ────────────
          [      Apply 2 damage      ]
```

- **SATOR breakdown chips** — `CombatSolve` already computes the TN from components; expose the components (S, A, T, O, R) so the UI can show them (§9). This turns the solver into the teaching tool the walkthrough HTML is. VoiceOver: "Target number 8: skill 4, attacker walked plus 0, target jumped plus 3, medium range plus 2."
- **Range** as a segmented control with the inch ranges in the segment labels (removes the separate caption); ">42″" as a separate small toggle chip because it's an exception, not a range band. Identifier `as.sator.range` preserved.
- **Conditions** as toggle chips (`Toggle` with `.toggleStyle(.button)`), the three common ones visible; "I can see the target" and "in front of the shooter" (rare, and they *block* the shot) under "More…" — when either is off, the TN gauge switches to the "Can't shoot" state with the reason. `as.sator.tgtMove` preserved on the target-move control.
- **Damage preview** uses `PipTrack` before/after (ghost pips for the damage), so players *see* what the hit will do before rolling. "What happens next" popover text becomes the inline line under the pips.
- **Apply** lives in a bottom `safeAreaInset` bar (glass), always visible; title rules unchanged ("Apply 2 damage" / "Apply miss" / "Apply hit"). Identifier `as.sator.resolve` preserved; add `as.sator.apply`.
- **After apply**: sheet dismisses; battle screen runs the damage-landing animation (§6.15). If a crit is owed, the battle screen's crit state + dock takes over (current behavior; AppShellSpec mentions crit stacked on SATOR — current single-sheet flow is simpler; keep it and update spec, §12).
- **No shots left** state: `EmptyState` with `checkmark.circle` "Side A has fired everything" + "Done shooting" button that dismisses and triggers `finishShooting` (today it's orange text telling the user to close and tap elsewhere — `CombatSolverSheet.swift:76-80`).
- Detents: keep `.large`. Title "Solve a shot" (matches the button that opens it; "Shot solver" is jargon).

---

### 6.20 Critical hit sheet (`as.crit`)

**Today** (`BattleFlowView.swift:946-1038`). `Form`, medium/large detents, title "Critical hit". Unit name + info popover (explanation + full preview); `DiceRollEntry`; one-line result headline when dice entered; "Apply this critical" button.

**Target** (`ux.critCard` — "Large 2D6 + crit name + confirm apply"):

```
Critical hit                                  [Close]
(B) Locust · 1 of 2

Roll two dice on the table, then tap the faces.
  ⚀ ⚁ ⚂ ⚃ ⚄ ⚅   first die
  ⚀ ⚁ ⚂ ⚃ ⚄ ⚅   second die

┌ RESULT ──────────────────────────────────┐
│ ⚂⚃  7   MOTIVE HIT                       │   ← big result name, icon per result
│ It moves half as far. A second one       │
│ stops it.                                │
└──────────────────────────────────────────┘

CRITICAL TABLE (reference)                         ← collapsed by default
 2 Ammo · 3 Engine · 4 Fire control · 5 None · 6 Weapon · 7 Motive
 8 Weapon · 9 None · 10 Fire control · 11 Engine · 12 Destroyed
 (rolled row highlighted)

──────── bottom bar ────────
     [  Apply motive hit  ]
```

- Result name + icon + full explanation shown inline (today split between headline and a popover).
- Severity styling: "No critical" (success-ish neutral), damaging results (warning), "Destroyed"/"Ammo — wrecked" (danger + flame).
- Reference table collapsed by default; highlights the rolled total.
- Apply title names the result ("Apply engine hit", "Apply — no effect").
- Identifiers: keep `as.crit.sheet`, `as.crit.die1`, `as.crit.die2`, `as.crit.confirm`, `as.crit.diceMode`, `as.crit.autoRoll`.
- Should be non-dismissable by swipe while a crit is owed? Today Close just returns to battle where the crit state persists — that's fine and safer; keep.

---

### 6.21 Unit Focus sheet (`as.unitFocus`)

**Today** (`UnitFocusSheet.swift`). List: Side, Status, "Card" + popover with stats; Armor section with `PipTrack` + "x of y left"; Structure section same; "Criticals so far" section; "This turn" (Moved, Shot); actions (Roll critical…, Solve a shot with this 'Mech…). Detents medium/large.

**Target** — this is the "unit card" screen and should look like one:

```
                 ─── (drag indicator)
(A) Shadow Hawk SHD-2H                         [Close]
SIDE A · SIZE 2 · [🔥 Wrecked · still fires]

┌ StatStrip ───────────────────────────────┐
│ MV 10″/6″j │ TMM 2 │ SKL 4 │ DMG 2·2·1   │   ← visible, not in a popover
└──────────────────────────────────────────┘

ARMOR                                   3/5
■■■□□                                     (large PipTrack)
STRUCTURE                               5/5
■■■■■

CRITICALS                                    ← only if any
 [Engine ×1] [Weapon ×1] [Fire control ×1] [Motive]
 Weapon hits reduce damage. Fire control adds 2 to its shots.

THIS TURN
 Moved   [🚶 Walked]
 Shot    [✓ Hit Locust · 2]   Rolled 9, needed 6.

ABILITIES
 IF0* · JMPW1                                 (tap → glossary, 1.x)

──────── bottom bar (when actions apply) ────────
 [  Shoot with Shadow Hawk  ]    or   [ Roll critical ]
```

- Stats are the header, not a popover. Effective values (after crits) shown; changed values marked with a small down-arrow + tooltip ("−1 from weapon hit").
- Move-mode chips (`ux.moveModeTokens`, 1.x) — the "Moved" row shows the chip; editing the move here (UnitFocusSpec: "configurable anytime on the sheet") can reuse the Change menu from §6.14.
- Actions in a bottom bar, side-tinted. Titles: "Shoot with Shadow Hawk" (was "Solve a shot with this 'Mech…"), "Roll critical" (was "Roll critical…").
- Read-only mode when opened from Force (no actions, no "This turn").
- Identifiers: keep `as.unitFocus.sheet`, `as.unitFocus.wounds.{id}` (on the armor PipTrack), `as.unitFocus.resolve.{id}`.

---

### 6.22 What just happened (event log)

**Today** (`BattleFlowView.swift:585-606`). Sheet with a `List` of the last 12 event messages, newest first; "Nothing yet." when empty.

**Target.**
- Full history, grouped by turn (`Section("TURN 3")`) then phase (sub-eyebrow with phase icon). `MatchEvent` already has `turn` and `phase` — grouping needs no domain change.
- Each row: leading icon by event type (dice, move, hit, miss, crit, wreck, phase), the message, trailing relative time. Icons need an event `kind` (§9); until then, derive from phase (initiative → dice, movement → walk, combat → scope, end → checklist).
- Side badge on rows that belong to a side (needs kind/side metadata — §9; optional).
- `EmptyState`: "Nothing yet — the log fills in as you play."
- Medium/large detents (keep). Title "Match log" (shorter; "What just happened" can stay as the toolbar button's accessibility label).
- Optional: "Undo last change" button at the top when `store.canUndo`, since this is where players go when they made a mistake.

---

### 6.23 Dialogs, alerts, errors, loading

**Inventory today:** replace-game dialog (Play), delete dialog + error alert (Settings), quit, go back, done shooting, skip moves, rematch dialogs (Battle), "Something went wrong" alert (Battle).

**Target.**
- Keep system `confirmationDialog`s (they are already Liquid Glass and correct). Standardize copy: title as a question, message states consequence in one sentence, destructive verb repeats the noun ("Discard game", "Delete saved games"), cancel says what you keep ("Keep playing"). See §8.
- On iPad, `confirmationDialog` renders as a popover anchored to the source — make sure each dialog is attached to the button that triggers it (several are attached to the root view today, which anchors them oddly on iPad).
- Replace inline red error rows with `ErrorBanner` + retry.
- Content-load failures (`BundleContentCatalogRepository`) are developer errors in practice; show a friendly `EmptyState` and log via `AppLog` (already done).
- Loading: skeletons via `.redacted(reason: .placeholder)` rather than spinners.

---

## 7. Cross-cutting concerns

### 7.1 Accessibility (AccessibilitySpec, WCAG 2.1 AA target)

- **Announcements**: phase change, side change, TN change (debounced 0.5 s), hit/miss, unit wrecked, crit result, victory. Use `AccessibilityNotification.Announcement` with `.announcementPriority(.high)` for outcomes.
- **Rotor headings**: Eyebrows and step titles get `.isHeader`.
- **Grouping**: every card is one element with a composed label; pips are never read pip-by-pip.
- **Custom actions**: Unit cards get `accessibilityActions` — "Shoot with this 'Mech", "Show card" — so VoiceOver users don't need to open Focus first.
- **Adjustable dice** (stretch): `accessibilityAdjustableAction` on each `DieFacePicker`.
- **Contrast**: all tokens validated; add a unit test that computes contrast ratios of token pairs from the asset catalog values (cheap, prevents regressions).
- **Reduce Motion / Reduce Transparency / Increase Contrast / Bold Text / Differentiate Without Color**: each has a preview variant; `DifferentiateWithoutColor` adds pattern fills to side cards if needed (the badges already carry shape).
- **Voice Control**: every icon-only button has a visible-name-matching `accessibilityInputLabels`.

### 7.2 Dynamic Type

- Test at default, XXXL, AX3, AX5.
- `ViewThatFits` / `AnyLayout(HStackLayout ↔ VStackLayout)` switch for: side-by-side cards (Table setup, initiative), move tiles (2×2 → 1 col), StatStrip (row → grid), dock (two buttons side-by-side → stacked).
- TN numeral scales via `@ScaledMetric` but caps at a max so the gauge stays on screen at AX5.
- Never truncate unit names; allow two lines.

### 7.3 Dark mode and outdoor legibility

- Default to system appearance; Settings can force.
- Dark mode is likely the "hero" appearance (matches the walkthrough mood); design both, screenshot both.
- Outdoor/bright: verify TN, pips and dock primary at max brightness in light mode (UX verification checklist).

### 7.4 iPad and landscape

- **iPad battle**: two columns — left: header + step tools (dice, move tiles, coach); right: both sides' unit cards (persistent). Dock spans bottom of the left column. `NavigationSplitView` is *not* needed — use a plain `HStack` inside the cover with a fixed 360 pt right column.
- **iPhone landscape** (`ux.landscapeSplit`, Phase 7 in spec): when `verticalSizeClass == .compact` and idiom is phone — unit strip (horizontal scroll of compact cards) on the leading side, tool on the trailing side. Phase track collapses to "Step 3/4 · Shoot".
- **iPad sheets**: solver and Focus present as form sheets; consider the solver as an inspector (`.inspector`) on iPad so the table stays visible — 1.x.
- **Rules** on iPad: two-column (topic list + detail) via `NavigationSplitView` inside the Rules tab (IOS26PlatformSpec mentions this as optional).
- **Pointer / keyboard**: `.hoverEffect` on cards; keyboard shortcuts in battle (Return = primary, ⌘Z = undo, 1–6 = die faces when a die picker is focused) — 1.x.

### 7.5 Localization readiness

- Move all user-facing strings into a String Catalog (`Localizable.xcstrings`) as part of the copy pass; use `LocalizedStringResource` in components. No translations in 1.0 (LocalizationSpec), but doing the extraction during the overhaul avoids a second pass over every view.
- Use `.formatted()` and `Measurement<UnitLength>` for inches so "10″" can localize later.

---

## 8. Copy and voice pass

Goal: same concept → same word everywhere; verbs on buttons; consequence in one line.

### 8.1 Global rules
- Always curly apostrophe: `’Mech`, `’Mechs`, `don’t`. Lint for `'Mech` in Swift string literals and JSON.
- Inches: `″` (double prime) consistently; spoken "inches" in a11y labels (already done).
- Sides: pick **one** of "Side A/B" or "Lance A/B" (§14 D1) and update specs or code accordingly.
- Buttons are verbs: "Roll critical", not "Critical"; "Miniatures placed", not "Placed".

### 8.2 Proposed string changes (code location → new copy)

| Where | Today | Proposed |
|-------|-------|----------|
| `primaryTitle .acknowledgeDeployment` | Placed | Miniatures placed |
| `primaryTitle .useInitiativeRolls` | {side} goes first / Use rolls | {winner} wins — start moving / Enter all four dice |
| `primaryTitle .rollInitiative` | Roll | Roll both sides |
| `primaryTitle .startShooting` | Start shooting | Start shooting (keep) |
| `primaryTitle .solveShot` | Solve a shot | Solve a shot (keep) |
| `primaryTitle .rollCritical` | Critical / Critical (2) | Roll critical / Roll critical (1 of 2) |
| `primaryTitle .resolveEnd` | Continue | Next turn / See result |
| Initiative result | {side} goes first | {winner} wins initiative · {loser} moves first |
| Move button `.standstill` | Still · under 1″ | Stood still · under 1″ (match recorded label) |
| `MovementMode.unset.displayName` | Tap to record… | Not recorded (UI-only instruction moves to the view) |
| Solver title | Shot solver | Solve a shot |
| Solver toolbar | Change | Change ’Mechs |
| Unit Focus action | Solve a shot with this ’Mech… | Shoot with {name} |
| Unit Focus action | Roll critical… | Roll critical |
| Victory | We have a winner | {Side} wins |
| Victory | Wait — go back | Undo the last step |
| Victory | Play again (same mission) | Play again |
| Battle menu | Quit and discard this game | Discard this game |
| Quit dialog title | Quit this game? | Discard this game? |
| Quit dialog destructive | Quit and discard | Discard game |
| Replace dialog destructive | Discard and start Ridge Line | Discard and start over |
| Event log title | What just happened | Match log |
| Getting Started title | New here | New here? (keep as nav title “Getting started”, list entry “New here?”) — decide one |
| Settings button | Delete saved games | Delete saved games (keep) — message adds “and your checklist” |

### 8.3 Content JSON
- `as-getting-started.json`: item `roster` ("Then tap Play Ridge Line") becomes the bottom CTA, not a checklist item.
- `as-rules-topics.json`: add `summary` (one line) and optional `group` per topic; optional structured `table` blocks (ContentPackSpec bump, schemaVersion 2 — or keep v1 and add optional fields, which `Codable` tolerates if they're optional).

---

## 9. Code architecture changes

The UI work needs these supporting changes. Each is small and testable.

### 9.1 Split `BattleFlowView.swift` (1,212 lines)

```
Features/Battle/
  BattleFlowView.swift            // shell: toolbar, dialogs, sheets, step switch (~250 lines)
  BattleHeader.swift              // TurnCounter + PhaseTrack + SideTag
  BattleDock.swift                // PhaseDock wiring: primaryTitle/hint/action
  Steps/
    TableSetupStep.swift
    PlaceMiniaturesStep.swift
    InitiativeStep.swift
    MovementStep.swift
    CombatStep.swift
    CriticalPendingStep.swift
    CleanUpStep.swift
  VictoryView.swift
  CritSheet.swift
  EventLogSheet.swift
  CombatSolverSheet.swift         // split further:
  Solver/
    SolverPairPicker.swift
    SolverShotView.swift
    SATORBreakdown.swift
    DamagePreviewCard.swift
  UnitFocusSheet.swift
DesignSystem/Components/
  DieFacePicker.swift, DiceTray.swift, DiceReadout.swift, PipTrack.swift, …
```

`PrintedMove` (`BattleFlowView.swift:1121-1178`) is display math on domain data — move it to `DesignSystem` or a `Features/Battle/Support` file and add unit tests.

### 9.2 Stop re-reading content in `body`
Load `RidgeLineScenarioDTO` once into the `MatchStore` (or a small `@Observable ScenarioPresentation`) at match start; `winningSummary`, `tableSteps`, scenario title, subtitle come from there. Removes `try?` decoding in `BattleFlowView.swift:299-319`.

### 9.3 Domain additions (small, additive, `Sendable`, tested)
1. **SATOR breakdown** — `CombatSolve` exposes `components: [SATORComponent]` (`letter`, `label`, `delta`) so the UI can render chips without re-deriving math in the view. Also expose `hitOdds: Int` (percent) from the WAYS_AT_LEAST table in SATORAttackSpec (golden vectors already list odds — add tests).
2. **Event kinds** — `MatchEvent.kind: MatchEventKind?` (`initiative`, `move`, `shot(hit: Bool)`, `critical`, `wrecked`, `phase`, `system`) and optional `side`/`unitId`. Verified: `SchemaV1` stores the whole session as an encoded `payload: Data` blob with a `payloadSchemaVersion` (`Persistence/SchemaV1/SchemaV1.swift`), so an **optional** new Codable property needs no SwiftData migration. Bump `payloadSchemaVersion` only if decoding old payloads would change behavior; document in DataSchemaSpec. Required for typed shot feed, typed log icons, and Victory stats.
3. **Shot ordering** — store `sequence` (monotonic Int) on `TurnShot` or derive the shot feed from typed events; delete the `hasPrefix(unit.name)` lookup (`BattleFlowView.swift:475`).
4. **Coach hints for UI** — `BattleCoach.endWouldFinishMatch: Bool` (for "Next turn" vs "See result") and `BattleCoach.isLastTurn: Bool`.
5. **Initiative roll-then-apply (auto mode)** — `MatchStore.previewAutoInitiative()` returning dice without applying, then `setInitiative` with them, so the UI can show the roll before advancing. Pure store change.

### 9.4 Preferences store
`@Observable AppPreferences` (in `AppDependencies`) backed by `UserDefaults`: `theme`, `hapticsEnabled`, `keepScreenAwake`, `defaultDiceMode`, `gettingStartedChecks: Set<String>`, `hasSeenIntro`. "Delete saved games" clears checks too (SettingsSpec).

### 9.5 Force tab data flow
Replace `forceLoads` token (`RootTabView.swift:12, 38-42`) with an observable "active session changed" signal from the repository or `AppDependencies` (e.g., `matchSessions` publishes a revision counter). Force and Play both observe it; Play's `refreshResume` on `onAppear` also goes away.

### 9.6 Lint
- SwiftLint `custom_rules`: `no_raw_colors` (regex on `\.(red|orange|green|blue|yellow)\b` and `Color\.(white|black|accentColor)` in `Features/`), `straight_apostrophe_mech` (regex `'Mech` in string literals).

---

## 10. Testing and verification

### 10.1 Previews
Every component and every battle step gets `#Preview`s with fixture sessions (`MatchSession` builders already exist in tests — move a `PreviewFixtures.swift` into the app target under `#if DEBUG`). Preview traits: `.sizeThatFitsLayout`, light/dark, `.environment(\.dynamicTypeSize, .accessibility5)`.

### 10.2 Snapshot tests
Add a snapshot testing target (e.g., `swift-snapshot-testing` via SPM in `project.yml`) for components and steps in light/dark × default/AX5. ~40 snapshots cover the overhaul; they prevent the visual regressions a 1,200-line refactor will otherwise cause.

### 10.3 UI tests
There is no UI test target yet (`project.yml` has `MechBuddyTests` only). Add `MechBuddyUITests` with the Phase 6 happy path driven entirely by the identifiers in §16 — this is what proves the overhaul didn't break the slice. Launch with an in-memory store argument.

### 10.4 Unit tests
- `PrintedMove` parsing (moved out of the view).
- SATOR components + odds (§9.3).
- Token contrast ratios (§7.1).
- `BattleCoach` new flags.

### 10.5 Manual verification checklist (per UXVisualPolishSpec)
- [ ] Outdoor/bright: TN and pips readable at arm's length
- [ ] Dark + Light: glass samples content without mud
- [ ] Reduce Transparency + Reduce Motion: no illegible glass; no motion
- [ ] AX5: TN, dice, dock usable
- [ ] VoiceOver: full Ridge Line game playable eyes-free (hit/miss, phase, side, pip counts announced)
- [ ] iPad portrait/landscape; iPhone SE-size width; iPhone Pro Max landscape
- [ ] Hotseat test with two real people: does the next player notice their turn?

---

## 11. Phased rollout

Each phase is one or more PRs; each ends green on `MechBuddyCI` and the manual checklist for touched screens.

### Phase U0 — Foundations (≈2–3 days)
- Tokens (color assets with light/dark/high-contrast), `TMFont`, `TMSpace`, `TMRadius`, `TMMotion`, `TMHaptics`.
- `AppPreferences` + Settings toggles for haptics/theme/keep-awake (Settings UI can stay simple until U5).
- Root tint, launch background color.
- `PreviewFixtures`.
- App icon (can run in parallel — design dependency).
- **DoD:** no visible change except tint/launch; previews compile; tokens documented in DesignSystemSpec Verification.

### Phase U1 — Component library (≈4–5 days)
- §5.1–5.19, 5.23–5.25 with previews and snapshots.
- Replace `DiceFaces` → `DieFacePicker` and `PipTrack` v2 in place (first visible upgrade, low risk).
- **DoD:** snapshot suite green; existing screens use new dice + pips; identifiers unchanged.

### Phase U2 — Battle table (≈5–7 days) — highest impact
- Split `BattleFlowView` (§9.1) *first*, as a no-visual-change PR.
- Header strip + `PhaseDock` + `ScrollView` card layout.
- Steps in order: Combat → Movement → Initiative → Clean up → Pending crit → Place → Table setup.
- Side theming, side-change banner, announcements, haptics, damage-landing animation.
- **DoD:** full Ridge Line playable; UI test happy path green; VoiceOver pass on battle.

### Phase U3 — Sheets (≈4–5 days)
- Shot solver (needs §9.3.1 SATOR components + odds).
- Crit sheet, Unit Focus, Event log (typed icons need §9.3.2; ship phase-derived icons first).
- Victory screen.
- **DoD:** solver usable at AX5 with TN on screen while entering dice; crit names visible without popovers.

### Phase U4 — Play home & onboarding (≈3 days)
- ResumeCard, MissionCard, Classic sheet, remove sleep hack.
- Getting Started checklist + annotated card.
- How to play visual walkthrough.
- **DoD:** onboarding reachable in one tap; checklist persists; How to play renders real components.

### Phase U5 — Force, Rules, Settings (≈3 days)
- Force display cards + PV bar + read-only Focus.
- Rules grouping, icons, search, typography; optional structured tables.
- Settings full layout.
- **DoD:** each tab passes the verification checklist.

### Phase U6 — iPad, landscape, polish (≈3–4 days)
- iPad battle two-column; phone landscape split; iPad Rules split view.
- Copy pass + String Catalog extraction.
- Full a11y audit; contrast test; final snapshot refresh.
- App Store screenshots (light + dark, iPhone + iPad) from the polished build.
- **DoD:** UXVisualPolishSpec MVP items all checked; spec Verification blocks updated with commit + code paths.

**Rough total:** 24–30 focused days for one engineer. U0–U2 alone (≈2 weeks) delivers ~70% of the perceived quality jump.

---

## 12. Spec and doc updates required

Per SpecGovernance, these must change in the same PRs as the behavior:

| Spec | Change |
|------|--------|
| DesignSystemSpec | Document concrete token values, type tokens, component list with file paths; fill Verification (code paths, commit). Record SF Pro width variants as the brand display face (no custom font). |
| UXVisualPolishSpec | Check off MVP items as delivered; move `ux.pvMeter`, `ux.critCard`, `ux.moveModeTokens`, `ux.emptyStates` to "MVP (done)" if shipped early. |
| BattleTableSpec | Initiative is an **inline step**, not a sheet; dock contents = secondary + primary (coach-driven), not Phase/My Unit/Attack/Done; header = TurnCounter + PhaseTrack + active side; phase chips are read-only in 1.0. |
| AppShellSpec | Crit flow: battle-screen crit state after SATOR dismiss (not stacked on SATOR); Classic coming soon = sheet; How to play / Getting Started pushed from Play. |
| SATORAttackSpec | Solver shows SATOR component chips + odds; title "Solve a shot"; conditions as chips. |
| GettingStartedSpec | Spec checklist ids (`dl_qs`, `cards`, `dice`, `tape`, `maps`, `roster`) no longer match `as-getting-started.json` (`what`, `dl_qs`, `minis`, `dice`, `tape`, `maps`, `roster`). Align the spec to the JSON; progress becomes "N / 6" once `roster` turns into the bottom CTA (§6.4). |
| SettingsSpec | Add "Keep screen awake"; "Dice" default; ordering. |
| AccessibilitySpec | Add new identifiers (§16); note retained legacy ids. |
| ScreenCatalog | Add `as.mission.setup` mapping to table setup; `classic.modeHome` sheet; event log `as.battle.log`. |
| HotseatSpec / UXVisualPolishSpec | Reconcile "Lance A" vs "Side A" (§14 D1). |
| DataSchemaSpec | If `MatchEvent.kind` is added (§9.3.2), document optional field / schema version. |
| ContentPackSpec | Optional `summary`, `group`, structured `table` blocks in rules topics. |
| docs/feature-inventory.md | It still says "code not started" for everything — update statuses while touching it. |

---

## 13. Risks and mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Identifier drift breaks tests / spec contract | High during U2 | §16 table; add the UI test target before U2; never remove, only add ids |
| `List` → `ScrollView` loses free a11y/keyboard behavior | Medium | Explicit `.isHeader`, focus order, `accessibilityElement(children: .combine)` on cards; VoiceOver pass per phase |
| Custom glass misuse (stacked glass, muddy sampling) | Medium | Glass only in dock + solver/crit bottom bars; all inside `GlassEffectContainer`; Reduce Transparency check |
| Over-branding ("neon cockpit") | Medium | Per-screen brand budget table; one amber moment per screen; review screenshots against §3.2 |
| Animations slow down play | Low–Med | All ≤ 0.45 s; never block input; Reduce Motion path |
| Big-bang refactor conflicts with feature work | Medium | Split-file PR first with zero visual change; then one step per PR |
| Old saved payloads decode without the new event `kind` | Low | Make the field optional and fall back to phase-derived icons for older events |
| Scope creep into roster editing / Free Battle | Medium | Force tab stays display-only; editing is RosterSpec work, not this plan |
| Haptics feel punitive on miss | Low | Device testing; soft feedback; toggle in Settings |

---

## 14. Open decisions for the owner

| # | Decision | Recommendation |
|---|----------|----------------|
| D1 | "Side A/B" (code) vs "Lance A/B" (specs) | **Side A/B** — plainer for first-timers; the app's own copy already teaches "a lance is a team". Update specs. |
| D2 | Side colors | **A = coolant teal-blue, B = ember orange**, amber reserved for "do this now". Alternative: A = coolant, B = signal amber (fewer colors, but B and the CTA tint collide). |
| D3 | Dark-first or system appearance by default | **System**, with dark as the hero in screenshots. |
| D4 | How to play / Getting Started: push or sheet | **Push** from Play (reference content; keeps tab bar; kills the sleep hack). |
| D5 | Dice mode picker visibility | Keep a small "Let the app roll" link in-context + default in Settings; drop the segmented picker from every dice screen (physical dice primary). |
| D6 | Table-setup steps as tappable checks | **Yes, session-local, non-blocking.** Or plain numbered list if zero new state is preferred. |
| D7 | Typed `MatchEvent.kind` in 1.0 | **Yes.** Events live inside the encoded session payload, so an optional field needs no SwiftData migration (§9.3). |
| D8 | Weight-class glyphs (`ux.weightGlyph`, Later tier) | Defer to 1.x. |
| D9 | Victory "match stats" card | Ship structure tallies in 1.0; shot stats once D7 lands. |
| D10 | App icon: commission vs in-house | Commission (it's the one asset that most signals "real product"). |
| D11 | Default skill setting (SettingsSpec) in 1.0 | Hide until Free Battle (Ridge Line is fixed at skill 4). |

---

## 15. Quick wins

Each is < 1 hour, low risk, and visibly improves polish. Good first PR.

1. `DieFacePicker`: swap numerals for `die.face.N(.fill)` symbols and fix white-on-amber contrast (`BattleFlowView.swift:1193-1201`).
2. Color the Hit outcome with success green + `checkmark.circle.fill` (`CombatSolverSheet.swift:263-268`) and add `.sensoryFeedback(.success/.error, trigger:)`.
3. `PipTrack`: armor vs structure colors + hollow lost pips (`UnitFocusSheet.swift:151`).
4. Add compact `PipTrack`s to battle unit rows in place of "Armor x/y" text (`BattleFlowView.swift:551-556`).
5. Primary button titles: "Miniatures placed", "Roll critical", "Next turn" (§8.2).
6. `.contentTransition(.numericText())` + `.monospacedDigit()` on dice totals and TN.
7. Toolbar menu icon `ellipsis.circle` → `ellipsis`.
8. Curly-apostrophe sweep (`'Mech` → `’Mech`) in Swift and JSON.
9. Replace `ContentUnavailableView` on Victory with a simple header + buttons reordered (primary first, "Undo the last step" last).
10. Make "How to play" and "New here?" visible rows on Play; delete the `Task.sleep` path.
11. Post `AccessibilityNotification.Announcement` on phase/side change.
12. Move "What just happened" to its own toolbar button.

---

## 16. Appendix: identifier preservation table

Every identifier present in code at `bd4cb5e`, with where it moves. **Keep = must still exist after the overhaul.** "Add" = spec ids to add alongside.

| Identifier | Today (file) | After overhaul | Action |
|-----------|-------------|----------------|--------|
| `play.home` | PlayHomeView | Play ScrollView root | Keep |
| `as.modeHome.resume` | PlayHomeView | ResumeCard Continue button | Keep |
| `as.modeHome.ridgeLine` | PlayHomeView | MissionCard primary | Keep |
| `as.modeHome.gettingStarted` | PlayHomeView (popover) | MissionCard "New here?" link | Keep |
| `as.modeHome.howToPlay` | PlayHomeView (popover) | MissionCard "How to play" link | Keep |
| `play.classicComingSoon` | PlayHomeView | Classic row | Keep |
| `classic.comingSoon.playAS` | PlayHomeView (popover) | Classic sheet primary | Keep; add `classic.modeHome` on sheet |
| `as.gettingStarted.screen` | GettingStartedView | same | Keep |
| `as.gettingStarted.check.{id}` | GettingStartedView | ChecklistRow | Keep |
| `as.howToPlay.screen` | HowToPlayRidgeLineView | same | Keep |
| `force.as.list` | ForcePlaceholderView | Force root | Keep |
| `force.as.unit.{name}` | ForcePlaceholderView | ForceUnitCard | Keep; add `force.as.unit.{id}` |
| `rules.home` | RulesHomeView | same | Keep |
| `rules.as.{topicId}` | RulesHomeView | topic row | Keep |
| `rules.as.detail.{topicId}` | RulesTopicDetailView | same | Keep |
| `settings.home` | SettingsHomeView | same | Keep |
| `settings.deleteAll` | SettingsHomeView | Data section | Keep |
| `as.battle.leave` | BattleFlowView toolbar | same | Keep |
| `as.battle.more` | BattleFlowView toolbar | same | Keep |
| `as.battle.back` | menu | menu | Keep |
| `as.battle.table` | step headline | CoachPrompt title | Keep |
| `as.battle.activeSide` | hidden element | header SideTag | Keep (same label/value contract) |
| `as.battle.screen` | battle List | battle ScrollView | Keep |
| `as.battle.primary` | bottom bar | PhaseDock primary | Keep; add `as.battle.phaseDock.next` |
| `as.battle.doneShooting` | bottom bar | PhaseDock secondary | Keep; add `as.battle.phaseDock.doneSide` |
| — | — | PhaseDock container | Add `as.battle.phaseDock` |
| — | — | PhaseTrack segments | Add `as.battle.phase.{initiative,movement,combat,end}` |
| `as.battle.swapSides` | table setup header | Who's who header | Keep |
| `as.ridge.tablePrep` | table setup List | table setup root | Keep; add `as.mission.setup` |
| `as.ridge.tableReady` | Start button | dock primary on setup | Keep; add `as.mission.startBattle` |
| `as.battle.unit.{uuid}` | unit rows | UnitCard | Keep |
| `as.battle.shot.hit` / `.miss` | shots list | shot feed rows | Keep |
| `as.battle.move.{mode}` | move buttons | move tiles | Keep |
| `as.battle.rollInit` | initiative dice-mode picker | "Let the app roll" control | Keep |
| `as.initiative.tieHint` | tie text | tie card | Keep |
| — | — | initiative dice | Add `as.initiative.lanceA.die1` … `lanceB.die2`, `as.initiative.confirm` |
| `as.victory` | VictoryView | Victory root | Keep; add `as.victory.screen` |
| `as.victory.back` / `.rematch` / `.done` | VictoryView | same buttons | Keep |
| `as.crit.sheet` | CritSheet | same | Keep |
| `as.crit.diceMode` / `.autoRoll` / `.die1` / `.die2` / `.confirm` | DiceRollEntry / CritSheet | DiceTray / bottom bar | Keep |
| `as.sator.sheet` | CombatSolverSheet | same | Keep |
| `as.sator.attacker` / `.target` | pickers | card groups | Keep |
| `as.sator.range` | segmented | segmented | Keep |
| `as.sator.tgtMove` | picker | Target-moved control | Keep |
| `as.sator.tnPreview` | TN VStack | TNGauge | Keep; add `as.sator.tn` |
| `as.sator.outcome` | Hit/Miss label | OutcomeBanner | Keep |
| `as.sator.resolve` | Apply button | bottom bar | Keep; add `as.sator.apply` |
| `as.sator.diceMode` / `.autoRoll` / `.die1` / `.die2` | DiceRollEntry | DiceTray | Keep |
| `as.unitFocus.sheet` | UnitFocusSheet | same | Keep |
| `as.unitFocus.wounds.{uuid}` | armor section | armor PipTrack | Keep |
| `as.unitFocus.resolve.{uuid}` | shoot button | bottom bar | Keep |
| — | — | event log sheet | Add `as.battle.log` |
