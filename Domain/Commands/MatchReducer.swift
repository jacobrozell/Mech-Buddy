import Foundation

public enum MatchCommand: Sendable {
    case startMission(scenarioId: ScenarioId, ruleset: ScenarioRuleset, units: [MatchUnitState])
    case markTableReady
    case setDiceMode(DiceMode)
    case abandonMatch
    case setInitiative(InitiativeRolls)
    case setMovementMode(unitId: UUID, mode: MovementMode)
    case markMoved(unitId: UUID)
    /// Change a move already recorded this phase. Does not change whose turn it is.
    case reviseMovement(unitId: UUID, mode: MovementMode)
    case skipRemainingMoves
    /// Trade sides before anyone moves or shoots.
    case swapSides
    case advancePhase
    case finishCombatSide
    case acknowledgeDeployment
    case resolveSATOR(SATORAttackCommand)
    case applyCritical(unitId: UUID, roll: DiceRoll2D6)
    case resolveEndPhase
    case completeMatch(MatchOutcome)
}

public struct SATORAttackCommand: Sendable, Equatable {
    public var attackerId: UUID
    public var defenderId: UUID
    public var range: RangeBracket
    public var roll: DiceRoll2D6
    public var attackerMove: MovementMode?
    public var targetMove: TargetMoveModifier
    public var woods: Bool
    public var partialCover: Bool
    public var rearHit: Bool
    public var overheatUsed: Int

    public init(
        attackerId: UUID,
        defenderId: UUID,
        range: RangeBracket,
        roll: DiceRoll2D6,
        attackerMove: MovementMode? = nil,
        targetMove: TargetMoveModifier,
        woods: Bool = false,
        partialCover: Bool = false,
        rearHit: Bool = false,
        overheatUsed: Int = 0
    ) {
        self.attackerId = attackerId
        self.defenderId = defenderId
        self.range = range
        self.roll = roll
        self.attackerMove = attackerMove
        self.targetMove = targetMove
        self.woods = woods
        self.partialCover = partialCover
        self.rearHit = rearHit
        self.overheatUsed = overheatUsed
    }
}

public enum MatchReducer {
    public static func reduce(_ session: MatchSession, _ command: MatchCommand) throws -> MatchSession {
        var next = session
        next.updatedAt = Date()

        switch command {
        case .startMission(let scenarioId, let ruleset, let units):
            next = MatchSession(
                modeId: .alphaStrike,
                scenarioId: scenarioId,
                ruleset: ruleset,
                units: units,
                status: .active,
                tableReady: false,
                forcesLoaded: true
            )

        case .markTableReady:
            next.tableReady = true

        case .setDiceMode(let mode):
            next.diceMode = mode

        case .abandonMatch:
            next.status = .abandoned
            next.outcome = nil

        case .setInitiative(let rolls):
            guard next.phase == .initiative else {
                throw MatchDomainError.illegalPhaseTransition("Initiative already resolved")
            }
            let winner = try AlphaStrikePhaseEngine.resolveInitiative(rolls: rolls)
            next.initiativeRolls = rolls
            next.initiativeWinner = winner
            next.activeSide = AlphaStrikePhaseEngine.initiativeLoser(winner: winner)
            next.phase = .movement
            next.appendLog(
                "Initiative: \(rolls.lanceA.total) to \(rolls.lanceB.total). \(winner.displayName) goes last"
            )

        case .setMovementMode(let unitId, let mode):
            guard next.phase == .movement else {
                throw MatchDomainError.illegalPhaseTransition("Not in movement")
            }
            guard let idx = next.units.firstIndex(where: { $0.id == unitId }) else {
                throw MatchDomainError.unitNotFound
            }
            guard next.units[idx].side == next.activeSide else {
                throw MatchDomainError.illegalPhaseTransition("Not this side’s move")
            }
            guard next.units[idx].combatStatus == .active else {
                throw MatchDomainError.cannotAttack("Unit cannot move")
            }
            try validateMovement(mode, unit: next.units[idx])
            next.units[idx].movementMode = mode

        case .reviseMovement(let unitId, let mode):
            guard next.phase == .movement else {
                throw MatchDomainError.illegalPhaseTransition("Not in movement")
            }
            guard let idx = next.units.firstIndex(where: { $0.id == unitId }) else {
                throw MatchDomainError.unitNotFound
            }
            guard next.units[idx].hasMovedThisTurn, next.units[idx].combatStatus == .active else {
                throw MatchDomainError.illegalPhaseTransition("That ’Mech has no move to change")
            }
            try validateMovement(mode, unit: next.units[idx])
            next.units[idx].movementMode = mode

        case .markMoved(let unitId):
            guard next.phase == .movement else {
                throw MatchDomainError.illegalPhaseTransition("Not in movement")
            }
            guard let idx = next.units.firstIndex(where: { $0.id == unitId }) else {
                throw MatchDomainError.unitNotFound
            }
            guard next.units[idx].side == next.activeSide else {
                throw MatchDomainError.illegalPhaseTransition("Not this side’s move")
            }
            next.units[idx].hasMovedThisTurn = true
            if next.units[idx].movementMode == .unset {
                next.units[idx].movementMode = .ground
            }
            next.activeSide = AlphaStrikePhaseEngine.nextMovementActiveSide(
                current: next.activeSide,
                units: next.units
            )

        case .skipRemainingMoves:
            guard next.phase == .movement else {
                throw MatchDomainError.illegalPhaseTransition("Not in movement")
            }
            for i in next.units.indices where next.units[i].combatStatus == .active && !next.units[i].hasMovedThisTurn {
                if next.units[i].movementMode == .unset {
                    next.units[i].movementMode = .ground
                }
                next.units[i].hasMovedThisTurn = true
            }

        case .swapSides:
            guard next.canSwapSides else {
                throw MatchDomainError.illegalPhaseTransition("Sides can be swapped until the first move")
            }
            for i in next.units.indices {
                next.units[i].side = next.units[i].side.other
            }
            next.activeSide = next.activeSide.other
            next.initiativeWinner = next.initiativeWinner?.other
            if let rolls = next.initiativeRolls {
                next.initiativeRolls = InitiativeRolls(lanceA: rolls.lanceB, lanceB: rolls.lanceA)
            }
            next.appendLog("Swapped sides")

        case .advancePhase:
            next = try advance(next)

        case .finishCombatSide:
            guard next.phase == .combat, let winner = next.initiativeWinner else {
                throw MatchDomainError.illegalPhaseTransition("Not in combat")
            }
            if AlphaStrikePhaseEngine.hasPendingCriticals(units: next.units) {
                throw MatchDomainError.illegalPhaseTransition("Resolve pending criticals first")
            }
            let loser = winner.other
            if next.activeSide == loser {
                next.activeSide = winner
                next.appendLog("\(winner.displayName) combat")
            } else {
                next.phase = .end
                next.appendLog("End phase")
            }

        case .acknowledgeDeployment:
            guard next.needsDeploymentAcknowledgement else {
                throw MatchDomainError.illegalPhaseTransition("Placement is only at the start of the first turn")
            }
            next.deploymentAcknowledged = true

        case .resolveSATOR(let attack):
            next = try applySATOR(next, attack)

        case .applyCritical(let unitId, let roll):
            guard let idx = next.units.firstIndex(where: { $0.id == unitId }) else {
                throw MatchDomainError.unitNotFound
            }
            guard next.units[idx].pendingCritical else {
                throw MatchDomainError.illegalPhaseTransition("No critical owed")
            }
            let result = AlphaStrikeCriticals.apply(to: next.units[idx], roll: roll)
            next.units[idx] = result.unit
            next.appendLog("Crit \(result.title) on \(result.unit.name)")

        case .resolveEndPhase:
            guard next.phase == .end else {
                throw MatchDomainError.illegalPhaseTransition("Not in end phase")
            }
            AlphaStrikePhaseEngine.removeDestroyedAtEnd(&next.units)
            if let outcome = VictoryEvaluator.evaluateAfterEnd(session: next) {
                next.status = .completed
                next.outcome = outcome
                next.appendLog("Match complete: \(outcome.displaySummary)")
                return next
            }
            next.turn += 1
            next.phase = .initiative
            next.initiativeWinner = nil
            next.initiativeRolls = nil
            AlphaStrikePhaseEngine.resetTurnFlags(&next.units)
            next.appendLog("Turn \(next.turn)")

        case .completeMatch(let outcome):
            next.status = .completed
            next.outcome = outcome
            next.appendLog("Match complete: \(outcome.displaySummary)")
        }

        return next
    }

    private static func applySATOR(_ session: MatchSession, _ attack: SATORAttackCommand) throws -> MatchSession {
        var next = session
        guard next.phase == .combat else {
            throw MatchDomainError.illegalPhaseTransition("Not in combat")
        }
        if next.units.contains(where: { $0.criticalsOwed > 0 }) {
            throw MatchDomainError.illegalPhaseTransition("Roll the critical before the next shot.")
        }
        guard let attackerIdx = next.units.firstIndex(where: { $0.id == attack.attackerId }),
              let defenderIdx = next.units.firstIndex(where: { $0.id == attack.defenderId }) else {
            throw MatchDomainError.unitNotFound
        }

        var attacker = next.units[attackerIdx]
        let defender = next.units[defenderIdx]

        guard attacker.side == next.activeSide else {
            throw MatchDomainError.cannotAttack("Not this side’s combat")
        }
        guard attacker.canAttackThisTurn else {
            throw MatchDomainError.cannotAttack("Unit cannot attack")
        }
        guard defender.side != attacker.side else {
            throw MatchDomainError.cannotAttack("Invalid target")
        }
        guard defender.combatStatus != .removed else {
            throw MatchDomainError.cannotAttack("Target removed")
        }

        let move = attack.attackerMove
            ?? (attacker.movementMode == .unset ? .ground : attacker.movementMode)
        let tn = try SATORResolver.resolve(
            CombatSolver.satorInput(
                attacker: attacker,
                defender: defender,
                attackerMove: move,
                targetMove: attack.targetMove,
                woods: attack.woods,
                partialCover: attack.partialCover,
                rangeInches: nil,
                bracket: attack.range
            )
        )

        let hit = SATORResolver.isHit(tn: tn, roll: attack.roll)
        var deliveredDamage = 0
        var note = ""

        if hit {
            let delivered = AlphaStrikeDamage.delivered(
                CombatSolver.damageInput(
                    attacker: attacker,
                    bracket: attack.range,
                    rearHit: attack.rearHit,
                    overheatUsed: attack.overheatUsed
                ),
                overheatAllowed: next.ruleset.overheatAllowed
            )
            let applied = AlphaStrikeDamage.apply(
                to: defender,
                amount: delivered.delivered,
                naturalTwelveHit: attack.roll.isNaturalTwelve
            )
            next.units[defenderIdx] = applied.unit
            deliveredDamage = delivered.delivered
            note = "\(attacker.name) hit \(defender.name) for \(delivered.delivered). Rolled \(attack.roll.total), needed \(tn.value)."
            if applied.needsCritical {
                note += " A critical is owed."
            }
        } else {
            note = "\(attacker.name) missed \(defender.name). Rolled \(attack.roll.total), needed \(tn.value). No damage."
        }

        // Engine crit: +1 heat per engine hit whenever the unit fires, capped at 4.
        attacker.heat = min(4, attacker.heat + attacker.crits.engineHits)
        attacker.hasAttackedThisTurn = true
        attacker.turnShot = TurnShot(
            targetName: defender.name,
            hit: hit,
            total: attack.roll.total,
            targetNumber: tn.value,
            damage: deliveredDamage
        )
        // Persist attacker's chosen move if provided (UI may pass sheet move).
        if let attackerMove = attack.attackerMove {
            attacker.movementMode = attackerMove == .unset ? .ground : attackerMove
        }
        next.units[attackerIdx] = attacker
        next.appendLog(note)
        return next
    }

    private static func validateMovement(_ mode: MovementMode, unit: MatchUnitState) throws {
        if unit.isImmobile, mode != .standstill {
            throw MatchDomainError.illegalPhaseTransition("\(unit.name) can’t move. Record it as stood still.")
        }
        if mode == .jump, !unit.canJump {
            throw MatchDomainError.illegalPhaseTransition("\(unit.name) can’t jump. Choose stood still, walked, or sprinted.")
        }
    }

    private static func advance(_ session: MatchSession) throws -> MatchSession {
        var next = session
        switch session.phase {
        case .initiative:
            throw MatchDomainError.illegalPhaseTransition("Resolve initiative first")
        case .movement:
            guard AlphaStrikePhaseEngine.movementComplete(units: next.units) else {
                throw MatchDomainError.illegalPhaseTransition("Movement incomplete")
            }
            next.phase = .combat
            if let winner = next.initiativeWinner {
                next.activeSide = winner.other
            }
            next.appendLog("Combat phase")
        case .combat:
            throw MatchDomainError.illegalPhaseTransition("Use finishCombatSide")
        case .end:
            return try reduce(next, .resolveEndPhase)
        }
        return next
    }
}

private extension MatchSession {
    mutating func appendLog(_ message: String) {
        eventLog.append(MatchEvent(turn: turn, phase: phase, message: message))
    }
}
