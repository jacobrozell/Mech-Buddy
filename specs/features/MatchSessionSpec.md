# Match Session Spec — TableMech

Types: [DomainModelSpec](../DomainModelSpec.md). Hotseat: [HotseatSpec](HotseatSpec.md).

## User story

Leave mid-battle, kill the app, resume the same turn/phase/pips/`activeSide` without re-setup.

## Complete session model

Use `MatchSession` from DomainModelSpec (includes `activeSide`, `initiativeRolls`, `forcesLoaded`, `tableReady`).

### Unit visual / logic states

| `combatStatus` | UI | Can fire | Removed from table |
|----------------|-----|----------|-------------------|
| `active` | Normal | Yes | No |
| `destroyedPendingEnd` | Badge “Fires until End” | Yes | No until End |
| `removed` | Hidden from force list (log only) | No | Yes |

When `ApplyDamage` zeroes structure → set `destroyedPendingEnd` (do **not** set `removed` until End phase command).

### Unreadable saves

`statusRaw` on the SwiftData row is a string, not only `MatchStatus`. When the newest active row fails to decode, or its payload schema is newer than this build, `loadActive` sets that row to `unreadable` and tries the next active row. It does not delete the row (a later build may read it) and it does not throw, so Play can start a new game. `deleteAll()` still removes unreadable rows. Play shows one notice: "A saved game couldn't be opened, so it was set aside. You can start a new game."

## State machine — phases

```
StartMission (forces loaded + table ready)
  → turn=1, phase=initiative, activeSide=lanceA (until initiative set)
Initiative resolved
  → phase=movement, activeSide=initiativeLoser
Movement complete (all living units hasMovedThisTurn or passed)
  → phase=combat, activeSide=initiativeLoser, clear hasAttackedThisTurn
Combat: loser Done attacking
  → activeSide=initiativeWinner
Combat: winner Done attacking
  → phase=end
End resolved (removals + victory check)
  → if victory → status=completed
  → else turn+=1, phase=initiative, reset hasMoved/hasAttacked/movementMode=unset for living units
```

### AdvancePhase rules

| From | `AdvancePhase` / Next | Allowed when |
|------|----------------------|--------------|
| initiative | → movement | `initiativeWinner != nil` |
| movement | → combat | All `canFire` units with `combatStatus==active` have `hasMovedThisTurn == true` **or** user confirms **Skip remaining moves** |
| combat | (use Done side, not AdvancePhase) | — |
| end | → initiative (next turn) | End checklist applied; no winner yet |

**Jump via phase chips:** Allowed for recovery; does **not** auto-fix incomplete work. Jumping **back** clears nothing; jumping **forward** shows confirm if current phase incomplete. Prefer Next for happy path.

### Exit (resolve conflict)

| Action | Behavior |
|--------|----------|
| Dismiss battle cover (swipe/Done to Play) | **Autosave** `active` session; no discard prompt |
| **Abandon match** | Confirm → `status=abandoned`; leave cover |
| **End match** early | Confirm → evaluate victory if possible else abandoned |

No “dirty discard” prompt — autosave is the product rule (owner-aligned).

## Commands (signatures)

```swift
enum MatchCommand: Sendable {
    case startMission(scenarioId: ScenarioId, units: [MatchUnitState])
    case abandonMatch
    case setInitiative(rolls: InitiativeRolls)      // ties → Domain error .initiativeTied
    case setMovementMode(unitId: UUID, mode: MovementMode)
    case markMoved(unitId: UUID)
    case skipRemainingMoves
    case advancePhase
    case jumpToPhase(PhaseId)                       // with UI confirm if incomplete
    case finishCombatSide                           // loser→winner or winner→end
    case resolveSATOR(ResolveSATORCommand)
    case applyCritical(unitId: UUID, roll: DiceRoll2D6)
    case resolveEndPhase
    case completeMatch(outcome: MatchOutcome)
}

enum MatchOutcome: Sendable, Equatable {
    case winner(SideId)
    case draw
}

enum MatchDomainError: Error, Sendable, Equatable {
    case initiativeTied
    case illegalPhaseTransition(String)
    case unitNotFound
    case cannotAttack(reason: String)               // e.g. sprint
    case noActiveSession
}
```

Reducer: `(MatchSession, MatchCommand) throws -> MatchSession` — pure Domain; persistence outside.

## StartMission / Load forces

1. Build four `MatchUnitState` from bundled Ridge Line fixtures (or edited grid)  
2. Upsert matching names into Force library **templates** (stats), separate from match snapshot  
3. `forcesLoaded=true`; require `tableReady=true` before Start battle  
4. If another `active` AS session exists → UI confirms abandon first  

## Rematch

`StartMission` with same scenario → **new** `MatchSession.id`; prior completed session retained only if history ungated (1.0: drop or keep completed without UI).

## Free Battle

Command exists for 1.1; ReleaseSurface hides entry in 1.0.

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-11-01 |
| Commit | — |
| Code paths | `Persistence/SwiftDataMatchSessionRepository.swift` (`loadActive` sets `unreadable`); `Features/Play/PlayMatchCoordinator.swift` |
