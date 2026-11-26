import Foundation
import MechBuddyDomain

/// Clash of Steel's box rules: Battlefield Support, Formations and buildings (Quick-Start pp. 28–32).
extension MatchStore {
    var boxRules: BoxRulesState? { session?.boxRules }

    /// The Command Lance whose Combat Intuition this shot uses: only in the Movement Phase.
    func combatIntuitionFormation(for attackerId: UUID) -> FormationState? {
        guard let session, session.phase == .movement,
              let formation = session.boxRules?.formation(of: attackerId, kind: .commandLance),
              formation.combatIntuitionIds.contains(attackerId) else { return nil }
        return formation
    }

    /// Combat Intuition 'Mechs that may attack right now.
    var combatIntuitionShooters: [MatchUnitState] {
        guard let session, let rules = session.boxRules else { return [] }
        return rules.formations.filter { $0.kind == .commandLance }.flatMap { formation in
            session.units.filter {
                formation.combatIntuitionIds.contains($0.id)
                    && FormationRules.combatIntuitionBlockReason(formation, unit: $0, session: session) == nil
            }
        }
    }

    /// A Combat Intuition kill or crit-kill leaves the table at once. Not an undo step of its own.
    func settleCombatIntuition() {
        guard session?.phase == .movement, session?.boxRules?.combatIntuitionTargets.isEmpty == false else { return }
        mutateBoxRules(.settleImmediateEffects, undoable: false)
    }

    func setSupportPicks(side: SideId, picks: [BattlefieldSupportType]) {
        mutateBoxRules(.setSupportPicks(side: side, picks: picks), undoable: false, failureTitle: "Couldn’t buy that support")
    }

    func lockSupportPicks(side: SideId) {
        mutateBoxRules(.lockSupportPicks(side: side), failureTitle: "Couldn’t save the support")
    }

    @discardableResult
    func useSupport(side: SideId, pickId: UUID, die1: Int, die2: Int, scatterDirection: Int?, scatterDistance: Int?, unitsHit: [UUID]) -> Bool {
        guard let roll = DiceRoll2D6.validated(die1: die1, die2: die2) else { return false }
        mutateBoxRules(
            .useSupport(side: side, pickId: pickId, roll: roll, scatterDirection: scatterDirection,
                        scatterDistance: scatterDistance, unitsHit: unitsHit),
            failureTitle: "Couldn’t use that support"
        )
        return lastError == nil
    }

    func designateCombatIntuition(formationId: String, unitIds: [UUID]) {
        mutateBoxRules(.designateCombatIntuition(formationId: formationId, unitIds: unitIds), failureTitle: "Couldn’t choose those ’Mechs")
    }

    @discardableResult
    func rerollInitiative(formationId: String, die1: Int, die2: Int) -> Bool {
        guard let roll = DiceRoll2D6.validated(die1: die1, die2: die2) else { return false }
        mutateBoxRules(.rerollInitiative(formationId: formationId, roll: roll), failureTitle: "Couldn’t reroll Initiative")
        return lastError == nil
    }

    func useLucky(formationId: String, unitId: UUID) {
        mutateBoxRules(.useLucky(formationId: formationId, unitId: unitId), undoable: false, failureTitle: "Couldn’t use Lucky")
    }

    func damageBuilding(_ buildingId: String, amount: Int) {
        mutateBoxRules(.damageBuilding(buildingId: buildingId, amount: amount), failureTitle: "Couldn’t damage the building")
    }

    @discardableResult
    func attackBuilding(_ buildingId: String, attackerId: UUID, bracket: RangeBracket, die1: Int, die2: Int, attackerMove: MovementMode) -> Bool {
        guard let roll = DiceRoll2D6.validated(die1: die1, die2: die2) else { return false }
        mutateBoxRules(
            .attackBuilding(buildingId: buildingId, attackerId: attackerId, bracket: bracket, roll: roll, attackerMove: attackerMove),
            failureTitle: "Couldn’t save the shot"
        )
        return lastError == nil
    }

    @discardableResult
    func collapseBuilding(_ buildingId: String, inside: [UUID], onRoof: [UUID], minimalDice: [UUID: Int]) -> Bool {
        mutateBoxRules(.collapseBuilding(buildingId: buildingId, inside: inside, onRoof: onRoof, minimalDice: minimalDice),
                       failureTitle: "Couldn’t collapse the building")
        return lastError == nil
    }

    func setBuildingHeight(_ buildingId: String, inches: Int) {
        mutateBoxRules(.setBuildingHeight(buildingId: buildingId, inches: inches), undoable: false)
    }
}
