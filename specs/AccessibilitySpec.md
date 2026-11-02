# Accessibility Spec — Mech Buddy

## Target

WCAG 2.1 AA for Ridge Line happy path. Platform: [IOS26PlatformSpec](IOS26PlatformSpec.md).

## Requirements

| Area | Rule |
|------|------|
| VoiceOver | Labels + hints; TN/phase/side announced |
| Dynamic Type | Through AXXXL on battle + SATOR |
| Contrast | Content tokens; glass uses system adaptation |
| Touch | ≥44×44 pt |
| Motion / transparency | Respect Reduce Motion / Transparency |
| Non-color | Hit/miss, side, phase |

## Identifier convention

`{area}.{screen}.{control}` — use **ScreenCatalog** IDs. Unit ids: `as.battle.unit.{uuid}`.

### Identifiers in the 0.2.0 app

SwiftUI keeps one identifier on an element. Where a control already had an id, the newer id sits on a non-interactive sibling (`accessibilityIdentifiers` in `DesignSystem/AccessibilityID.swift`). Both stay findable.

Play, Force, Rules, Settings:

```
play.home
as.modeHome.resume
as.modeHome.ridgeLine
as.modeHome.gettingStarted
as.modeHome.howToPlay
as.gettingStarted.screen
as.gettingStarted.check.{id}
as.howToPlay.screen
as.howToPlay.sampleWreck
play.classicComingSoon
classic.modeHome
classic.comingSoon.playAS
force.as.list
force.as.unit.{name}
force.as.unit.{uuid}
rules.home
rules.as.{topicId}
rules.as.detail.{topicId}
settings.home
settings.deleteAll
```

Battle stage, header, dock:

```
as.battle.screen
as.ridge.tablePrep
as.mission.setup
as.battle.leave
as.battle.more
as.battle.back
as.battle.swapSides
as.battle.table
as.battle.activeSide
as.battle.phaseDock
as.battle.phase.initiative
as.battle.phase.movement
as.battle.phase.combat
as.battle.phase.end
as.battle.primary
as.battle.phaseDock.next
as.ridge.tableReady
as.mission.startBattle
as.battle.doneShooting
as.battle.phaseDock.doneSide
as.battle.skipRemaining
as.battle.unit.{uuid}
as.battle.move.{mode}
as.battle.shot.hit
as.battle.shot.miss
as.battle.log
```

Initiative dice ids still say `lance`. The visible words are Side A / Side B. `as.battle.activeSide` value is `lanceA` or `lanceB`.

```
as.battle.rollInit
as.initiative.lanceA.die1
as.initiative.lanceA.die2
as.initiative.lanceB.die1
as.initiative.lanceB.die2
as.initiative.confirm
as.initiative.tieHint
```

Solver, crit, focus, victory:

```
as.sator.sheet
as.sator.attacker
as.sator.target
as.sator.pick.attacker.{uuid}
as.sator.pick.target.{uuid}
as.sator.range
as.sator.tgtMove
as.sator.tnPreview
as.sator.tn
as.sator.outcome
as.sator.die1
as.sator.die2
as.sator.diceMode
as.sator.autoRoll
as.sator.resolve
as.sator.apply
as.crit.sheet
as.crit.die1
as.crit.die2
as.crit.diceMode
as.crit.autoRoll
as.crit.confirm
as.unitFocus.sheet
as.unitFocus.wounds.{uuid}
as.unitFocus.resolve.{uuid}
as.victory
as.victory.screen
as.victory.rematch
as.victory.done
as.victory.back
```

`as.battle.primary` and `as.battle.phaseDock.next` name the same dock primary. `as.battle.doneShooting` and `as.battle.phaseDock.doneSide` name Done shooting. `as.sator.resolve` and `as.sator.apply` name the apply button. `as.sator.tnPreview` and `as.sator.tn` name the gauge. `as.victory` and `as.victory.screen` name victory. `force.as.unit.{name}` is the card; `force.as.unit.{uuid}` is the sibling.

## Release gate

No 1.0 with open **critical** a11y failures on Ridge Line path.

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-10-28 |
| Commit | `b9acebb` (tag `0.2.0`) |
| Code paths | `DesignSystem/AccessibilityID.swift`, `Features/Play/PlayHomeView.swift`, `GettingStartedView.swift`, `SettingsHomeView.swift`, `ForceListView.swift`, `RulesHomeView.swift`, `ClassicComingSoonSheet.swift`, `Features/Battle/BattleFlowView.swift`, `BattleHeader.swift`, `BattleDock.swift`, `CombatSolverSheet.swift`, `CritSheet.swift`, `UnitFocusSheet.swift`, `VictoryView.swift`, `EventLogSheet.swift`, `DesignSystem/Components/PhaseTrack.swift`, `TNGauge.swift`, `DiceTray.swift` |
