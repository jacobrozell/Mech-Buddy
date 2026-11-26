import Foundation

/// Commands for the Alpha Strike box's extra rules (Battlefield Support, Formations, buildings; Quick-Start pp. 28–32).
public enum BoxRulesCommand: Sendable, Equatable {
    /// Before play: the side's secret purchase, within its budget (p. 29).
    case setSupportPicks(side: SideId, picks: [BattlefieldSupportType])
    /// Written down: the picks can't change from now on.
    case lockSupportPicks(side: SideId)
    /// Use one bought support in the Combat Phase (p. 29). `unitsHit`: the target 'Mech for a strike that hit;
    /// for the template, every 'Mech base it touches where it lands. A miss with the template needs the scatter dice.
    case useSupport(side: SideId, pickId: UUID, roll: DiceRoll2D6, scatterDirection: Int?, scatterDistance: Int?, unitsHit: [UUID])
    /// At the start of the scenario: the Command Lance 'Mechs with Combat Intuition (p. 32; not the Atlas).
    case designateCombatIntuition(formationId: String, unitIds: [UUID])
    /// The Command Lance's side rerolls its Initiative roll. The new roll stands (p. 32).
    case rerollInitiative(formationId: String, roll: DiceRoll2D6)
    /// A Combat Intuition 'Mech attacks in the Movement Phase; damage effects apply at once (p. 32).
    case combatIntuitionAttack(formationId: String, attack: SATORAttackCommand)
    /// After a critical from a Combat Intuition attack: a 'Mech it destroyed leaves the table now.
    case settleImmediateEffects
    /// A Battle Star 'Mech spends one Lucky to reroll its Attack Roll (p. 32).
    case useLucky(formationId: String, unitId: UUID)
    /// Damage to a building's CF, such as 1 per inch a 'Mech moved through it (p. 28).
    case damageBuilding(buildingId: String, amount: Int)
    /// A weapon attack on a building: immobile target, damage to CF (p. 28).
    case attackBuilding(buildingId: String, attackerId: UUID, bracket: RangeBracket, roll: DiceRoll2D6, attackerMove: MovementMode)
    /// The building comes down: damage to each 'Mech moving through it or standing on it (p. 28).
    /// `minimalDice`: for a Light building ("0*"), each 'Mech's 1D6.
    case collapseBuilding(buildingId: String, inside: [UUID], onRoof: [UUID], minimalDice: [UUID: Int])
    case setBuildingHeight(buildingId: String, inches: Int)
}

public enum BoxRulesReducer {
    public static func reduce(_ session: MatchSession, _ command: BoxRulesCommand) throws -> MatchSession {
        guard var rules = session.boxRules else {
            throw MatchDomainError.illegalPhaseTransition("This mission doesn’t use the box rules.")
        }
        var next = session
        next.updatedAt = Date()

        switch command {
        case .setSupportPicks(let side, let picks):
            guard var inventory = rules.support[side] else {
                throw MatchDomainError.illegalPhaseTransition("No Battlefield Support for this side.")
            }
            guard !inventory.locked else {
                throw MatchDomainError.illegalPhaseTransition("Support is chosen before play begins and can’t change now.")
            }
            guard BattlefieldSupportRules.fitsBudget(picks, budget: inventory.budget) else {
                throw MatchDomainError.illegalPhaseTransition(
                    "That costs \(BattlefieldSupportRules.cost(of: picks)) points; the budget is \(inventory.budget)."
                )
            }
            inventory.picks = picks.map { SupportPick(type: $0) }
            rules.support[side] = inventory

        case .lockSupportPicks(let side):
            guard var inventory = rules.support[side] else {
                throw MatchDomainError.illegalPhaseTransition("No Battlefield Support for this side.")
            }
            inventory.locked = true
            rules.support[side] = inventory
            next.boxRules = rules
            // The picks stay secret: the log says only that they are written down.
            next.appendLog("\(next.displayName(of: side)) wrote down its Battlefield Support")
            return next

        case .useSupport(let side, let pickId, let roll, let direction, let distance, let unitsHit):
            next = try useSupport(next, rules: &rules, side: side, pickId: pickId, roll: roll,
                                  direction: direction, distance: distance, unitsHit: unitsHit)

        case .designateCombatIntuition(let formationId, let unitIds):
            guard let index = rules.formations.firstIndex(where: { $0.id == formationId && $0.kind == .commandLance }) else {
                throw MatchDomainError.illegalPhaseTransition("No Command Lance.")
            }
            let formation = rules.formations[index]
            guard next.turn == 1, next.phase == .initiative || !next.units.contains(where: \.hasMovedThisTurn) else {
                throw MatchDomainError.illegalPhaseTransition("Combat Intuition is chosen at the start of the scenario.")
            }
            guard Set(unitIds).count == formation.combatIntuitionCount,
                  unitIds.allSatisfy({ formation.memberIds.contains($0) && $0 != formation.commandUnitId }) else {
                throw MatchDomainError.illegalPhaseTransition(
                    "Choose \(formation.combatIntuitionCount) Command Lance ’Mechs, not the command ’Mech."
                )
            }
            rules.formations[index].combatIntuitionIds = unitIds
            let names = unitIds.compactMap { id in next.units.first { $0.id == id }?.name }
            next.boxRules = rules
            next.appendLog("Combat Intuition: \(names.joined(separator: " and "))")
            return next

        case .rerollInitiative(let formationId, let roll):
            return try rerollInitiative(next, rules: rules, formationId: formationId, roll: roll)

        case .combatIntuitionAttack(let formationId, let attack):
            return try combatIntuitionAttack(next, rules: rules, formationId: formationId, attack: attack)

        case .settleImmediateEffects:
            settle(&next, rules: rules)
            return next

        case .useLucky(let formationId, let unitId):
            guard let index = rules.formations.firstIndex(where: { $0.id == formationId }),
                  FormationRules.canUseLucky(rules.formations[index], unitId: unitId, units: next.units) else {
                throw MatchDomainError.cannotAttack("No Lucky reroll available.")
            }
            rules.formations[index].luckyUsesLeft -= 1
            let name = next.units.first { $0.id == unitId }?.name ?? "A ’Mech"
            next.boxRules = rules
            next.appendLog("Lucky: \(name) rerolls its attack. \(rules.formations[index].luckyUsesLeft) left")
            return next

        case .damageBuilding(let buildingId, let amount):
            guard amount > 0 else { return session }
            try damage(&next, rules: &rules, buildingId: buildingId, amount: amount, why: "")

        case .attackBuilding(let buildingId, let attackerId, let bracket, let roll, let attackerMove):
            next = try attackBuilding(next, rules: &rules, buildingId: buildingId, attackerId: attackerId,
                                      bracket: bracket, roll: roll, attackerMove: attackerMove)

        case .collapseBuilding(let buildingId, let inside, let onRoof, let minimalDice):
            guard let index = rules.buildings.firstIndex(where: { $0.id == buildingId }) else {
                throw MatchDomainError.illegalPhaseTransition("No such building.")
            }
            let building = rules.buildings[index]
            rules.buildings[index].cf = 0
            rules.buildings[index].collapsed = true
            var lines: [String] = []
            for id in inside + onRoof {
                guard let u = next.units.firstIndex(where: { $0.id == id }), next.units[u].combatStatus != .removed else { continue }
                if building.type.collapseIsMinimal, minimalDice[id].map(MinimalDamage.isValid) != true {
                    throw MatchDomainError.illegalPhaseTransition("Roll the minimal damage die for each ’Mech (Light building).")
                }
                let amount = BuildingRules.collapseDamage(
                    building.type, heightInches: building.heightInches,
                    onRoof: onRoof.contains(id), minimalDie: minimalDice[id]
                )
                guard amount > 0 else { continue }
                let applied = AlphaStrikeDamage.apply(to: next.units[u], amount: amount, naturalTwelveHit: false)
                next.units[u] = applied.unit
                lines.append("\(applied.unit.name) \(amount)" + (applied.needsCritical ? " (a critical is owed)" : ""))
            }
            next.appendLog("\(building.name) collapses into rubble" + (lines.isEmpty ? "" : ". Damage: " + lines.joined(separator: ", ")))

        case .setBuildingHeight(let buildingId, let inches):
            guard let index = rules.buildings.firstIndex(where: { $0.id == buildingId }) else {
                throw MatchDomainError.illegalPhaseTransition("No such building.")
            }
            rules.buildings[index].heightInches = max(1, min(12, inches))
        }

        next.boxRules = rules
        return next
    }

    // MARK: - Battlefield Support

    private static func useSupport(
        _ session: MatchSession, rules: inout BoxRulesState, side: SideId, pickId: UUID, roll: DiceRoll2D6,
        direction: Int?, distance: Int?, unitsHit: [UUID]
    ) throws -> MatchSession {
        var next = session
        guard next.phase == .combat else {
            throw MatchDomainError.illegalPhaseTransition("Battlefield Support is declared in the Combat Phase.")
        }
        if next.units.contains(where: { $0.criticalsOwed > 0 }) {
            throw MatchDomainError.illegalPhaseTransition("Roll the critical first.")
        }
        guard var inventory = rules.support[side],
              let pickIndex = inventory.picks.firstIndex(where: { $0.id == pickId }) else {
            throw MatchDomainError.illegalPhaseTransition("That support isn’t this side’s.")
        }
        let pick = inventory.picks[pickIndex]
        guard !pick.isUsed else {
            throw MatchDomainError.illegalPhaseTransition("Each support is used once.")
        }
        let type = pick.type
        let hit = BattlefieldSupportRules.isHit(type, roll: roll)
        var line = "\(next.displayName(of: side)) called \(type.displayName). Rolled \(roll.total), needed \(type.targetNumber)."
        var targets = unitsHit
        if hit {
            if !type.usesTemplate, targets.count != 1 {
                throw MatchDomainError.illegalPhaseTransition("Pick the target ’Mech.")
            }
            line += type.usesTemplate ? " On target." : " Hit."
        } else if type.scattersOnMiss {
            guard let direction, let distance,
                  let scatter = BattlefieldSupportRules.scatter(directionDie: direction, distanceDie: distance) else {
                throw MatchDomainError.illegalPhaseTransition("Roll the scatter dice: direction, then distance.")
            }
            line += " Missed: scatters \(scatter.inches)″ toward \(scatter.direction)."
        } else {
            targets = []
            line += " Missed. Nothing happens."
        }
        var hits: [String] = []
        for id in targets {
            guard let u = next.units.firstIndex(where: { $0.id == id }), next.units[u].combatStatus != .removed else {
                throw MatchDomainError.unitNotFound
            }
            let applied = AlphaStrikeDamage.apply(to: next.units[u], amount: type.damage, naturalTwelveHit: false)
            next.units[u] = applied.unit
            hits.append("\(applied.unit.name) \(type.damage)" + (applied.needsCritical ? " (a critical is owed)" : ""))
        }
        if type.usesTemplate {
            line += hits.isEmpty ? " No ’Mech under the template." : " Damage: " + hits.joined(separator: ", ") + "."
        } else if !hits.isEmpty {
            line += " Damage: " + hits.joined(separator: ", ") + "."
        }
        inventory.picks[pickIndex].usedOnTurn = next.turn
        inventory.locked = true
        rules.support[side] = inventory
        next.appendLog(line)
        return next
    }

    // MARK: - Formations

    private static func rerollInitiative(_ session: MatchSession, rules: BoxRulesState, formationId: String, roll: DiceRoll2D6) throws -> MatchSession {
        var rules = rules
        guard let index = rules.formations.firstIndex(where: { $0.id == formationId }) else {
            throw MatchDomainError.illegalPhaseTransition("No Command Lance.")
        }
        let formation = rules.formations[index]
        guard FormationRules.canRerollInitiative(formation, session: session),
              let side = FormationRules.side(of: formation, units: session.units) else {
            throw MatchDomainError.illegalPhaseTransition("No Initiative reroll available this turn.")
        }
        guard session.phase == .movement, let rolls = session.initiativeRolls,
              !session.units.contains(where: \.hasMovedThisTurn) else {
            throw MatchDomainError.illegalPhaseTransition("Reroll Initiative before anyone moves.")
        }
        var dice = rolls.rolls
        let old = dice[side]?.total
        dice[side] = roll
        rules.formations[index].initiativeRerollTurn = session.turn
        var reset = session
        reset.phase = .initiative
        reset.boxRules = rules
        reset.appendLog("\(formation.name) rerolls Initiative: \(old.map(String.init) ?? "–") becomes \(roll.total)")
        do {
            return try MatchReducer.reduce(reset, .setInitiative(InitiativeRolls(rolls: dice)))
        } catch MatchDomainError.initiativeTied {
            // A tie after the reroll: both sides roll again, as for any tie.
            reset.initiativeRolls = nil
            reset.initiativeWinner = nil
            reset.initiativeOrder = []
            reset.appendLog("Initiative tied: both sides roll again")
            return reset
        }
    }

    private static func combatIntuitionAttack(_ session: MatchSession, rules: BoxRulesState, formationId: String, attack: SATORAttackCommand) throws -> MatchSession {
        var rules = rules
        guard let index = rules.formations.firstIndex(where: { $0.id == formationId }),
              let attacker = session.units.first(where: { $0.id == attack.attackerId }) else {
            throw MatchDomainError.unitNotFound
        }
        let formation = rules.formations[index]
        if let reason = FormationRules.combatIntuitionBlockReason(formation, unit: attacker, session: session) {
            throw MatchDomainError.cannotAttack(reason)
        }
        // The attack is resolved as in the Combat Phase, then the phase goes back to Movement.
        var next = session
        next.phase = .combat
        let logCount = next.eventLog.count
        next = try MatchReducer.applySATOR(next, attack)
        next.phase = .movement
        for i in logCount..<next.eventLog.count {
            next.eventLog[i].phase = .movement
            next.eventLog[i].message = "Combat Intuition: " + next.eventLog[i].message
        }
        rules.formations[index].combatIntuitionLastUsed[attack.attackerId] = session.turn
        rules.combatIntuitionTargets[attack.defenderId] = session.turn
        next.boxRules = rules
        settle(&next, rules: rules)
        return next
    }

    /// Combat Intuition applies damage effects before the target can act (p. 32): a 'Mech it destroyed is
    /// removed now instead of at the End Phase.
    static func settle(_ session: inout MatchSession, rules: BoxRulesState) {
        for i in session.units.indices {
            let unit = session.units[i]
            guard rules.combatIntuitionTargets[unit.id] == session.turn, unit.combatStatus != .removed,
                  unit.isStructurallyDestroyed || unit.crits.destroyedByCrit else { continue }
            session.units[i].combatStatus = .removed
            session.units[i].criticalsOwed = 0
            session.eventLog.append(MatchEvent(turn: session.turn, phase: session.phase,
                                               message: "\(unit.name) is destroyed before it can act (Combat Intuition)"))
        }
    }

    // MARK: - Buildings

    private static func damage(_ session: inout MatchSession, rules: inout BoxRulesState, buildingId: String, amount: Int, why: String) throws {
        guard let index = rules.buildings.firstIndex(where: { $0.id == buildingId }) else {
            throw MatchDomainError.illegalPhaseTransition("No such building.")
        }
        guard !rules.buildings[index].collapsed else {
            throw MatchDomainError.illegalPhaseTransition("That building is already rubble.")
        }
        let before = rules.buildings[index].cf
        rules.buildings[index].cf = max(0, before - amount)
        let b = rules.buildings[index]
        if b.cf == 0 {
            rules.buildings[index].collapsed = true
            session.appendLog("\(b.name) takes \(amount)\(why) and collapses (CF 0). Rubble now: +1″ per inch")
        } else {
            session.appendLog("\(b.name) takes \(amount)\(why). CF \(b.cf) of \(b.startingCF)")
        }
    }

    private static func attackBuilding(
        _ session: MatchSession, rules: inout BoxRulesState, buildingId: String, attackerId: UUID,
        bracket: RangeBracket, roll: DiceRoll2D6, attackerMove: MovementMode
    ) throws -> MatchSession {
        var next = session
        guard next.phase == .combat else { throw MatchDomainError.illegalPhaseTransition("Not in combat") }
        guard let a = next.units.firstIndex(where: { $0.id == attackerId }) else { throw MatchDomainError.unitNotFound }
        guard let building = rules.building(buildingId), !building.collapsed else {
            throw MatchDomainError.cannotAttack("That building is already rubble.")
        }
        var attacker = next.units[a]
        guard attacker.canAttackThisTurn else { throw MatchDomainError.cannotAttack("\(attacker.name) can’t attack this turn.") }
        let move = attackerMove == .unset ? (attacker.movementMode == .unset ? .ground : attacker.movementMode) : attackerMove
        let tn = try BuildingRules.attackTargetNumber(attacker: attacker, attackerMove: move, bracket: bracket)
        let hit = SATORResolver.isHit(tn: tn, roll: roll)
        let amount = hit ? BuildingRules.attackDamage(attacker: attacker, bracket: bracket) : 0
        attacker.hasAttackedThisTurn = true
        attacker.movementMode = move
        attacker.turnShot = TurnShot(targetName: building.name, hit: hit, total: roll.total,
                                     targetNumber: tn.value, damage: amount, kind: .weapon)
        next.units[a] = attacker
        if hit, amount > 0 {
            next.appendLog("\(attacker.name) hit \(building.name) for \(amount). Rolled \(roll.total), needed \(tn.value).")
            try damage(&next, rules: &rules, buildingId: buildingId, amount: amount, why: "")
        } else {
            next.appendLog("\(attacker.name) \(hit ? "hit" : "missed") \(building.name). Rolled \(roll.total), needed \(tn.value). No damage.")
        }
        return next
    }
}
