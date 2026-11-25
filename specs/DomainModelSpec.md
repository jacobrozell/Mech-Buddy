# Domain Model Spec — Mech Buddy

**Status:** Authoritative for Domain types used by engines, commands, and persistence DTOs.  
**Language:** Swift 6, all types `Sendable` unless noted. Domain imports Foundation only.

Companion: [MatchSessionSpec](features/MatchSessionSpec.md) · [SATORAttackSpec](features/SATORAttackSpec.md) · [ContentPackSpec](ContentPackSpec.md)

---

## Identifiers

```swift
public struct GameModeId: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public static let alphaStrike = GameModeId(rawValue: "alpha-strike")
    public static let classicTW = GameModeId(rawValue: "classic-tw")
}

public struct ScenarioId: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public static let ridgeLine = ScenarioId(rawValue: "ridge-line")
    public static let fullLances = ScenarioId(rawValue: "full-lances")
}

public enum SideId: String, Codable, Sendable, CaseIterable {
    case lanceA = "lanceA"
    case lanceB = "lanceB"
}

public enum PhaseId: String, Codable, Sendable, CaseIterable {
    case initiative
    case movement
    case combat
    case end
}

public enum MatchStatus: String, Codable, Sendable {
    case active
    case completed
    case abandoned
}

public enum MovementMode: String, Codable, Sendable, CaseIterable {
    case unset
    case standstill
    case ground
    case sprint
    case jump
}

public enum UnitCombatStatus: String, Codable, Sendable {
    case active                    // on table, can act
    case destroyedPendingEnd       // structure gone; still fires until End
    case removed                   // removed at End, or left the table (`leftTable`)
}
```

---

## Scenario & victory

```swift
public enum VictoryRule: Codable, Sendable, Equatable {
    case destroyAllEnemies
    case destroyAllEnemiesOrStructureAfterTurn(maxTurn: Int)
    // Full Lances later: case firstToVictoryPoints(threshold: Int)
}

public struct ScenarioRuleset: Codable, Sendable, Equatable {
    public var overheatAllowed: Bool
    public var physicalAttacksAllowed: Bool
    public var forcedWithdrawal: Bool
    public var maxTurns: Int?              // e.g. 6 for Ridge Line tiebreak
    public var victory: VictoryRule

    public static let ridgeLine = ScenarioRuleset(
        overheatAllowed: false,
        physicalAttacksAllowed: false,
        forcedWithdrawal: false,
        maxTurns: 6,
        victory: .destroyAllEnemiesOrStructureAfterTurn(maxTurn: 6)
    )
}
```

---

## Crit flags & unit snapshots

```swift
public struct CritFlags: Codable, Sendable, Equatable {
    public var fireControlHits: Int      // each +2 TN
    public var engineHits: Int           // 2+ → destroyed at End
    public var weaponHits: Int           // each −1 to S/M/L (floor 0)
    public var mpHit: Bool               // halve MV inches & TMM (floor)
    public var ammoExploded: Bool        // destroyed unless ENE/CASE/CASEII
    public var destroyedByCrit: Bool     // remove at End
}

public struct MatchUnitState: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var libraryUnitId: UUID?      // optional link to Force library
    public var name: String
    public var side: SideId
    public var skill: Int                // 2...5 typical
    public var pv: Int
    public var sz: Int
    public var mv: String                // e.g. "10\"/6\"j" or "12\""
    public var tmm: Int
    public var s: Int
    public var m: Int
    public var l: Int
    public var ov: Int
    public var armorCap: Int
    public var structureCap: Int
    public var armorDamage: Int          // 0...armorCap
    public var structureDamage: Int      // 0...structureCap
    public var heat: Int                 // 0...4
    public var abilities: String         // free text for v1; parse later
    public var crits: CritFlags
    public var movementMode: MovementMode
    public var hasMovedThisTurn: Bool
    public var hasAttackedThisTurn: Bool
    public var combatStatus: UnitCombatStatus
    public var leftTable: Bool           // left the play area: .removed, counts as destroyed (p. 12)
    public var withdrawalAnnounced: Bool // End Phase logged "… is crippled and must withdraw"
    // Both decode as false when missing (saves from before Full Lances).
}

public extension MatchUnitState {
    var remainingArmor: Int { max(0, armorCap - armorDamage) }
    var remainingStructure: Int { max(0, structureCap - structureDamage) }
    var isStructurallyDestroyed: Bool { structureCap > 0 && structureDamage >= structureCap }
    /// May still fire in Combat if destroyedPendingEnd
    var canFire: Bool {
        combatStatus == .active || combatStatus == .destroyedPendingEnd
    }
    /// Crippled (rulebook p. 12), any one of:
    /// no armor and remainingStructure <= (structureCap + 1) / 2;
    /// effective Medium and Long both 0 after weapon hits (a card printing 0/0 needs a weapon hit first);
    /// MP hits took its move to 0 (a heat shutdown doesn't count).
    var isCrippled: Bool
}

public extension MatchSession {
    /// ruleset.forcedWithdrawal && unit is .active && unit.isCrippled
    func mustWithdraw(_ unit: MatchUnitState) -> Bool
    /// Crippled and not yet announced (Clean up lists them).
    var newlyCrippled: [MatchUnitState] { get }
    /// nil when `.leaveTable` is legal: active match, unit .active, no critical owed,
    /// and in Movement either already moved or its side's turn ("Record this on its move.").
    func leaveTableBlockReason(_ unit: MatchUnitState) -> String?
}
```

**Leaving the table:** `MatchCommand.leaveTable(unitId:)` sets `leftTable`, `combatStatus = .removed`, clears owed criticals and logs "<name> left the table". It is undoable like any command. In Movement, before the unit has moved, it is that unit's move: `hasMovedThisTurn` is set and the turn passes on. `AlphaStrikePhaseEngine.inMoveOrder` keeps a unit that left on this turn's move in the move order, so alternation doesn't skip; `resetTurnFlags` clears it for the next turn. `VictoryEvaluator` counts only `.active` units, so a unit that left counts as destroyed and adds no structure to the turn-cap score.

**Crippled announcement:** `.resolveEndPhase` logs "<name> is crippled and must withdraw" once per unit when `mustWithdraw`, then sets `withdrawalAnnounced`.

**Library record** (`ASUnitRecord` in persistence) mirrors card fields without match-only flags (`hasMovedThisTurn`, `combatStatus`, `movementMode`). Mapping: copy card fields into `MatchUnitState` at mission start; `libraryUnitId` set when upserting from Force.

---

## Match session (complete)

```swift
public struct MatchEvent: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var turn: Int
    public var phase: PhaseId
    public var message: String           // localized key or English for v1
    public var createdAt: Date
}

public struct MatchSession: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var modeId: GameModeId
    public var scenarioId: ScenarioId?
    public var ruleset: ScenarioRuleset
    public var turn: Int                 // starts at 1
    public var phase: PhaseId
    public var activeSide: SideId
    public var initiativeWinner: SideId?
    public var initiativeRolls: InitiativeRolls?
    public var units: [MatchUnitState]
    public var eventLog: [MatchEvent]
    public var status: MatchStatus
    public var tableReady: Bool          // setup step 2
    public var forcesLoaded: Bool
    public var updatedAt: Date
}

public struct InitiativeRolls: Codable, Sendable, Equatable {
    public var lanceA: DiceRoll2D6
    public var lanceB: DiceRoll2D6
}

public struct DiceRoll2D6: Codable, Sendable, Equatable {
    public var die1: Int                 // 1...6
    public var die2: Int                 // 1...6
    public var total: Int { die1 + die2 }
}
```

---

## Phase engine prompts

```swift
public struct PhaseContext: Sendable, Equatable {
    public var turn: Int
    public var phase: PhaseId
    public var activeSide: SideId
    public var initiativeWinner: SideId?
    public var ruleset: ScenarioRuleset
}

public struct PhasePrompt: Sendable, Equatable {
    public var title: String
    public var detail: String
}
```

`PlayEngine.alphaStrikePhased.phaseOrder` = `[.initiative, .movement, .combat, .end]`.

---

## Combat Domain results

```swift
public struct SATORInput: Sendable, Equatable {
    public var skill: Int                         // S base
    public var attackerMove: MovementMode         // unset → treat as .ground
    public var targetMove: TargetMoveModifier
    public var targetTMM: Int
    public var other: OtherModifiers
    public var rangeInches: Double?               // if set, derive bracket
    public var rangeBracket: RangeBracket?        // explicit override
}

public enum TargetMoveModifier: String, Sendable, Codable {
    case immobile
    case standstill
    case groundUsesTMM
    case jumpedUsesTMMPlus1
}

public struct OtherModifiers: Sendable, Equatable {
    public var woods: Bool
    public var partialCover: Bool
    public var chargeOrDFA: Bool
    public var targetHasSTL: Bool
    public var fireControlHits: Int
    public var attackerHeat: Int
}

public enum RangeBracket: String, Sendable, Codable {
    case short   // +0, ≤6"
    case medium  // +2, >6"…24"
    case long    // +4, >24"…42"
    case outOfRange
}

public struct TargetNumber: Sendable, Equatable {
    public var value: Int
    public var autoMiss: Bool            // value > 12
    public var hitOddsPercent: Int       // 0...100 combinatorial 2D6
    public var breakdown: [String]       // debug / UI lines
}

public struct DamageInput: Sendable, Equatable {
    public var short: Int
    public var medium: Int
    public var long: Int
    public var bracket: RangeBracket
    public var rearHit: Bool             // +1
    public var overheatUsed: Int         // 0...OV; 0 if ruleset disallows
    public var ovlAllowsLong: Bool
}

public struct DamageResult: Sendable, Equatable {
    public var delivered: Int
}

/// One attack a turn: weapon fire or a Standard physical attack (punch or kick).
/// Carried by `SATORInput`, `CombatTableInsight`, `SATORAttackCommand` and `TurnShot`
/// (`TurnShot.kind` decodes as `.weapon` when missing, for saves from before Close Quarters).
public enum AttackKind: String, Codable, Sendable { case weapon, physical }
// Physical damage: AlphaStrikeDamage.physical(attacker:rearHit:) = Size (+1 with MEL) + rear 1.

public struct ApplyDamageResult: Sendable, Equatable {
    public var unit: MatchUnitState
    public var needsCritical: Bool       // any structure marked this hit, or natural 12 hit through armor per rules
    public var becameStructurallyDestroyed: Bool
}
```

---

## Naming map

| Spec / UI | Domain / Data |
|-----------|----------------|
| Force library unit | `ASUnitRecord` (persistence) ↔ card fields of `MatchUnitState` |
| Match roster unit | `MatchUnitState` |
| Side A / B | `SideId.lanceA` / `.lanceB` |

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-08-21 |
| Commit | — |
| Code paths | *not implemented* |
