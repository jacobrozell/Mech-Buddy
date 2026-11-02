# UX / Visual Polish Spec — Mech Buddy

**Status:** Authoritative for visual and interaction polish.  
**Companion:** [DesignSystemSpec](DesignSystemSpec.md) · [IOS26PlatformSpec](IOS26PlatformSpec.md) · [AccessibilitySpec](AccessibilitySpec.md)

Principle: **tableside glanceability** + **iOS 26 content-first chrome**. Brand lives in content (TN, pips, prompts); navigation stays system Liquid Glass. Do not rebuild the HTML walkthrough as full-screen cockpit chrome.

---

## Tier legend

| Tier | Meaning |
|------|---------|
| **MVP** | Required for 1.0 Ridge Line vertical slice feel |
| **1.x** | Ship when surface ungates or after first TestFlight feedback |
| **Later** | Delight / marketing — not a release blocker |

Every MVP item needs a non-color cue and Dynamic Type path (see AccessibilitySpec).

---

## MVP (done)

Shipped in app **0.2.0** (tag `0.2.0`).

### SATOR / combat

| ID | Improvement | Notes |
|----|-------------|-------|
| `ux.tnHero` | Large TN numeral + odds bar as hero content | `TNGauge`: “N+”, “P% to hit”, histogram. Opaque readout, not glass |
| `ux.hitMiss` | Hit/miss: text label + semantic color + haptics | `OutcomeBanner`; `.success` on hit, soft impact on miss |
| `ux.satorRunningTN` | Show the running TN as SATOR terms change | Summary chips plus the gauge. VoiceOver reads the gauge as a header |

### Roster / damage

| ID | Improvement | Notes |
|----|-------------|-------|
| `ux.pipTrack` | Arm’s-length pip tracks (armor vs structure) with counts | `PipTrack` / `HealthReadout` on battle cards, Unit Focus, and Getting Started |
| `ux.sideIdentity` | Side A/B: badge color **and** the words “Side A” / “Side B” | Circle + coolant for Side A. Diamond + ember for Side B. Signal amber is the action color |

### Battle table

| ID | Improvement | Notes |
|----|-------------|-------|
| `ux.phasePrompt` | One-line coach prompt primary; chips secondary | `CoachPrompt` in the step. `PhaseTrack` is read-only: icon, label, checkmark when done, selected trait on the current step |
| `ux.phaseDockGlass` | Phase dock in `GlassEffectContainer` | Coach-driven secondary + primary (`PhaseDock`). See BattleTableSpec |
| `ux.resumeCard` | Play home resume: scenario · turn · phase | `ResumeCard` also shows Side A / Side B structure bars. Continue is the signal button |

### Platform (free with correct APIs)

| ID | Improvement | Notes |
|----|-------------|-------|
| `ux.tabMinimize` | `.tabBarMinimizeBehavior(.onScrollDown)` on the root `TabView` | `RootTabView` |
| `ux.sidebarAdaptable` | `.tabViewStyle(.sidebarAdaptable)` | iPad |
| `ux.defaultSheets` | System sheet glass; no custom `presentationBackground` | Detents + drag indicator on solver, crit, Unit Focus, log, Classic |
| `ux.brandInContent` | Brand fills inside scroll content for glass sampling | Per IOS26PlatformSpec |

### Motion (MVP, Reduce Motion aware)

| ID | Improvement | Notes |
|----|-------------|-------|
| `ux.motionDice` | Short feedback on 2D6 resolve | `DiceTray` haptic; initiative readout uses `tmSymbolBounce` |
| `ux.motionPhase` | Discrete phase change feedback | `PhaseTrack` uses `TMMotion.phase`. Pass-the-phone banner on side change |
| `ux.motionApply` | Feedback when damage applies to pips | `PipTrack` drain, staggered; skipped flourish when Reduce Motion is on |

### Explicit non-goals (MVP)

- Full-bleed mech-cockpit chrome on every screen  
- Stacked neon panels / multiple competing brand moments per screen  
- Licensed ’Mech art or scanned record sheets  
- Decorative particle / heat-haze effects  

---

## MVP (done) — shipped early

These were listed as 1.x. The 0.2.0 app already includes them.

| ID | What ships | Notes |
|----|-------------|-------|
| `ux.moveModeTokens` | Recorded move as a `StatusChip` on Unit Focus (“Stood still”, “Walked”, “Jumped”, “Sprinted”) | Movement step uses the same four modes as buttons |
| `ux.critCard` | `CritSheet`: dice tray, large readout, result name, confirm | Opens from the battle screen after the solver dismisses |
| `ux.pvMeter` | Force tab `PVBalanceBar`: Side A vs Side B bar and a gap line | “Even”, “Gap N — even” through 5, otherwise “Gap N — {side} ahead” |
| `ux.emptyStates` | `EmptyState`: symbol, title, message, optional button | Force load failure, rules search, solver with nothing left to shoot, empty match log |
| `ux.landscapeSplit` | Phone landscape: unit strip beside the step. iPad regular width: step beside a roster column | `BattleStageLayout` |
| `ux.symbolEffects` | `tmSymbolBounce` on dice landings and the victory mark | Omitted when Reduce Motion is on |
| `ux.hapticsSetting` | Settings → Haptics, default on | `TMHaptics` reads `hapticsEnabled` |

## 1.x polish

| ID | Improvement | Notes |
|----|-------------|-------|
| `ux.heatScale` | Vertical 0–4 heat with shutdown state | Heat is stored on the unit and added into SATOR. No heat scale is on screen |

---

## Later (delight / marketing)

| ID | Improvement | Notes |
|----|-------------|-------|
| `ux.weightGlyph` | Abstract weight-class silhouette per unit | Deferred. No glyph component in the app |
| `ux.commTapeLog` | Compact match log styling | |
| `ux.rulesShare` | Share / print-friendly Rules tables | |
| `ux.turnWidget` | Home-screen widget: Turn N · phase | Post–App Intents readiness |
| `ux.customDisplayFont` | Optional condensed display for TN only | Unused. TN uses SF Pro Rounded. See DesignSystemSpec |

---

## Per-screen brand budget

One primary brand moment per screen:

| Screen | Primary moment |
|--------|----------------|
| `as.sator` | TN gauge |
| `as.battle` | Phase prompt (+ dock as glass UI) |
| `force.as.list` / Unit Focus | Pip tracks |
| `as.modeHome` | Resume / primary CTA (signal tint on button only) |
| Rules topics | Tables — minimal brand; readable first |

---

## Verification checklist (before claiming polish done)

- [ ] Outdoor / bright ambient: TN and pips readable  
- [ ] Dark Mode + Light Mode: glass samples content without mud  
- [ ] Reduce Transparency + Reduce Motion: no illegible custom glass  
- [ ] AXXXL: TN and dock usable (alternate layout OK)  
- [ ] VoiceOver: hit/miss, phase, pip counts announced  

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 (MVP tier) / 1.x (`ux.heatScale` and Later) |
| Last verified | 2026-10-28 |
| Commit | `b9acebb` (tag `0.2.0`) |
| Code paths | `DesignSystem/Components/TNGauge.swift`, `OutcomeBanner.swift`, `PipTrack.swift`, `SideBadge.swift`, `PhaseTrack.swift`, `PhaseDock.swift`, `ResumeCard.swift`, `EmptyState.swift`; `Features/Battle/BattleFlowView.swift`, `CombatSolverSheet.swift`, `CritSheet.swift`, `VictoryView.swift`; `Features/Play/PlayHomeView.swift`, `ForceListView.swift`; `App/RootTabView.swift`, `App/AppPreferences.swift` |
