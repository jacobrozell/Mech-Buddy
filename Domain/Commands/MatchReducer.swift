import Foundation

public enum MatchCommand: Sendable {
    case startMission(scenarioId: ScenarioId, ruleset: ScenarioRuleset, units: [MatchUnitState])
    case markTableReady
    case setDiceMode(DiceMode)
    case abandonMatch
    case setInitiative(InitiativeRolls)
    /// Skip the roll: the players agreed which side moves first (casual and learning games).
    case agreeInitiative(firstToMove: SideId)
    /// Tag a miniature with a colour so players can match minis to cards. Any phase.
    case setMini(unitId: UUID, mini: MiniMarker?)
    case setMovementMode(unitId: UUID, mode: MovementMode)
    case markMoved(unitId: UUID)
    /// Change a move already recorded this phase. Does not change whose turn it is.
    case reviseMovement(unitId: UUID, mode: MovementMode)
    case skipRemainingMoves
    /// Trade sides before anyone moves or shoots.
    case swapSides
    case advancePhase
    /// Both sides are done shooting. Fire is simultaneous: either side may shoot in any order.
    case finishCombat
    case acknowledgeDeployment
    case resolveSATOR(SATORAttackCommand)
    case applyCritical(unitId: UUID, roll: DiceRoll2D6)
    /// The ’Mech left the play area. It counts as destroyed and can't come back (rulebook p. 12).
    /// During Movement it is that ’Mech's move. Undo restores it like any other command.
    case leaveTable(unitId: UUID)
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
    /// Weapon fire or a punch/kick. A physical attack ignores `range` and `overheatUsed`.
    public var attackKind: AttackKind

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
        overheatUsed: Int = 0,
        attackKind: AttackKind = .weapon
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
        self.attackKind = attackKind
    }

    /// A punch or kick: within 1″, target in the front arc, damage = Size (rulebook pp. 20–22).
    public static func physical(
        attackerId: UUID,
        defenderId: UUID,
        roll: DiceRoll2D6,
        attackerMove: MovementMode? = nil,
        targetMove: TargetMoveModifier,
        woods: Bool = false,
        partialCover: Bool = false,
        rearHit: Bool = false
    ) -> SATORAttackCommand {
        SATORAttackCommand(
            attackerId: attackerId,
            defenderId: defenderId,
            range: .short,
            roll: roll,
            attackerMove: attackerMove,
            targetMove: targetMove,
            woods: woods,
            partialCover: partialCover,
            rearHit: rearHit,
            attackKind: .physical
        )
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
            next.activeSide = firstMover(next)
            next.appendLog(
                "Initiative: \(rolls.lanceA.total) to \(rolls.lanceB.total). \(winner.displayName) goes last"
            )

        case .setMini(let unitId, let mini):
            guard let idx = next.units.firstIndex(where: { $0.id == unitId }) else {
                throw MatchDomainError.unitNotFound
            }
            next.units[idx].mini = mini

        case .agreeInitiative(let first):
            guard next.phase == .initiative else {
                throw MatchDomainError.illegalPhaseTransition("Initiative already resolved")
            }
            // The side that moves first is the one that "lost" the roll; the other moves last.
            next.initiativeRolls = nil
            next.initiativeWinner = first.other
            next.activeSide = first
            next.phase = .movement
            next.activeSide = firstMover(next)
            next.appendLog("Players chose: \(first.displayName) moves first")

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
                units: next.units,
                firstToMove: next.initiativeWinner?.other
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

        case .finishCombat:
            guard next.phase == .combat else {
                throw MatchDomainError.illegalPhaseTransition("Not in combat")
            }
            if AlphaStrikePhaseEngine.hasPendingCriticals(units: next.units) {
                throw MatchDomainError.illegalPhaseTransition("Resolve pending criticals first")
            }
            next.phase = .end
            next.appendLog("End phase")

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

        case .leaveTable(let unitId):
            guard let idx = next.units.firstIndex(where: { $0.id == unitId }) else {
                throw MatchDomainError.unitNotFound
            }
            if let reason = next.leaveTableBlockReason(next.units[idx]) {
                throw MatchDomainError.illegalPhaseTransition(reason)
            }
            let movingOffNow = next.phase == .movement && !next.units[idx].hasMovedThisTurn
            if movingOffNow {
                next.units[idx].hasMovedThisTurn = true
                if next.units[idx].movementMode == .unset {
                    next.units[idx].movementMode = .ground
                }
            }
            next.units[idx].leftTable = true
            next.units[idx].combatStatus = .removed
            next.units[idx].criticalsOwed = 0
            if movingOffNow {
                // It still counts in this turn's move order (AlphaStrikePhaseEngine.inMoveOrder).
                next.activeSide = AlphaStrikePhaseEngine.nextMovementActiveSide(
                    current: next.activeSide,
                    units: next.units,
                    firstToMove: next.initiativeWinner?.other
                )
            }
            next.appendLog("\(next.units[idx].name) left the table")

        case .resolveEndPhase:
            guard next.phase == .end else {
                throw MatchDomainError.illegalPhaseTransition("Not in end phase")
            }
            for line in AlphaStrikeHeat.applyEndPhase(&next.units) {
                next.appendLog(line)
            }
            AlphaStrikePhaseEngine.removeDestroyedAtEnd(&next.units)
            for i in next.units.indices {
                next.units[i].combatPhaseCrits = nil
            }
            // Forced Withdrawal: say once that a ’Mech is crippled. From now on it heads home.
            for i in next.units.indices where next.mustWithdraw(next.units[i]) && !next.units[i].withdrawalAnnounced {
                next.units[i].withdrawalAnnounced = true
                next.appendLog("\(next.units[i].name) is crippled and must withdraw")
            }
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

        // No side gate: damage and crits land at the end of the phase (combatPhaseCrits),
        // so the order shots are entered in can't change the result. Players roll together.
        guard attacker.canAttackThisTurn else {
            throw MatchDomainError.cannotAttack("Unit cannot attack")
        }
        guard defender.side != attacker.side else {
            throw MatchDomainError.cannotAttack("Invalid target")
        }
        guard defender.combatStatus != .removed else {
            throw MatchDomainError.cannotAttack("Target removed")
        }

        let physical = attack.attackKind == .physical
        if physical, !next.ruleset.physicalAttacksAllowed {
            throw MatchDomainError.cannotAttack("Punches and kicks aren’t used in this mission.")
        }
        let bracket = physical ? RangeBracket.short : attack.range
        let move = attack.attackerMove
            ?? (attacker.movementMode == .unset ? .ground : attacker.movementMode)
        if !physical, let reason = CombatSolver.noDamageReason(attacker: attacker, bracket: bracket) {
            throw MatchDomainError.cannotAttack(reason)
        }
        let tn = try SATORResolver.resolve(
            CombatSolver.satorInput(
                attacker: attacker,
                defender: defender,
                attackerMove: move,
                targetMove: attack.targetMove,
                woods: attack.woods,
                partialCover: attack.partialCover,
                rangeInches: nil,
                bracket: bracket,
                attackKind: attack.attackKind
            )
        )

        let hit = SATORResolver.isHit(tn: tn, roll: attack.roll)
        var deliveredDamage = 0
        var note = ""
        // Overheat is declared before the roll, so the heat comes whether the shot hits or not.
        // It can't add to a punch or kick (p. 24).
        let overheat = physical ? 0 : AlphaStrikeHeat.usableOverheat(
            requested: attack.overheatUsed,
            attacker: attacker,
            bracket: bracket,
            overheatAllowed: next.ruleset.overheatAllowed
        )
        // Keep the "X hit Y for N. Rolled R, needed T." shape: ShotFeed and Victory stats read it.
        let how = physical ? " Punch or kick." : ""

        if hit {
            let delivered = physical
                ? AlphaStrikeDamage.physical(attacker: attacker, rearHit: attack.rearHit)
                : AlphaStrikeDamage.delivered(
                    CombatSolver.damageInput(
                        attacker: attacker,
                        bracket: bracket,
                        rearHit: attack.rearHit,
                        overheatUsed: overheat
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
            note = "\(attacker.name) hit \(defender.name) for \(delivered.delivered). Rolled \(attack.roll.total), needed \(tn.value).\(how)"
            if applied.needsCritical {
                note += " A critical is owed."
            }
        } else {
            note = "\(attacker.name) missed \(defender.name). Rolled \(attack.roll.total), needed \(tn.value).\(how) No damage."
        }

        if overheat > 0 {
            note += " Overheated \(overheat)."
        }
        // Overheat and engine-hit heat land in the End Phase (AlphaStrikeHeat.endPhase).
        attacker.overheatThisTurn = overheat
        attacker.hasAttackedThisTurn = true
        attacker.turnShot = TurnShot(
            targetName: defender.name,
            hit: hit,
            total: attack.roll.total,
            targetNumber: tn.value,
            damage: deliveredDamage,
            kind: attack.attackKind
        )
        // Persist attacker's chosen move if provided (UI may pass sheet move).
        if let attackerMove = attack.attackerMove {
            attacker.movementMode = attackerMove == .unset ? .ground : attackerMove
        }
        next.units[attackerIdx] = attacker
        next.appendLog(note)
        return next
    }

    /// Usually the initiative loser; the other side if the loser has nothing left to move.
    private static func firstMover(_ session: MatchSession) -> SideId {
        let loser = session.initiativeWinner?.other ?? session.activeSide
        return AlphaStrikePhaseEngine.movementSequence(firstToMove: loser, units: session.units).first ?? loser
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
            for i in next.units.indices {
                next.units[i].combatPhaseCrits = next.units[i].crits
            }
            if let winner = next.initiativeWinner {
                next.activeSide = winner.other
            }
            next.appendLog("Combat phase")
        case .combat:
            throw MatchDomainError.illegalPhaseTransition("Use finishCombat")
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
