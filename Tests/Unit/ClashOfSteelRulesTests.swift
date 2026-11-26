import Foundation
import Testing
import MechBuddyDomain
import MechBuddyData

/// Alpha Strike Box Set Quick-Start Rulebook, 3rd printing. Page numbers are printed pages.
@Suite("Buildings (p. 28)")
struct BuildingRulesTests {
    @Test("Buildings Table: move cost, CF range and default, capacity, collapse damage (p. 28)")
    func table() {
        #expect(BuildingType.allCases.map(\.moveCostPerInch) == [1, 2, 3, 4])
        #expect(BuildingType.allCases.map(\.defaultCF) == [3, 4, 12, 20])
        #expect(BuildingType.allCases.map(\.cfRange.upperBound) == [5, 8, 18, 40])
        #expect(BuildingType.allCases.map(\.weightCapacity) == [2, 4, 6, 8])
        #expect(BuildingType.allCases.map(\.collapseDamage) == [0, 1, 2, 4])
    }

    @Test("Box buildings start at their default CF; a chosen CF stays inside the range (p. 28)")
    func startingCF() {
        #expect(BuildingState(id: "s", name: "Small", type: .medium).cf == 4)
        #expect(BuildingState(id: "l", name: "Large", type: .heavy).cf == 12)
        #expect(BuildingState(id: "l", name: "Large", type: .heavy, cf: 30).cf == 18)
    }

    @Test("Moving through: extra Move per inch, and 1 CF per inch (p. 28)")
    func moveThrough() {
        #expect(BuildingRules.extraMoveCost(.heavy, inches: 2) == 6)
        #expect(MovementCost.total(inches: 2, terrain: .building(.medium)) == 6)
        #expect(BuildingRules.moveThroughDamage(inches: 3) == 3)
    }

    @Test("Weight capacity is the total Size on the building; the table's Medium capacity is 4 (p. 28)")
    func capacity() {
        #expect(!BuildingRules.isOverCapacity(.medium, sizes: [2, 2]))
        #expect(BuildingRules.isOverCapacity(.medium, sizes: [2, 2, 1]))
        #expect(BuildingRules.isOverCapacity(.heavy, sizes: [4, 3]))
    }

    @Test("Collapse: value × every 4 full inches (min 1), +1 on the roof; Heavy 3″ is 2, 3 on the roof (p. 28)")
    func collapse() {
        #expect(BuildingRules.collapseDamage(.heavy, heightInches: 3, onRoof: false) == 2)
        #expect(BuildingRules.collapseDamage(.heavy, heightInches: 3, onRoof: true) == 3)
        #expect(BuildingRules.collapseDamage(.medium, heightInches: 8, onRoof: false) == 2)
        #expect(BuildingRules.collapseDamage(.hardened, heightInches: 12, onRoof: true) == 13)
        // Light "0*": minimal damage, 4+ on 1D6 deals 1 (owner call; p. 21 meaning of "0*").
        #expect(BuildingRules.collapseDamage(.light, heightInches: 2, onRoof: false, minimalDie: 3) == 0)
        #expect(BuildingRules.collapseDamage(.light, heightInches: 2, onRoof: false, minimalDie: 4) == 1)
    }

    @Test("A building is attacked as an immobile target: −4 (pp. 18, 28)")
    func attackTN() throws {
        let shooter = MatchUnitState(name: "Shooter", side: .lanceA, skill: 3, pv: 10, sz: 2, mv: "8\"", tmm: 1,
                                     s: 3, m: 2, l: 1, ov: 0, armorCap: 4, structureCap: 2)
        let tn = try BuildingRules.attackTargetNumber(attacker: shooter, attackerMove: .ground, bracket: .medium)
        #expect(tn.value == 3 + 2 - 4)
        #expect(BuildingRules.attackDamage(attacker: shooter, bracket: .medium) == 2)
    }
}

@Suite("Battlefield Support (pp. 29–30)")
struct BattlefieldSupportTests {
    @Test("The table: TN, damage, cost (p. 30)")
    func table() {
        let all = BattlefieldSupportType.allCases
        #expect(all.map(\.targetNumber) == [5, 5, 6, 7, 7, 8])
        #expect(all.map(\.damage) == [1, 1, 2, 2, 1, 2])
        #expect(all.map(\.cost) == [2, 3, 3, 4, 2, 3])
        #expect(all.map(\.scattersOnMiss) == [false, true, false, true, true, true])
        #expect(!BattlefieldSupportType.thumper.targetsMech && BattlefieldSupportType.lightStrike.targetsMech)
    }

    @Test("Budgets: 5 or 12, 1D6 when the scenario says nothing (pp. 12, 29)")
    func budgets() {
        #expect([1, 2, 3, 4, 5, 6].map(BattlefieldSupportRules.budget(forDie:)) == [0, 0, 5, 5, 12, 12])
        #expect(BattlefieldSupportRules.fitsBudget([.lightStrike, .sniper], budget: 5))
        #expect(!BattlefieldSupportRules.fitsBudget([.heavyBombing, .thumper], budget: 5))
        // p. 29 example, Player B: 2 + 2 + 3 + 3 + 2 = 12.
        #expect(BattlefieldSupportRules.cost(of: [.lightStrike, .lightStrike, .heavyStrike, .thumper, .sniper]) == 12)
    }

    @Test("Flat 2D6 against the TN, no modifiers; scatter is 1D6 direction and 1D6 × 2 inches (pp. 29–30)")
    func rolls() {
        #expect(BattlefieldSupportRules.isHit(.sniper, roll: DiceRoll2D6(die1: 4, die2: 4)))
        #expect(!BattlefieldSupportRules.isHit(.sniper, roll: DiceRoll2D6(die1: 3, die2: 4)))
        #expect(BattlefieldSupportRules.scatter(directionDie: 2, distanceDie: 5) == .init(direction: 2, inches: 10))
        #expect(BattlefieldSupportRules.scatter(directionDie: 7, distanceDie: 5) == nil)
    }
}

@Suite("Clash of Steel box rules in a match (pp. 28–32)")
struct BoxRulesReducerTests {
    private func unit(_ name: String, _ side: SideId, skill: Int = 3, sz: Int = 2, armor: Int = 4, structure: Int = 2) -> MatchUnitState {
        MatchUnitState(name: name, side: side, skill: skill, pv: 30, sz: sz, mv: "10\"", tmm: 2,
                       s: 3, m: 3, l: 1, ov: 0, armorCap: armor, structureCap: structure)
    }

    /// Command Lance (Atlas, Archer, Warhammer, Blackjack) and a Battle Star of three.
    private func session(phase: PhaseId = .initiative) -> MatchSession {
        let a = ["Atlas", "Archer", "Warhammer", "Blackjack"].map { unit($0, .lanceA) }
        let b = ["Warhawk", "Timber Wolf", "Nova"].map { unit($0, .lanceB, skill: 2) }
        let units = a + b
        var s = MatchSession(ruleset: .ridgeLine, phase: phase, units: units, status: .active, tableReady: true, forcesLoaded: true)
        s.boxRules = BoxRulesState(
            support: [.lanceA: SupportInventory(budget: 5), .lanceB: SupportInventory(budget: 5)],
            formations: [
                FormationState(id: "cmd", kind: .commandLance, memberIds: a.map(\.id), commandUnitId: a[0].id, combatIntuitionCount: 2),
                FormationState(id: "star", kind: .battleStar, memberIds: b.map(\.id), luckyUsesLeft: 7)
            ],
            buildings: [BuildingState(id: "L1", name: "Large building 1", type: .heavy, heightInches: 3)]
        )
        return s
    }

    private func id(_ s: MatchSession, _ name: String) -> UUID { s.units.first { $0.name == name }!.id }

    @Test("Support picks: within 5 points, secret, then locked (p. 29, p. 31)")
    func picks() throws {
        var s = session()
        #expect(throws: MatchDomainError.self) {
            try BoxRulesReducer.reduce(s, .setSupportPicks(side: .lanceA, picks: [.heavyBombing, .lightStrike]))
        }
        s = try BoxRulesReducer.reduce(s, .setSupportPicks(side: .lanceA, picks: [.lightStrike, .sniper]))
        s = try BoxRulesReducer.reduce(s, .lockSupportPicks(side: .lanceA))
        #expect(!s.eventLog.last!.message.contains("Sniper"))
        #expect(throws: MatchDomainError.self) {
            try BoxRulesReducer.reduce(s, .setSupportPicks(side: .lanceA, picks: [.thumper]))
        }
    }

    @Test("A strike hit damages its target; each support is used once; a missed strike does nothing (p. 29)")
    func strike() throws {
        var s = session()
        s = try BoxRulesReducer.reduce(s, .setSupportPicks(side: .lanceA, picks: [.lightStrike, .heavyStrike]))
        s.phase = .combat
        let picks = s.boxRules!.support[.lanceA]!.picks
        let nova = id(s, "Nova")
        s = try BoxRulesReducer.reduce(s, .useSupport(side: .lanceA, pickId: picks[1].id, roll: DiceRoll2D6(die1: 3, die2: 3),
                                                      scatterDirection: nil, scatterDistance: nil, unitsHit: [nova]))
        #expect(s.units.first { $0.id == nova }!.armorDamage == 2)
        #expect(throws: MatchDomainError.self) {
            try BoxRulesReducer.reduce(s, .useSupport(side: .lanceA, pickId: picks[1].id, roll: DiceRoll2D6(die1: 6, die2: 6),
                                                      scatterDirection: nil, scatterDistance: nil, unitsHit: [nova]))
        }
        s = try BoxRulesReducer.reduce(s, .useSupport(side: .lanceA, pickId: picks[0].id, roll: DiceRoll2D6(die1: 1, die2: 2),
                                                      scatterDirection: nil, scatterDistance: nil, unitsHit: [nova]))
        #expect(s.units.first { $0.id == nova }!.armorDamage == 2)
        #expect(s.boxRules!.support[.lanceA]!.available.isEmpty)
    }

    @Test("Template support: every base touched, friend or foe; a miss needs the scatter dice (pp. 29–30)")
    func template() throws {
        var s = session()
        s = try BoxRulesReducer.reduce(s, .setSupportPicks(side: .lanceB, picks: [.sniper]))
        s.phase = .combat
        let pick = s.boxRules!.support[.lanceB]!.picks[0].id
        let hit = [id(s, "Atlas"), id(s, "Nova")]
        #expect(throws: MatchDomainError.self) {
            try BoxRulesReducer.reduce(s, .useSupport(side: .lanceB, pickId: pick, roll: DiceRoll2D6(die1: 1, die2: 1),
                                                      scatterDirection: nil, scatterDistance: nil, unitsHit: hit))
        }
        s = try BoxRulesReducer.reduce(s, .useSupport(side: .lanceB, pickId: pick, roll: DiceRoll2D6(die1: 1, die2: 1),
                                                      scatterDirection: 3, scatterDistance: 4, unitsHit: hit))
        #expect(s.units.filter { hit.contains($0.id) }.allSatisfy { $0.armorDamage == 2 })
        #expect(s.eventLog.last!.message.contains("8″"))
    }

    @Test("Support is declared in the Combat Phase (p. 29)")
    func supportPhase() throws {
        var s = session()
        s = try BoxRulesReducer.reduce(s, .setSupportPicks(side: .lanceA, picks: [.thumper]))
        let pick = s.boxRules!.support[.lanceA]!.picks[0].id
        #expect(throws: MatchDomainError.self) {
            try BoxRulesReducer.reduce(s, .useSupport(side: .lanceA, pickId: pick, roll: DiceRoll2D6(die1: 6, die2: 6),
                                                      scatterDirection: nil, scatterDistance: nil, unitsHit: []))
        }
    }

    @Test("Combat Intuition: two Command Lance 'Mechs, never the Atlas (p. 32)")
    func designate() throws {
        let s = session()
        #expect(throws: MatchDomainError.self) {
            try BoxRulesReducer.reduce(s, .designateCombatIntuition(formationId: "cmd", unitIds: [id(s, "Atlas"), id(s, "Archer")]))
        }
        let next = try BoxRulesReducer.reduce(s, .designateCombatIntuition(formationId: "cmd", unitIds: [id(s, "Archer"), id(s, "Blackjack")]))
        #expect(next.boxRules!.formation("cmd")!.combatIntuitionIds.count == 2)
    }

    @Test("Initiative reroll once per turn while the Atlas stands; the new roll stands (p. 32)")
    func reroll() throws {
        var s = session()
        s = try MatchReducer.reduce(s, .setInitiative(InitiativeRolls(lanceA: DiceRoll2D6(die1: 1, die2: 2), lanceB: DiceRoll2D6(die1: 4, die2: 4))))
        #expect(s.initiativeWinner == .lanceB)
        s = try BoxRulesReducer.reduce(s, .rerollInitiative(formationId: "cmd", roll: DiceRoll2D6(die1: 6, die2: 5)))
        #expect(s.initiativeWinner == .lanceA && s.phase == .movement)
        #expect(throws: MatchDomainError.self) {
            try BoxRulesReducer.reduce(s, .rerollInitiative(formationId: "cmd", roll: DiceRoll2D6(die1: 6, die2: 6)))
        }
        // With the Atlas destroyed there is no reroll.
        var t = session()
        t.units[0].combatStatus = .removed
        t = try MatchReducer.reduce(t, .setInitiative(InitiativeRolls(lanceA: DiceRoll2D6(die1: 1, die2: 2), lanceB: DiceRoll2D6(die1: 4, die2: 4))))
        #expect(!FormationRules.canRerollInitiative(t.boxRules!.formation("cmd")!, session: t))
    }

    @Test("A reroll that ties sends both sides back to roll (p. 13 ties)")
    func rerollTie() throws {
        var s = session()
        s = try MatchReducer.reduce(s, .setInitiative(InitiativeRolls(lanceA: DiceRoll2D6(die1: 1, die2: 2), lanceB: DiceRoll2D6(die1: 4, die2: 4))))
        s = try BoxRulesReducer.reduce(s, .rerollInitiative(formationId: "cmd", roll: DiceRoll2D6(die1: 4, die2: 4)))
        #expect(s.phase == .initiative && s.initiativeRolls == nil)
        #expect(!FormationRules.canRerollInitiative(s.boxRules!.formation("cmd")!, session: s))
    }

    @Test("Combat Intuition: after winning Initiative, attack in the Movement Phase; a kill lands at once; every 3 turns (p. 32)")
    func combatIntuition() throws {
        var s = session()
        let archer = id(s, "Archer"), fireTarget = id(s, "Nova")
        s = try BoxRulesReducer.reduce(s, .designateCombatIntuition(formationId: "cmd", unitIds: [archer, id(s, "Blackjack")]))
        s = try MatchReducer.reduce(s, .setInitiative(InitiativeRolls(lanceA: DiceRoll2D6(die1: 6, die2: 6), lanceB: DiceRoll2D6(die1: 1, die2: 1))))
        let nova = s.units.firstIndex { $0.id == fireTarget }!
        s.units[nova].armorDamage = 4
        s.units[nova].structureDamage = 1
        let a = s.units.firstIndex { $0.id == archer }!
        s.units[a].hasMovedThisTurn = true
        s.units[a].movementMode = .ground
        let shot = SATORAttackCommand(attackerId: archer, defenderId: fireTarget, range: .medium,
                                      roll: DiceRoll2D6(die1: 6, die2: 5), targetMove: .groundUsesTMM)
        s = try BoxRulesReducer.reduce(s, .combatIntuitionAttack(formationId: "cmd", attack: shot))
        #expect(s.phase == .movement)
        #expect(s.units[nova].combatStatus == .removed)
        #expect(s.units[a].hasAttackedThisTurn)
        let cmd = s.boxRules!.formation("cmd")!
        #expect(!FormationRules.combatIntuitionReady(cmd, unitId: archer, turn: 3))
        #expect(FormationRules.combatIntuitionReady(cmd, unitId: archer, turn: 4))
    }

    @Test("Combat Intuition needs the Initiative win and a recorded move (p. 32)")
    func combatIntuitionGates() throws {
        var s = session()
        let archer = id(s, "Archer")
        s = try BoxRulesReducer.reduce(s, .designateCombatIntuition(formationId: "cmd", unitIds: [archer, id(s, "Blackjack")]))
        s = try MatchReducer.reduce(s, .setInitiative(InitiativeRolls(lanceA: DiceRoll2D6(die1: 1, die2: 1), lanceB: DiceRoll2D6(die1: 6, die2: 6))))
        let cmd = s.boxRules!.formation("cmd")!
        let unit = s.units.first { $0.id == archer }!
        #expect(FormationRules.combatIntuitionBlockReason(cmd, unit: unit, session: s) != nil)
    }

    @Test("Lucky: seven uses shared by the Battle Star, only its own 'Mechs, gone below three 'Mechs (pp. 32, 37)")
    func lucky() throws {
        var s = session()
        let wolf = id(s, "Timber Wolf")
        s = try BoxRulesReducer.reduce(s, .useLucky(formationId: "star", unitId: wolf))
        #expect(s.boxRules!.formation("star")!.luckyUsesLeft == 6)
        #expect(throws: MatchDomainError.self) {
            try BoxRulesReducer.reduce(s, .useLucky(formationId: "star", unitId: id(s, "Atlas")))
        }
        s.units[s.units.firstIndex { $0.name == "Nova" }!].combatStatus = .removed
        #expect(throws: MatchDomainError.self) {
            try BoxRulesReducer.reduce(s, .useLucky(formationId: "star", unitId: wolf))
        }
    }

    @Test("Maneuvering Ace: woods cost 1″ less per inch (p. 32); level change is +1″ per inch (p. 15)")
    func maneuveringAce() {
        #expect(MovementCost.total(inches: 4, terrain: .woods) == 8)
        #expect(MovementCost.total(inches: 4, terrain: .woods, maneuveringAce: true) == 4)
        #expect(MovementCost.total(inches: 3, terrain: .clear, levelChange: 2) == 7) // +2″ per inch, table (D27)
    }

    @Test("Attacking a building damages its CF; CF 0 collapses it to rubble (p. 28)")
    func buildingAttack() throws {
        var s = session()
        s.phase = .combat
        let wolf = id(s, "Timber Wolf")
        s = try BoxRulesReducer.reduce(s, .attackBuilding(buildingId: "L1", attackerId: wolf, bracket: .short,
                                                          roll: DiceRoll2D6(die1: 3, die2: 3), attackerMove: .standstill))
        #expect(s.boxRules!.building("L1")!.cf == 9)
        #expect(s.units.first { $0.id == wolf }!.hasAttackedThisTurn)
        s = try BoxRulesReducer.reduce(s, .damageBuilding(buildingId: "L1", amount: 9))
        #expect(s.boxRules!.building("L1")!.collapsed)
    }

    @Test("Collapse damages 'Mechs inside and on the roof (+1) (p. 28)")
    func collapseDamage() throws {
        var s = session()
        let atlas = id(s, "Atlas"), nova = id(s, "Nova")
        s = try BoxRulesReducer.reduce(s, .collapseBuilding(buildingId: "L1", inside: [atlas], onRoof: [nova], minimalDice: [:]))
        #expect(s.units.first { $0.id == atlas }!.armorDamage == 2)
        #expect(s.units.first { $0.id == nova }!.armorDamage == 3)
        #expect(s.boxRules!.building("L1")!.collapsed)
    }

    @Test("Swap sides moves each side's support with it; saves round-trip")
    func swapAndCodable() throws {
        var s = session()
        s = try BoxRulesReducer.reduce(s, .setSupportPicks(side: .lanceA, picks: [.thumper]))
        let swapped = try MatchReducer.reduce(s, .swapSides)
        #expect(swapped.boxRules!.support[.lanceB]!.picks.map(\.type) == [.thumper])
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(MatchSession.self, from: data).boxRules == s.boxRules)
    }
}
