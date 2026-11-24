# Triage — Ridge Line playtest 2026-11-19

Source: `NOTES.md` (notes 1–82, L1–L10).

## Done

TestFlight archive of **0.2.0 (1)** is Xcode Cloud Release build `088bef16-7b2c-4d46-a0e2-c7b0a4dd983f` (run 2), from `41b8d35`. That commit is the rules pass. The dock layout below is the commit after it and is not in that archive.

| Item | Where it landed |
|---|---|
| P0-1 Crits wait until the end of the phase | `41b8d35` — `combatPhaseCrits` / `firingCrits` |
| P0-2 Killing blow owes no critical | `41b8d35` — `AlphaStrikeDamage.apply` |
| P0-3 Wrecked units drop out of later shot feeds | `41b8d35` — `resetTurnFlags` clears every `turnShot` |
| P0-4 Second tap on Apply does not raise "No critical owed" | `41b8d35` — `isApplying` on the crit and solver sheets |
| P0-5 Wrecked target no longer says armor absorbs the shot | `41b8d35` — solver banner, preview card skipped, target dimmed |
| P1-3 Pick which ’Mech moves | `41b8d35` — "Move this one" |
| P1-4 Crit card says whose dice and that it is not a shot | `41b8d35` |
| P1-5 Solver is one column; Change keeps the shooter | `41b8d35` |
| P1-7 Initiative button names who moves; a tie says to clear the dice | `41b8d35` |
| P1-8 Each phase opens at the top | `41b8d35` |
| Phone landscape (L1, L8, L9) | `41b8d35` — `BattleStageLayout.resolve` returns `.stacked` on iPhone, including compact height. Shoot and Clean up keep their lists. |
| P1-1 Dock covers the next control | This commit — the battle dock, the solver need line and Apply bar, and the crit Apply bar are siblings of the scroll view, not safe-area insets |
| Woods chip opens More… (36) | This commit — chips are 44 pt and More… is a plain button with its own row |

Fixed later on `feature/guided-mission-ladder` (2026-11-24):

| Item | Fix |
|---|---|
| 77 "Motive" vs "MP" | The unit sheet chip and help text say "MP hit", matching the card and the crit sheet |
| 65 Wrecks say "still fires" in Clean up | `UnitCard(shootingOver:)`. Clean up passes it, so wrecks read "Wrecked" |
| 45 Crits hidden on unit rows | Unit rows show one warning line: "Heat 2 · Weapon ×1 · MP hit" (`UnitConditions`) |
| 49 Do wrecks explode? | Clean up says "Wrecks don’t explode or hurt anything nearby." |
| 14 Skill not shown at setup | Briefing: "Every ’Mech uses Skill 4. Write it on the card’s blank Skill line." |
| 81 "Best shot" is meaningless | Victory match stats list killing blows ("Shadow Hawk wrecked the Locust · turn 4"); best shot is only the fallback |
| 82 No full log after the game | Victory has a **Full battle log** link that opens the match log |
| Pass-the-phone pill shows the heading through it | The pill is opaque, with a shadow |

Already fixed before that: clean-up copy when nothing is wrecked (33), the picked-up checkbox (63), range-band labels (41), per-sheet dice mode (59), "Moves locked in" (57), and Move this one (15).

Then, same day:

| Item | Fix |
|---|---|
| P1-6 Simultaneous fire (50) | Either side shoots in any order; one **Done shooting** (`finishCombat`) ends the phase. The order can't change results, since effects land at the end of the phase. See HotseatSpec |
| 2, 5 "We agreed who goes first" | Initiative has **Skip the roll — we’ll choose who moves first** (`agreeInitiative`) |
| 24 Mini colour labels | Briefing **Mark mini** menu per ’Mech; a colour dot on unit cards, the mover card and the shot picker (`MatchUnitState.mini`) |
| 45 Crits in the shot feed | Feed lists "Critical: Weapon hit on Commando" for this turn |
| 28 Miss chip truncates | Hit and miss chips use the short name ("Missed Wolverine") |
| Dock at accessibility text sizes | Buttons stack; "Done shooting" no longer breaks mid-word |

Rules found by the 2026-11-24 rulebook audit are in `docs/game-modes/alpha-strike/rules-audit-2026-11-24.md`.

## Executive summary
1. Rules: crit effects apply as soon as the crit is rolled, so a unit's same-phase return fire is penalized (58). A crit is also demanded on a unit that its own damage just destroyed (54). Both are small fixes in `Domain/Engines/AlphaStrike`.
2. Data: the shot feed shows stale shots from wrecked units for the rest of the game, because `resetTurnFlags` skips `.removed` units (68/73). A double tap on Apply raises a raw "No critical owed" alert (76).
3. The biggest table-side blocker is the floating glass dock. It sits on top of the next action on almost every screen (10 notes). Close behind are controls moving under the finger (7 notes) and a forced unit order within each side, which the reducer does not even require (15).
4. Landscape on phone is broken. The `.phoneLandscape` stage puts the shooter and clean-up lists in a 248pt horizontally scrolling rail and hides them in the main column, so the shoot and clean-up phases look empty (L1/L2/L5/L8/L9).
5. Strong foundations to keep: crit flow, shot feed, end-of-move summary with Change, "Wrecked · still fires", tie handling, Undo last change, and the victory screen. Jacob's direction is "less cluttered: one decision per screen, full-width rows, fewer docks."

## Jacob's direct feedback (owner quotes)
- **19:** the solve-a-shot picker "could be improved a lot". He wants a VStack of full-width cards instead of 2-up tiles. → P1-5
- **40:** "I don't like a lot of the UI with how cluttered it is." → applies to all P1 rows
- **57:** "has moved is misleading when I didn't actually move." → P2
- **74:** "Sorry confused. I get a second shot?" (the crit prompt) → P1-4

---

## P0 — rules / correctness / data / raw errors

| # | Notes | Issue | Where (verified) | Fix | Size |
|---|---|---|---|---|---|
| P0-1 | 58, 56 (also covers 44) | A crit taken mid-phase changes the same unit's return fire. In this game the Locust shot at 8+ instead of 6+. Weapon-hit −1 damage, MP-hit halved TMM, and engine heat all have the same exposure. | `AlphaStrikeCriticals.apply` writes `crits.*` immediately. `CombatSolver.satorInput` reads `attacker.crits.fireControlHits` and `defender.effectiveTMM`. `CombatSolver.damageInput` reads `attacker.effectiveDamage` (weaponHits). `MatchReducer.applySATOR` resolves through these same helpers. | Snapshot crit effects at the start of combat, for example a `critsAtPhaseStart` field on `MatchUnitState`, set in `MatchReducer.advance` for `.movement→.combat`. Have `satorInput`/`damageInput` read the snapshot during `.combat`, and clear it in `.resolveEndPhase`. Add a reducer test for fire-control return fire. | M |
| P0-2 | 54 (62 is the contrast case) | A crit is demanded on a unit that this hit just destroyed. | `AlphaStrikeDamage.apply`: `let needsCritical = structureMarked \|\| naturalTwelveHit` never checks `updated.isStructurallyDestroyed`. Overkill (62) skips the crit only because `structureDamage` is already capped, so `structureMarked` is false. | `needsCritical = (structureMarked \|\| naturalTwelveHit) && !updated.isStructurallyDestroyed`. Then the preview's `needsCritical` in `CombatSolver.preview` follows automatically. | S |
| P0-3 | 73, 68 | The shot feed shows T4 shots in T6, skips T5, and has no turn labels. Root cause: units wrecked in T4 become `.removed` in `removeDestroyedAtEnd`, and `resetTurnFlags` (which only touches `.active`/`.destroyedPendingEnd`) never clears their `turnShot`. `ShotFeed.rows` then sorts them in with the fallback order `10_000 + offset`. | `AlphaStrikePhaseEngine.resetTurnFlags`, `AlphaStrikePhaseEngine.removeDestroyedAtEnd`, `ShotFeed.rows` (Features/Battle/Support/ShotFeed.swift) | Clear `turnShot` for every unit in `resetTurnFlags`, or nil it inside `removeDestroyedAtEnd`. Also filter `.removed` in `ShotFeed.rows`. For 68, add a turn divider or store the turn on `TurnShot`. | S |
| P0-4 | 76 | A double tap on "Apply MP hit" shows the raw alert "Couldn't save the critical — No critical owed". | `CritSheet.apply` has no in-flight guard. `MatchStore.applyPendingCrit` passes `failureTitle: "Couldn't save the critical"`. The reducer throws `illegalPhaseTransition("No critical owed")` from `case .applyCritical`. The alert is `BattleFlowView`'s `.alert(store.lastErrorTitle…)`. | Add `@State isApplying` to `CritSheet` and the solver's `applyShot`, and disable the button after the first tap. In `applyPendingCrit`, treat "no crit owed" as a silent no-op. Audit the other `lastError` strings for developer-speak. | S |
| P0-5 | 61 | The "If this hits" card for a wrecked (0/0) target says "Armor absorbs it. A critical only happens on two 6s." That is wrong. | `CombatSolverSheet.swift` ~L900, inside `DamagePreviewCard` (`"Armor absorbs it…"`) | Branch on `defender.combatStatus == .destroyedPendingEnd`: show "Already wrecked — this shot changes nothing" and dim the target tile in `targetCard`. | S |

## P1 — blocks or misleads at the table

| # | Notes | Issue | Where (verified) | Fix | Size |
|---|---|---|---|---|---|
| P1-1 | 1, 6, 8, 10, 37, 39, 46, 66, 31, 43, L2, L5, L7 | **The dock covers content.** The next die row, Shoot button, Clear dice, or move list sits under the glass dock. | `BattleFlowView.toolColumn` attaches `BattleDock` → `PhaseDock` (a `GlassEffectContainer`) with `.safeAreaInset(edge: .bottom)` plus `.scrollEdgeEffectStyle(.soft, for: .bottom)`. `CombatSolverSheet.shotScreen` (`applyBar`) and `CritSheet` (`applyBar`) use the same pattern. See (d). | Stop drawing scroll content under the dock: give the dock an opaque bar background, or place it in a `VStack` below the `ScrollView`. Put each step's key control above the fold: tie "Clear dice" in the dock (66), dice under the NEED card (31). Open `CritSheet` at `.large` (43). | M |
| P1-2 | 18, 26, 30, 36, 52, 53, 70, 78 (also 35) | **Controls move under the finger / gesture conflicts.** The pass banner collapses and shifts the list by about 50pt. The bottom half of the Woods chip opens More…. The first swipe after a tap is eaten. Taps are dropped while a sheet dismisses or the device rotates. | The pass banner is `SidePassBanner` inside `BattleFlowView.headerInset` (top safe-area inset), removed after 1.2s in `presentPassBanner`. Chips: `CombatSolverSheet.conditions`, where `chipToggle` (`.toggleStyle(.button)`, no min height) inside `FlowLayout` (DesignSystem/Components/PipTrack.swift) sits directly above the borderless `More…` button. Swipe/drag conflicts: sheet detents (`CritSheet .presentationDetents([.medium, .large])`) — unverified. | Show the pass banner as an overlay (`.overlay(alignment: .top)`) that does not resize the inset. Give chips `.frame(minHeight: 44)`, add spacing before More…, and check `FlowLayout`'s reported height. Disable dock buttons while a sheet is dismissing. Test 52/78 on device. | M |
| P1-3 | 15 (also 11, 75) | **Forced unit order within a side** — "Do I have to move my Wolverine?" There is also no undo on a mis-tapped move tile. | UI only: `MovementStep.current` = `AlphaStrikePhaseEngine.unitsNeedingMove(...).first`, and `BattleRoster.isRaised` uses the same `.first`. `MatchReducer` `.setMovementMode`/`.markMoved` only check `side == activeSide`, not order. See (c). | Add `@State selectedUnitId` to `MovementStep`. Make the active side's unmoved order rows tappable ("Move this one instead"), and drive `moverCard` and `isRaised` from the selection. Add a 5s "Undo" toast that calls `MatchStore.undo()` after `setMove`, shots, and crits. | S–M |
| P1-4 | 74, 44 | **Confusing crit prompt.** Your own unit's crit appears mid-way through the enemy's shooting and says "Roll two dice before anyone else shoots", which reads as a second shot. | `CriticalPendingStep.message`. `BattleCoach.init` puts `pendingCritical` ahead of every step. `MatchReducer.applySATOR` blocks further shots with "Roll the critical before the next shot." | Name the roller and say it is not an attack: "**Side B** rolls for their Wolverine's crit — this is not a shot." If P0-1 lands, crits can be deferred to the end of the phase or the clean-up step, which removes the mid-phase interruption entirely. | S (copy) / M (defer) |
| P1-5 | 19 (Jacob), 25, 20, 69, 21 | **Solver picker and defaults.** 2-up tiles hyphenate names. "Change" clears the shooter too. Range defaults to Short, the most generous band. The sticky NEED card hides the controls. | `CombatSolverSheet.pairColumns` (2 `GridItem`s) / `pairPicker` / `shooterCard` → `UnitCard`. Toolbar `Button("Change") { attackerId = nil; defenderId = nil }`. `CombatTableInsight.init(rangeInches: Int = 6…)` (CombatSolver.swift). Top `safeAreaInset` holding `gauge(for:)` in `shotScreen`. | Use a single-column full-width list and `lineLimit(1)` names, with the variant on a second line. Make Change clear only `defenderId`. Have no default range, or remember the last bracket per pair. Collapse the sticky gauge to "7+ · 58%" once scrolled. | M |
| P1-6 | 50 | Fire is gated so one side shoots fully before the other. Players at the table roll at the same time. | `MatchReducer.applySATOR` guard `attacker.side == next.activeSide`. `case .finishCombatSide`. `CombatSolverSheet.friendlies`/`shooters` filter on `live.activeSide`. | Optional for 1.0. Allow either side's shooters in the solver, and end combat when all units have fired or been skipped. This depends on P0-1 snapshots. | L |
| P1-7 | 7, 48 | The initiative dock says "Side B wins — start moving" while Side A moves. On a tie it still says "Enter all four dice". | `BattleFlowView.primaryButton` `.useInitiativeRolls` / `.rollInitiative` titles. A tie makes `InitiativeDice.winner` nil, which falls through to the "Enter all four dice" label. | "Side A moves first — start". On a tie, show "Tie — clear and roll again" (enabled, calling `clearDice`). | S |
| P1-8 | 34, L3 | The phase screen opens scrolled down, because the offset carries over from the previous phase. Rotating loses your place. | `BattleFlowView.toolColumn` uses a single `ScrollView` for every step, with no `.id(coach.step)` or `scrollPosition` reset. | Add `.scrollPosition` and reset it to the top in `.onChange(of: cue?.step)`. Preserve the position across rotation. | S |
| P1-9 | 59, 60 | "Let the app roll" is sticky across contexts: one crit using the app roll leaves later shots app-rolled. Crits offer "Roll again". | The mode is session-wide: `DiceTray` "Let the app roll" toggles `store.setDiceMode` (`MatchStore.setDiceMode`), and the solver and crit sheet read `session.diceMode`. "Roll again" sits in `DiceTray` (unverified exact label). | Make app-roll per-roll (local `@State`), defaulting to manual. Hide "Roll again" after a crit result, or log rerolls. | S |

## P2 — copy and polish
- **57 (Jacob), 17:** `MovementStep` CoachPrompt shows "Everyone has moved." Use "Moves locked in", and drop the "Side B is up" badge once movement is done (`BattleChrome.showsActiveSide`). The done row should read "Stood still ✓".
- **3:** portrait phase chips clip ("Shoo/t"). `PhaseTrack` already switches to "Step n of 4 · Name" when `verticalSizeClass == .compact` (L4); use that in portrait too.
- **33, 65, 63, 64:** in `CleanUpStep`, say "Nothing wrecked — tap Next turn" when `wrecks.isEmpty`. Make "Still on the table/Picked up" a checkbox row; it is local `@State pickedUp` and gates nothing. Drop "still fires" from `StatusChip` `.wrecked` in Clean up.
- **41:** range labels in `rangeControl` should be "Short 0–6″ · Medium over 6–24″ · Long over 24–42″".
- **77:** `UnitFocusSheet` chip says "Motive" while `AlphaStrikeCriticals.title` says "MP hit". Use "MP".
- **45:** add a crit chip to unit rows and crit lines to the shot feed.
- **28:** the miss chip truncates.
- **4:** the initiative title is tucked under the header.
- **2, 5:** add a "We agreed who goes first" shortcut and align the step-5 copy.
- **9:** placement diagram orientation.
- **14:** show "Skill 4" on the move and briefing screens.
- **24:** a mini color/label per unit.
- **29:** already addressed by 55.
- **49:** a "destroyed 'Mechs don't explode" line or Rules topic.
- **71, 79:** show the tiebreak and score card from T5 (`CleanUpStep` gates the score card on `coach.isLastTurn`).
- **81:** `VictoryView` "Best shot" → killing blow / clutch shot.
- **82:** full battle log on the victory screen.

## Landscape (phone, compact height)
| Notes | Issue | Cause (verified) | Fix | Size |
|---|---|---|---|---|
| L1, L6 | The rail is clipped, a second card peeks in, names hyphenate, and the rail doesn't follow the active unit. | `BattleStageLayout.resolve` returns `.phoneLandscape` for `idiom == .phone && vertical == .compact`. `BattleFlowView.stage` puts `BattleRoster` (`.frame(width: unitStripWidth = 248)`) beside `toolColumn(showsUnits: false)`. `BattleRoster.strip` is a **horizontal** `ScrollView` of 200pt-wide `BattleUnitRow`s, so 1.2 cards fit and Side A always comes first. | Drop the rail on phone landscape: return `.stacked` (as `VictoryView` does — L10 shows it works). Or make the rail a vertical list of the active side only. | S |
| L8, L9 | The shoot and clean-up lists are empty. | With `showsUnits: false`, `CombatStep` skips both `unitGroup`s, and `CleanUpStep` skips "Standing" and uses name-only wreck rows. The shooters and Shoot buttons exist only in the rail, scrolled off to the right (confirmed in `L05-shoot-list.png`: the rail shows Shadow Hawk (Side A) while Side B shoots). | Same fix: `.stacked` on phone. Or always pass `showsUnits: true` when the rail can't show the active side. | S |
| L2, L5, L7 | About 150pt of usable height. The move tiles and "Start shooting" sit under the dock. | `BattleHeader` compact branch + nav bar + `PhaseDock` (`TMSpace.xs` vertical padding in compact). Same dock overlap as P1-1. | Hide `TurnCounter` and the side badge in compact height, or move them into the nav title. Make the dock non-overlapping (P1-1). Consider a 4-column move grid in landscape. | M |
| L3 | Rotating resets the scroll position. | Probably the `stage` switch rebuilding `toolColumn` in a different container (unverified). | Keep the `ScrollView` identity stable across layouts, or restore `scrollPosition`. | S |
| L4 ✅, L10 ✅ | "Step n of 4" text; the victory screen is single column. | `PhaseTrack` compact branch; `VictoryView` rendered outside `stage`. | Keep both; see P2-3. | — |

## Positives worth preserving
- Crit flow: blocking card → dice sheet → plain-words result → "Weapon ×1" and "DMG 1·1·0 ↓" (42). The rules are right for MP not changing to-hit and for stood-still modifiers (51).
- The shot feed (38) and the result chips on shooter rows (28), once P0-3 is fixed.
- The end-of-move summary with **Change** on every row, which only advances on "Start shooting" (16).
- "Wrecked · still fires" (55). Wrecks drop out of the move order (67) and out of clean-up (72). Overkill never creates a second crit (62).
- Tie banner with Clear dice (47). The "If this hits" preview (22). The Woods toggle with live % (27).
- ⋯ → Undo last change restores "Crit owed" cleanly (75). This is the basis for the undo toast in P1-3.
- The clean-up recap (32), the T6 score card (79), the last-turn badge (71), the victory screen and stats (80). Bundled card data matches the printed cards (12, 13, 23).

---

## Investigations

**(a) Note 58 — are crit effects applied to same-phase return fire? Yes.**
- `MatchReducer` `case .applyCritical` calls `AlphaStrikeCriticals.apply`, which mutates `unit.crits` immediately (`fireControlHits += 1`, `weaponHits += 1`, `mpHit = true`, `engineHits += 1`).
- The next solve, both the preview (`CombatSolver.solve`) and the commit (`MatchReducer.applySATOR`), calls `CombatSolver.satorInput`. That passes `attacker.crits.fireControlHits` into `OtherModifiers`, and `SATORResolver` adds `oDelta += input.other.fireControlHits * 2`. This is the "O +2" in `190-…png`.
- `CombatSolver.damageInput` uses `attacker.effectiveDamage` (−weaponHits), and `defender.effectiveTMM` halves TMM for an MP-hit target mid-phase.
- `applySATOR` also adds engine heat: `attacker.heat + attacker.crits.engineHits`.
- There is no phase-start snapshot anywhere. Fix: see P0-1.

**(b) Note 54 — why is a crit owed when structure hits 0?**
- `AlphaStrikeDamage.apply` sets `needsCritical = structureMarked || naturalTwelveHit` and increments `criticalsOwed` regardless of `isStructurallyDestroyed`. It does mark `.destroyedPendingEnd` on the same path.
- `MatchUnitState.pendingCritical` then drives `BattleCoach.pendingCritical` → the `CriticalPendingStep` card plus the `rollCritical` dock.
- Later overkill hits don't owe a crit only because the structure is already capped (`structureMarked == false`).
- One-line fix in P0-2.

**(c) Note 15 — how hard is it to let the active side pick which unit moves? Small (S–M), UI only.**
- The domain already allows it: `.setMovementMode` and `.markMoved` validate only `side == activeSide` and `.active` status. `nextMovementActiveSide` alternates sides, not units.
- The forced order lives in two views: `MovementStep.current` (`unitsNeedingMove(...).first`) and `BattleRoster.isRaised`.
- Changes needed:
  - Add a selected-unit state (default `.first`).
  - Make the active side's unmoved `orderRow`s tappable (or show both units as choice cards).
  - Point `moverCard`, `isRaised` and `moveOrder` at the selection.
- `MatchStore.setMove` needs no change. Add a UI test for moving the second unit first.

**(d) Dock / bottom inset.**
- The dock is `BattleDock` (Features/Battle/BattleDock.swift), which wraps `PhaseDock` (DesignSystem/Components/PhaseDock.swift; Liquid Glass `GlassEffectContainer` + `PrimaryActionButton`/`SecondaryActionButton`).
- It is attached in `BattleFlowView.toolColumn` via `.safeAreaInset(edge: .bottom, spacing: 0) { dockInset(...) }`, together with `.scrollEdgeEffectStyle(.soft, for: .bottom)`.
- So content **does** get a bottom inset: the end of the list can scroll clear, which is why "scroll reveals all" (1).
- But a safe-area inset on a `ScrollView` still lets content draw **under** the translucent glass bar. At rest, whatever falls in the bottom ~100pt (die 2, Shoot, Clear dice, move order) is visible but covered, and taps hit the dock's glass.
- The same pattern repeats in `CombatSolverSheet.shotScreen` (`applyBar`) and `CritSheet` (`applyBar`, worse at the `.medium` detent).
- Fix: an opaque or non-overlapping dock (a `VStack` sibling of the scroll view), plus layouts that keep each step's key control above the fold.

**(e) L1/L2/L8/L9 — compact-height layout.**
- `BattleStageLayout.resolve(idiom:horizontal:vertical:)` returns `.phoneLandscape` whenever `idiom == .phone && vertical == .compact`.
- `BattleFlowView.stage` then renders `BattleRoster(layout: .phoneLandscape)` in a fixed 248pt column. Its `strip` is a horizontal `ScrollView` of 200pt cards: the clipped second card in L1, and the narrow `UnitCard` that hyphenates names.
- Next to the rail, `toolColumn(showsUnits: false)` tells `CombatStep` to omit its Shooters/Targets groups and `CleanUpStep` to omit "Standing", on the assumption that the rail shows them. Shoot buttons exist only in `BattleUnitRow` in the rail, which lists Side A first, so Side B's shooters are off-screen to the right. That is why the main column looks empty (L8/L9).
- L2: the nav bar, the compact `BattleHeader` and the `PhaseDock` together leave about 150pt.
- `VictoryView` bypasses `stage` entirely, which is why L10 works.
- Fix: map phone compact-height to `.stacked`, or a vertical active-side rail, and slim the header.

## Suggested order
P0-2, P0-3, P0-4 (all S) → P0-1 (M) → P1-1 dock (M) → the landscape `.stacked` fallback (S, fixes L1/L8/L9) → P1-3 pick-unit + undo toast → P1-2 → P1-5 (Jacob's picker) → P1-4 / P1-7 copy → P2 sweep.
