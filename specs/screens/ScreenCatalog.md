# Screen Catalog — Mech Buddy (mobile)

Master inventory of **every user-visible screen / sheet / dock**. Authoritative for IA. Feature specs own detailed behavior.

**Layout principle:** organize by tableside jobs, not by the nine HTML tabs.

```
Root tabs
├── Play
│   ├── Mode picker (if >1 reachable mode)
│   ├── Mode home
│   ├── Getting Started
│   ├── Scenario catalog
│   ├── Guided mission setup
│   ├── Battle table (+ sheets)
│   └── Match summary / history
├── Force
│   ├── Roster list
│   ├── Unit editor / Unit Focus
│   └── Import (MUL paste)
├── Rules
│   ├── Topic list (mode-filtered)
│   └── Topic detail / tables
└── Settings
    ├── Preferences
    └── Legal / delete data
```

---

## Root chrome

| ID | Screen | Type | Modes | Spec |
|----|--------|------|-------|------|
| `root.tabs` | Root `TabView` (Liquid Glass) | Screen | Both | [AppShellSpec](../AppShellSpec.md), [IOS26PlatformSpec](../IOS26PlatformSpec.md) |
| `play.home` | Play **shell** (resume + routes to mode home) | Screen | Both | [ModeHomeSpec](../features/ModeHomeSpec.md) |
| `force.as.list` | Force tab. Ridge Line roster, or the match in progress | Screen | Both | [RosterSpec](../features/RosterSpec.md) |
| `rules.home` | Rules browser home | Screen | Both | [RulesReferenceSpec](../features/RulesReferenceSpec.md) |
| `settings.home` | Settings | Screen | Both | [SettingsSpec](../features/SettingsSpec.md) |

---

## Play — shared

| ID | Screen | Type | Primary job | Release |
|----|--------|------|-------------|---------|
| `play.modePicker` | Choose Alpha Strike or Classic | Screen | Pick ruleset | Classic gated |
| `play.resumeBanner` | Resume in-progress match | `ResumeCard` on Play | Continue | MVP |
| `play.classicComingSoon` | Classic BattleTech row on Play | Row | Opens the coming-soon sheet | MVP |
| `play.matchHistory` | Past matches list | Screen | Review | Planned |
| `play.matchDetail` | Match summary | Screen | Review | Planned |

---

## Play — Alpha Strike

| ID | Screen | Type | Maps from HTML | Spec |
|----|--------|------|----------------|------|
| `as.modeHome` | Alpha Strike home | Screen | (new) | ModeHome |
| `as.gettingStarted` | Pre-game checklist + sample card | Push from Play | Set up | GettingStarted |
| `as.howToPlay` | Ridge Line app-flow walkthrough | Push from Play | (new) | ModeHome |
| `as.scenarios` | First games catalog | Screen | First games | GuidedMission |
| `as.mission.setup` | Table setup, first step of the battle cover. Stage id on that step is `as.ridge.tablePrep`. Checks are session-local and do not block Start battle | Step | Mission setup | BattleTable |
| `as.mission.ridgeLine.setup` | Same step as `as.mission.setup` for Ridge Line | Step | Mission steps 1–2 | GuidedMission |
| `as.mission.fullLances.setup` | Full Lances setup | Screen | First games G2 | GuidedMission (v1.x) |
| `as.battle` | Battle table | Screen | Turn, phase track, side, coach step | BattleTable |
| `as.battle.phaseDock` | Coach secondary + primary | Chrome | Glass dock | BattleTable |
| `as.initiative` | Initiative dice, inline on the battle step | Step | Turn · Roll | BattleTable |
| `as.moveCoach` | Movement modes on the movement step | Step | Move | BattleTable |
| `as.sator` | Shot solver, title **Solve a shot** | Sheet | Shoot | SATORAttack |
| `as.critRoll` | Critical table roller, after the solver dismisses | Sheet | Damage crit table | BattleTable / SATORAttack |
| `as.battle.log` | Match log | Sheet | Toolbar “What just happened” | BattleTable |
| `as.heatCoach` | Heat effects reference | Sheet | Damage · Heat | Planned |
| `as.physicalCoach` | Physical attack helper | Sheet | Damage · Physical | Planned (Game 2) |
| `as.victory` | Victory. Structure tally; shot stats parsed from log sentences when any exist | Screen | Mission winning | GuidedMission / BattleTable |
| `as.unitFocus` | Unit Focus sheet | Sheet | Roster unit card | UnitFocus |

---

## Force — Alpha Strike

| ID | Screen | Type | Maps from HTML | Spec |
|----|--------|------|----------------|------|
| `force.as.list` | Side A / Side B roster + PV bar | Screen | Roster | Roster |
| `force.as.unitEdit` | Edit stats / flip variant | Screen or push | Roster unit | Planned |
| `force.as.import` | MUL paste import | Sheet | Roster import | Planned |
| `force.as.addUnit` | Add blank / pick template | Sheet | Add a 'Mech | Planned |

---

## Rules — Alpha Strike

| ID | Screen | Type | Maps from HTML | Spec |
|----|--------|------|----------------|------|
| `rules.as.home` | Topic list | Screen | Tables + coaching tabs | RulesReference |
| `rules.as.turn` | Turn sequence | Detail | The turn | RulesReference |
| `rules.as.movement` | Movement modes & terrain | Detail | Move | RulesReference |
| `rules.as.combat` | LOS / arc / range | Detail | Shoot intro | RulesReference |
| `rules.as.satorRef` | SATOR field reference | Detail | Shoot stack labels | RulesReference |
| `rules.as.damage` | Armor / structure / crits / heat | Detail | Damage & heat | RulesReference |
| `rules.as.tables` | Compact modifier tables | Detail | Tables | RulesReference |
| `rules.as.abbreviations` | Card abbreviations | Detail | Tables · abbreviations | RulesReference |

---

## Classic mode

`classic.modeHome` is the coming-soon sheet. The rows under it stay planned until Classic play ships. Full behavior: [ClassicModeSpec](../features/ClassicModeSpec.md).

| ID | Screen | Type | Job |
|----|--------|------|-----|
| `classic.modeHome` | Classic coming soon | Sheet from Play | Explains record sheets, heat, and hit locations. Primary action plays Ridge Line |
| `classic.gettingStarted` | Hex / record-sheet orientation | Screen | Onboarding |
| `classic.battle` | Classic battle table | Screen | Phases |
| `classic.phaseDock` | Classic phase dock | Chrome | Init→Heat |
| `classic.recordSheet` | Record sheet (hit locations) | Screen/Sheet | Damage |
| `classic.heatScale` | Heat scale tracker | Sheet | Heat |
| `classic.weaponAttack` | Weapon TN + location | Sheet | Fire |
| `classic.hitLocation` | Hit location table roller | Sheet | Location |
| `classic.critical` | Critical hit (location) | Sheet | Crits |
| `classic.piloting` | Piloting skill roll helper | Sheet | PSR |
| `classic.physical` | Kick / punch / charge / DFA | Sheet | Physical |
| `classic.unitFocus` | Unit Focus (weapons + heat) | Sheet | Unit |
| `force.classic.list` | Classic force list | Screen | Roster |
| `force.classic.sheetEdit` | Edit record sheet | Screen | Setup |
| `rules.classic.*` | Classic rules topics | Detail | Reference |

---

## Settings

| ID | Screen | Type | Spec |
|----|--------|------|------|
| `settings.home` | Dice default, haptics, keep screen awake, theme, about, legal, delete | Screen | Settings |
| `settings.legal` | Privacy / support / accessibility / disclaimer | Links | Settings |
| `settings.deleteAll` | Delete saved games, with a confirm dialog | Button | Settings |

---

## Shared components (not screens, but named)

| ID | Component | Used by |
|----|-----------|---------|
| `chrome.empty` | Empty state | Lists |
| `chrome.errorBanner` | Recoverable error | All |
| `chrome.diceResult` | 2D6 readout | Initiative, SATOR, Crit |
| `chrome.pipTrack` | Armor/structure pips | Roster, Unit Focus |
| `chrome.phaseChip` | Read-only phase track (Roll, Move, Shoot, Clean up) | Battle header |

---

## HTML → mobile remapping (summary)

| HTML tab | Mobile destination |
|----------|-------------------|
| Mission | `as.mission.*.setup` + `as.battle` |
| Set up | `as.gettingStarted` |
| The turn | `rules.as.turn` + battle phase dock prompts |
| Move | `rules.as.movement` + `as.moveCoach` |
| Shoot | `as.sator` sheet from battle |
| Damage & heat | SATOR apply + `as.critRoll` / rules topics |
| First games | `as.scenarios` |
| Roster | Force tab |
| Tables | Rules tab |

---

## Accessibility identifiers

Convention: `{area}.{screen}.{control}` — e.g. `as.sator.resolve`, `force.as.unit.{uuid}`, `as.battle.phaseDock.next`. The live set is in [AccessibilitySpec](../AccessibilitySpec.md).

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 (AS subset) |
| Last verified | 2026-10-28 |
| Commit | `b9acebb` (tag `0.2.0`) |
| Code paths | `App/RootTabView.swift`, `Features/Play/PlayHomeView.swift`, `ClassicComingSoonSheet.swift`, `Features/Battle/BattleFlowView.swift`, `Steps/TableSetupStep.swift`, `EventLogSheet.swift`, `VictoryView.swift` |

**IA note:** `play.home` is the Play shell. The Force tab’s screen id is `force.as.list`. Do not add a second home without updating AppShellSpec.
