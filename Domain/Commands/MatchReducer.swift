import Foundation

public enum MatchCommand: Sendable {
    case startMission(scenarioId: ScenarioId, ruleset: ScenarioRuleset, units: [MatchUnitState])
    /// A Play mode game from its setup (PlayModeSpec § 5.6). `units` are built from the setup's forces.
    case startPlay(setup: PlaySetup, units: [MatchUnitState])
    case markTableReady
    case setDiceMode(DiceMode)
    case abandonMatch
    /// One 2D6 per side still in the game, plus any tie-break rounds (PlayModeSpec § 6.1).
    case setInitiative(InitiativeRolls)
    /// Skip the roll: the players agreed which side moves first (casual and learning games). Two sides.
    case agreeInitiative(firstToMove: SideId)
    /// Skip the roll: the players chose the whole order, first to move first (§ 6.1 "Players choose the order").
    case agreeInitiativeOrder([SideId])
    /// The side gives up: its ’Mechs leave the table at once and it is out (§ 6.5).
    case concede(side: SideId)
    /// Tag a miniature with a colour so players can match minis to cards. Any phase.
    case setMini(unitId: UUID, mini: MiniMarker?)
    /// Mark a ’Mech as standing in water this turn (partial cover for shots at it, −1 heat in the End Phase).
    /// Any phase. Cleared when the next turn starts.
    case setInWater(unitId: UUID, inWater: Bool)
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
    /// The 1D6 for a hit at a "0*" band (rulebook p. 21). Required when such a shot hits.
    public var minimalDie: Int?

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
        attackKind: AttackKind = .weapon,
        minimalDie: Int? = nil
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
        self.minimalDie = minimalDie
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

        case .startPlay(let setup, let units):
            next = MatchSession(
                modeId: .alphaStrike,
                scenarioId: nil,
                ruleset: setup.ruleset,
                sides: setup.sides.map { side in
                    var fresh = MatchSide(id: side.id, name: side.name, players: side.players, homeEdge: side.homeEdge)
                    fresh.name = side.name.trimmingCharacters(in: .whitespaces).isEmpty ? side.id.displayName : side.name
                    return fresh
                },
                play: setup,
                units: units,
                status: .active,
                tableReady: false,
                forcesLoaded: true,
                diceMode: setup.diceMode
            )
            next.appendLog("New game: \(setup.formatName), \(setup.budget.summary)")

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
            guard Set(rolls.rolls.keys) == Set(next.sidesInGame) else {
                throw MatchDomainError.illegalPhaseTransition("Enter a roll for every side still in the game")
            }
            let order = try AlphaStrikePhaseEngine.initiativeOrder(rolls: rolls)
            let winner = order[order.count - 1]
            var resolved = rolls
            resolved.order = order
            next.initiativeRolls = resolved
            next.initiativeWinner = winner
            next.initiativeOrder = order
            next.activeSide = order[0]
            next.phase = .movement
            next.activeSide = firstMover(next)
            if order.count == 2, let a = rolls.lanceA, let b = rolls.lanceB {
                next.appendLog("Initiative: \(a.total) to \(b.total). \(winner.displayName) goes last")
            } else {
                let totals = next.sidesInGame.compactMap { side in
                    rolls.rolls[side].map { "\(side.letter) \($0.total)" }
                }
                next.appendLog(
                    "Initiative: \(totals.joined(separator: ", ")). Order: "
                        + order.map(\.letter).joined(separator: ", ")
                        + ". \(next.displayName(of: winner)) goes last"
                )
            }

        case .setMini(let unitId, let mini):
            guard let idx = next.units.firstIndex(where: { $0.id == unitId }) else {
                throw MatchDomainError.unitNotFound
            }
            next.units[idx].mini = mini

        case .setInWater(let unitId, let inWater):
            guard let idx = next.units.firstIndex(where: { $0.id == unitId }) else {
                throw MatchDomainError.unitNotFound
            }
            next.units[idx].inWater = inWater

        case .agreeInitiative(let first):
            guard next.phase == .initiative else {
                throw MatchDomainError.illegalPhaseTransition("Initiative already resolved")
            }
            // The side that moves first is the one that "lost" the roll; the other moves last.
            guard next.sidesInGame.contains(first) else {
                throw MatchDomainError.illegalPhaseTransition("That side is out")
            }
            let order = [first] + next.sidesInGame.filter { $0 != first }
            next.initiativeRolls = nil
            next.initiativeWinner = order.last
            next.initiativeOrder = order
            next.activeSide = first
            next.phase = .movement
            next.activeSide = firstMover(next)
            next.appendLog("Players chose: \(first.displayName) moves first")

        case .agreeInitiativeOrder(let order):
            guard next.phase == .initiative else {
                throw MatchDomainError.illegalPhaseTransition("Initiative already resolved")
            }
            guard order.count == next.sidesInGame.count, Set(order) == Set(next.sidesInGame) else {
                throw MatchDomainError.illegalPhaseTransition("Put every side still in the game in order")
            }
            next.initiativeRolls = nil
            next.initiativeWinner = order.last
            next.initiativeOrder = order
            next.activeSide = order[0]
            next.phase = .movement
            next.activeSide = firstMover(next)
            next.appendLog("Players chose the order: " + order.map { next.displayName(of: $0) }.joined(separator: ", "))

        case .concede(let side):
            guard next.status == .active else {
                throw MatchDomainError.illegalPhaseTransition("The game is over.")
            }
            guard let sideIndex = next.sides.firstIndex(where: { $0.id == side }), !next.sides[sideIndex].isOut else {
                throw MatchDomainError.illegalPhaseTransition("That side is already out")
            }
            if next.units.contains(where: \.pendingCritical) {
                throw MatchDomainError.illegalPhaseTransition("Roll the critical first.")
            }
            for i in next.units.indices where next.units[i].side == side && next.units[i].combatStatus != .removed {
                next.units[i].combatStatus = .removed
                next.units[i].criticalsOwed = 0
            }
            next.sides[sideIndex].isOut = true
            next.sides[sideIndex].conceded = true
            next.sides[sideIndex].outOnTurn = next.turn
            next.initiativeOrder.removeAll { $0 == side }
            next.appendLog("\(next.displayName(of: side)) conceded and is out.")
            if let outcome = VictoryEvaluator.lastSideStanding(in: next) {
                next.status = .completed
                next.outcome = outcome
                next.appendLog("Match complete: \(outcome.displaySummary)")
                return next
            }
            if next.phase == .movement, next.activeSide == side || !next.sidesInGame.contains(next.activeSide) {
                next.activeSide = AlphaStrikePhaseEngine.nextMovementActiveSide(
                    current: next.activeSide,
                    units: next.units,
                    order: next.initiativeOrder
                )
            }
            if next.activeSide == side {
                next.activeSide = next.nextSide(after: side)
            }

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
                order: next.initiativeOrder
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
            // Two sides trade places. With more sides this becomes "Reorder sides" before the battle (§ 8.1).
            guard next.sides.count == 2 else {
                throw MatchDomainError.illegalPhaseTransition("Reorder sides instead")
            }
            let swap = { (side: SideId) in session.otherSide(of: side) }
            for i in next.units.indices {
                next.units[i].side = swap(next.units[i].side)
            }
            next.activeSide = swap(next.activeSide)
            next.initiativeWinner = next.initiativeWinner.map(swap)
            next.initiativeOrder = next.initiativeOrder.map(swap)
            next.initiativeRolls = next.initiativeRolls?.mapSides(swap)
            next.boxRules = next.boxRules?.mapSides(swap)
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
                    order: next.initiativeOrder
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
            // Sides with nothing left on the table are out (§ 6.5). Two sides: that ends the game below,
            // and the result says so, so the line is only logged with three or more sides.
            let wentOut = AlphaStrikePhaseEngine.markSidesOut(&next)
            if next.sides.count > 2 {
                for side in wentOut {
                    next.appendLog("\(next.displayName(of: side)) is out.")
                }
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
            next.initiativeOrder = []
            AlphaStrikePhaseEngine.resetTurnFlags(&next.units)
            next.appendLog("Turn \(next.turn)")

        case .completeMatch(let outcome):
            next.status = .completed
            next.outcome = outcome
            next.appendLog("Match complete: \(outcome.displaySummary)")
        }

        return next
    }

    static func applySATOR(_ session: MatchSession, _ attack: SATORAttackCommand) throws -> MatchSession {
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
        let rearFiring = attack.attackKind == .rearFiring
        guard rearFiring ? attacker.canRearFireThisTurn : attacker.canAttackThisTurn else {
            throw MatchDomainError.cannotAttack(rearFiring ? "No rear-firing attack available" : "Unit cannot attack")
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
        // A REAR shot is a weapon attack, and a ’Mech can’t make a physical attack in a turn it made one (p. 22).
        if physical, attacker.rearShot != nil {
            throw MatchDomainError.cannotAttack("It already fired its rear weapons this turn, so it can’t punch or kick.")
        }
        let bracket = physical ? RangeBracket.short : attack.range
        let move = attack.attackerMove
            ?? (attacker.movementMode == .unset ? .ground : attacker.movementMode)
        if !physical, let reason = CombatSolver.noDamageReason(attacker: attacker, bracket: bracket, kind: attack.attackKind) {
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
        let overheat = (physical || rearFiring) ? 0 : AlphaStrikeHeat.usableOverheat(
            requested: attack.overheatUsed,
            attacker: attacker,
            bracket: bracket,
            overheatAllowed: next.ruleset.overheatAllowed
        )
        // Keep the "X hit Y for N. Rolled R, needed T." shape: ShotFeed and Victory stats read it.
        let how = physical ? " Punch or kick." : (rearFiring ? " Rear-firing weapons." : "")

        let minimal = CombatSolver.isMinimalAttack(
            attacker: attacker,
            bracket: bracket,
            kind: attack.attackKind,
            overheatUsed: overheat
        )
        if hit, minimal {
            // "0*" (rulebook p. 21): 1D6, 4+ is one point of damage; otherwise a hit that deals nothing and rolls no crit.
            guard let die = attack.minimalDie, MinimalDamage.isValid(die: die) else {
                throw MatchDomainError.cannotAttack("Roll the minimal damage die (1D6) for this hit.")
            }
            let amount = MinimalDamage.damage(forDie: die)
            deliveredDamage = amount
            if amount > 0 {
                let applied = AlphaStrikeDamage.apply(
                    to: defender,
                    amount: amount,
                    naturalTwelveHit: attack.roll.isNaturalTwelve
                )
                next.units[defenderIdx] = applied.unit
                note = "\(attacker.name) hit \(defender.name) for \(amount). Rolled \(attack.roll.total), needed \(tn.value).\(how) Minimal damage die \(die): 1 point."
                if applied.needsCritical { note += " A critical is owed." }
            } else {
                note = "\(attacker.name) hit \(defender.name) for 0. Rolled \(attack.roll.total), needed \(tn.value).\(how) Minimal damage die \(die), needs \(MinimalDamage.threshold)+: no damage and no critical."
            }
        } else if hit {
            let delivered = physical
                ? AlphaStrikeDamage.physical(attacker: attacker, rearHit: attack.rearHit)
                : AlphaStrikeDamage.delivered(
                    CombatSolver.damageInput(
                        attacker: attacker,
                        bracket: bracket,
                        rearHit: attack.rearHit,
                        overheatUsed: overheat,
                        kind: attack.attackKind
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
        if hit {
            // HT#/#/#: a hit at that range adds heat to the target in the End Phase, at most 2 a turn (p. 25).
            let heatAbility = (physical || rearFiring) ? 0 : attacker.heatAbility(at: bracket)
            if heatAbility > 0 {
                let before = next.units[defenderIdx].incomingHeatThisTurn
                let after = min(MatchUnitState.maxIncomingHeatPerTurn, before + heatAbility)
                next.units[defenderIdx].incomingHeatThisTurn = after
                if after > before {
                    note += " +\(after - before) heat to \(defender.name) in the End Phase (HT)."
                }
            }
        }

        if overheat > 0 {
            note += " Overheated \(overheat)."
        }
        // Overheat and engine-hit heat land in the End Phase (AlphaStrikeHeat.endPhase).
        let shot = TurnShot(
            targetName: defender.name,
            hit: hit,
            total: attack.roll.total,
            targetNumber: tn.value,
            damage: deliveredDamage,
            kind: attack.attackKind
        )
        if rearFiring {
            // The forward shot can still follow, with this REAR value taken off its damage (p. 25).
            attacker.rearShot = shot
            attacker.rearFireReduction = attacker.rearDamage(at: bracket)
            note += " Forward damage this turn is \(attacker.rearFireReduction) less."
        } else {
            attacker.overheatThisTurn = overheat
            attacker.hasAttackedThisTurn = true
            attacker.turnShot = shot
        }
        // Persist attacker's chosen move if provided (UI may pass sheet move).
        if let attackerMove = attack.attackerMove {
            attacker.movementMode = attackerMove == .unset ? .ground : attackerMove
        }
        next.units[attackerIdx] = attacker
        next.appendLog(note)
        return next
    }

    /// Usually the initiative loser; the next side in order if the loser has nothing left to move.
    private static func firstMover(_ session: MatchSession) -> SideId {
        let order = session.initiativeOrder
        let loser = order.first ?? session.activeSide
        return AlphaStrikePhaseEngine.movementSequence(order: order, units: session.units).first ?? loser
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
            if let first = next.initiativeOrder.first {
                next.activeSide = first
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

extension MatchSession {
    mutating func appendLog(_ message: String) {
        eventLog.append(MatchEvent(turn: turn, phase: phase, message: message))
    }
}
