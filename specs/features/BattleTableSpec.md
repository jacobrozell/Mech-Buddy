# Battle Table Spec — Alpha Strike

## Hotseat

One-device play. See [HotseatSpec](HotseatSpec.md). The words on screen are **Side A** and **Side B** (`SideId.displayName`). `SideId` raw values stay `lanceA` / `lanceB`.

## Design principle

Organize by **tableside jobs** (phase → unit → attack → apply). Presentation: `fullScreenCover` from Play (`RootTabView` → `BattleFlowView`).

```
Battle cover
  → header: turn + phase track + side (when that step has a side)
  → step body (coach prompt, then the work)
  → glass dock: coach secondary + primary
  → tap a unit card → Unit Focus
  → Solve a shot → SATOR sheet (apply dismisses the sheet)
  → if a critical is owed, the battle step shows it; Roll critical opens the crit sheet
```

## Screen: `as.battle`

Root identifier `as.battle.screen`. Table setup uses `as.ridge.tablePrep` on the same stage, plus a non-interactive sibling `as.mission.setup`.

### Header

`BattleHeader`, in the top safe-area inset. Hidden during table setup and victory.

| Piece | Behavior |
|-------|----------|
| `TurnCounter` | Turn, and “of N” when the ruleset has `maxTurns` |
| `PhaseTrack` | Read-only chips: **Roll**, **Move**, **Shoot**, **Clean up**. Current chip is signal fill + bold + `.isSelected`. Earlier chips show a checkmark. Identifiers `as.battle.phase.initiative`, `.movement`, `.combat`, `.end` |
| Side | `SideTag` and the words “is up”. Shown for place, movement, and combat. Identifier `as.battle.activeSide`. Label “Active side, {Side A\|B}”. Value remains `lanceA` or `lanceB` |

At accessibility sizes, and in compact height, the track collapses to “Step N of 4 · {name}” and keeps the phase identifiers on hidden elements.

A pass banner (“{Side}’s turn — pass the phone”) appears when the active side changes during movement or combat.

The coach line lives in the step body (`CoachPrompt`, identifier `as.battle.table`), under the header.

### Body

One step at a time, chosen by `BattleCoach`:

| Step | View |
|------|------|
| Table setup | `TableSetupStep` |
| Place miniatures | `PlaceMiniaturesStep` |
| Initiative | `InitiativeStep` (inline) |
| Movement | `MovementStep` |
| Combat | `CombatStep` |
| Critical owed | `CriticalPendingStep` replaces the phase step until the crit is rolled |
| Clean up | `CleanUpStep` |
| Victory | `VictoryView` replaces the stage |

Phone landscape (`verticalSizeClass == .compact`): a horizontal unit strip beside the step. iPad regular width: the step beside a roster column (`BattleStageLayout`).

The match log is a toolbar sheet (`as.battle.log`), titled **Match log**. It is not a collapsed section in the body.

Honor `ScenarioRuleset`: Ridge Line leaves overheat and physical attacks off. The sheet does not offer those controls.

### Table setup

First step, before the header. “Who’s who” shows Side A and Side B cards. **Swap** (`as.battle.swapSides`) while `BattleCoach.canSwapSides`.

“Set the table” is a numbered checklist. Checks live in `@State` on `TableSetupStep`. They last for this visit to the step, they are not written to the session, and **Start battle** does not require them. The eyebrow shows “N of M”.

### Phase dock: `as.battle.phaseDock`

Bottom inset inside the cover. `GlassEffectContainer` via `PhaseDock` / `BattleDock`. Contents are the coach’s **secondary** (when present) and **primary**.

The primary control keeps `as.battle.primary` (or the setup id below) and also exposes `as.battle.phaseDock.next`.

| Step | Secondary | Primary |
|------|-----------|---------|
| Table setup | — | **Start battle** — `as.ridge.tableReady`, also `as.mission.startBattle` |
| Place | — | **Miniatures placed** |
| Initiative, real dice | — | **{Side} wins — start moving**, or **Enter all four dice** while a winner is unknown (disabled). Also `as.initiative.confirm` |
| Initiative, app rolls | — | **Roll both sides**, then the same confirm |
| Movement, incomplete | **Skip remaining** (`as.battle.skipRemaining`) | — |
| Movement, complete | — | **Start shooting** |
| Combat | **Done shooting** — `as.battle.doneShooting`, also `as.battle.phaseDock.doneSide` | **Solve a shot** |
| Critical owed | — | **Roll critical**, or **Roll critical (1 of N)** |
| Clean up | — | **Next turn**, or **See result** when this end would finish the match |

Dock tint: signal on setup, initiative, and clean up; the active side’s color on place and combat; warning while a critical is owed.

### Initiative (inline)

`InitiativeStep` on the battle screen. Both sides enter 2d6 here.

| Field | Control | Identifier |
|-------|---------|------------|
| Side A die 1, die 2 | `DieFacePicker` 1…6 | `as.initiative.lanceA.die1`, `.die2` |
| Side B die 1, die 2 | `DieFacePicker` 1…6 | `as.initiative.lanceB.die1`, `.die2` |
| Let the app roll | `DiceModeLink` | `as.battle.rollInit` |
| Confirm | Dock primary | `as.battle.primary`, `as.initiative.confirm` |

The identifiers still say `lanceA` / `lanceB`. The labels say Side A / Side B.

Real dice is the primary path. **Let the app roll** switches the session dice mode; the dock then says **Roll both sides** and shows a `DiceReadout`. A tie shows an inline card (`as.initiative.tieHint`) and **Clear dice**. Confirm stays disabled until the totals differ.

Winner = higher total; acts **last**. Persist `initiativeRolls` + `initiativeWinner`. Movement starts with `activeSide` on the loser.

### Phase advance

See [MatchSessionSpec](MatchSessionSpec.md) AdvancePhase rules. The dock primary is the coach’s next legal action. Phase chips are a read-only track.

### Unit row badges

`StatusChip` on unit cards:

| State | Chip |
|-------|------|
| `destroyedPendingEnd` | Wrecked · still fires |
| sprint this turn | Sprinted · can’t fire |
| pending crit | Crit owed (or “N crits owed”) |

## Sheets

| Sheet ID | When |
|----------|------|
| `as.unitFocus` | Tap a unit card. Medium and large detents |
| `as.sator` | **Solve a shot**, or Shoot from Unit Focus (the focus sheet dismisses first). Large detent |
| `as.critRoll` | Dock **Roll critical**, or Roll critical from Unit Focus, after the solver has dismissed. Medium and large. See AppShellSpec |
| `as.battle.log` | Toolbar **What just happened** |

Movement modes are buttons on `MovementStep` (`as.battle.move.{standstill|ground|sprint|jump}`), not a movement sheet.

## Victory

`VictoryView` when the coach step is victory. It shows the winner (or **Draw**), a **Final tally** of structure left per side (pips for a unit still in play, **Wrecked** otherwise), then **Play again**, **Back to Play**, and **Undo the last step**.

When the log contains shot sentences, a **Match stats** card counts them by parsing `MatchEvent.message`. There is no event-kind field. A line with ` hit ` and `. Rolled ` is a hit; ` missed ` and `. Rolled ` is a miss; a message prefixed `Crit ` is a crit. “Best shot” is the largest “for N” damage in a hit sentence. The card stays hidden when that shot count is zero.

Identifiers: `as.victory` on the root, `as.victory.screen` on a sibling, `as.victory.rematch`, `as.victory.done`, `as.victory.back`.

## Domain rules (engine)

`PlayEngineId.alphaStrikePhased`:

1. Initiative — both roll; higher acts last; re-roll ties
2. Movement — loser first; alternating; proportional if uneven counts
3. Combat — loser resolves all, then winner; damage marked immediately; effects at End. The shot feed repeats the applied result, including damage on a hit (“Shooter hit Target for N”).
4. End — remove destroyed; heat; victory check

Movement modes on unit state: `standstill | ground | sprint | jump` — feed SATOR.

## Exit

**Leave** dismisses the cover and keeps the active session (see MatchSessionSpec / AppShell). **Discard this game** in the More menu confirms, then abandons. **Go back a step** asks first when restoring an earlier step would discard shots, damage, or recorded moves. Handing the phone to the previous side does not ask.

## Acceptance criteria (battle)

- Given four dice with a winner, When the dock confirms, Then phase is Movement and the header shows the loser as up  
- Given structure reduced to 0, Then the unit shows “Wrecked · still fires” and can still attack until End  
- Given End resolves with no living enemies, Then Victory presents the structure tally  

## Accessibility

- `as.battle.screen`, `as.ridge.tablePrep`, `as.mission.setup`
- `as.battle.phaseDock`, `as.battle.phase.{initiative,movement,combat,end}`, `as.battle.phaseDock.next`
- `as.battle.unit.{uuid}`, `as.battle.activeSide`
- `as.battle.table`, `as.battle.primary`, `as.battle.doneShooting`, `as.battle.phaseDock.doneSide`
- Announce step and side changes with `AccessibilityNotification.Announcement` (`BattleChrome.announcement`)

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-11-01 |
| Commit | — |
| Code paths | `Features/Battle/BattleFlowView.swift`, `BattleHeader.swift`, `BattleDock.swift`, `BattleStage.swift`, `Domain/Commands/BattleCoach.swift`, `Features/Battle/Steps/InitiativeStep.swift`, `CombatStep.swift`, `TableSetupStep.swift`, `Features/Battle/VictoryView.swift`, `EventLogSheet.swift`, `DesignSystem/Components/PhaseTrack.swift`, `PhaseDock.swift` |
