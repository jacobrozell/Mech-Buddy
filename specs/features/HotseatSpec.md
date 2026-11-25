# Hotseat Spec — one-phone play

**Owner (2026-08-21):** One device shared (**hotseat**). No networked multiplayer in v1.

The words on screen are **Side A** and **Side B**. `SideId` cases remain `lanceA` and `lanceB`. Some accessibility identifiers still contain `lanceA` / `lanceB`; the labels say Side A / Side B.

## Model

| Concept | Behavior |
|---------|----------|
| `activeSide` | Side the UI emphasizes for the current micro-step |
| Sides | Side A / Side B |
| Chrome | On place, movement, and combat the header shows `SideTag` and “is up” (`as.battle.activeSide`). A banner says “{Side}’s turn — pass the phone” when that side changes |

### Phase behavior

| Phase | Hotseat |
|-------|---------|
| Initiative | Both sides enter 2D6 on the battle step (Side A fields + Side B fields). Identifiers: `as.initiative.lanceA.die1` … `lanceB.die2`. Winner acts **last**. Tie → inline hint and clear (`as.initiative.tieHint`). Confirm is the dock primary (`as.initiative.confirm`). **Skip the roll** (`as.initiative.agree`): players pick which side moves first (`agreeInitiative(firstToMove:)`); no dice are recorded and the log says "Players chose: Side B moves first". |
| Movement | `activeSide = initiativeLoser` first. After that side finishes its **batch** for the current alternating step, flip. See algorithm below. |
| Combat | **Simultaneous.** Either side may shoot, in any order. One **Done shooting** (`finishCombat`) ends the phase for both. No pass-the-phone banner and no active-side badge in combat. |
| End | No side ownership; shared checklist. |

### Opening a unit

Tap a unit card for Unit Focus. The dock has no **My Unit** button. During combat the dock primary is **Solve a shot** and the secondary is **Done shooting**.

### Prompts

Use side names (“Side A moves next”), not “you”. Announce `activeSide` changes to VoiceOver.

---

## Movement alternating algorithm

Let `needMove(side)` = active units on side with `hasMovedThisTurn == false`.

1. Start movement: `activeSide = initiativeLoser`.  
2. While any side has units needing move:  
   - Let `a = needMove(activeSide).count`, `b = needMove(otherSide).count`.  
   - If `a == 0`: flip `activeSide` and continue.  
   - Units this impulse = `max(1, floor(a / max(b,1)))` when `a > b`, else `1` (standard AS proportional: side with more remaining moves moves multiple).  
   - Simpler **v1 acceptable approximation** (document in code): alternate **one unit at a time** starting with loser; if one side has no remaining, the other moves all remaining. Prefer full proportional when implementing Domain tests; UI can still be one-unit-at-a-time selection.  
3. User selects a unit on `activeSide`, sets optional `movementMode`, marks moved (`markMoved`).  
4. When both sides `needMove == 0` → enable Advance to Combat.

**Pass:** `skipRemainingMoves` marks all remaining active units `hasMovedThisTurn=true` with `movementMode` left `.unset` (SATOR defaults ground).

**Destroyed mid-movement:** `destroyedPendingEnd` units still need a move marker if they started the phase active; if already destroyed before Movement, they do not move.

---

## Combat hotseat

Owner decision 2026-11-24, from playtest note 50: players at the table roll at the same time.

The rulebook lists the initiative loser's shots first, but damage and critical effects all apply at the end of the phase (`combatPhaseCrits`, heat in the End Phase), so entry order cannot change the result.

1. Shoot step lists both sides (`as.battle.shooters.lanceA` / `lanceB`), initiative loser first, each with "N to fire". Every unit with `canAttackThisTurn` has **Shoot**.
2. Solve a shot: "Who's shooting?" lists every unit that can still fire, from both sides, plus a one-line "Done:" note for the rest. Targets are the chosen shooter's enemies.
3. **Done shooting** → `finishCombat` → End. It asks first if any unit on either side can still fire.
4. Units with `destroyedPendingEnd` remain eligible until End.

---

## Accessibility

- `as.battle.activeSide` — label “Active side, {Side A\|B}”; value `lanceA` or `lanceB`
- Announce on change (`BattleChrome.announcement`, and the pass-the-phone line when only the side changes)

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-10-28 |
| Commit | `b9acebb` (tag `0.2.0`) |
| Code paths | `Domain/Models/Identifiers.swift` (`SideId.displayName`), `Domain/Commands/MatchReducer.swift`, `Domain/Commands/BattleCoach.swift`, `Features/Battle/BattleHeader.swift`, `BattleFlowView.swift`, `Steps/InitiativeStep.swift` |
