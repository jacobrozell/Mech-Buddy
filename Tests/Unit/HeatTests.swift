import Foundation
import Testing
import MechBuddyDomain

/// Alpha Strike quick-start rules: Heat, Shutdown, Overheating, Cooling Down (p. 24), Engine Hit (p. 23).
@Suite("Heat and overheat")
struct HeatTests {
    private func catapult(heat: Int = 0) -> MatchUnitState {
        MatchUnitState(
            name: "Catapult CPLT-C1", side: .lanceA, pv: 32, sz: 3, mv: "8\"j", tmm: 1,
            s: 2, m: 3, l: 2, ov: 1, armorCap: 5, structureCap: 5, heat: heat, abilities: "IF1,LRM1/1/1"
        )
    }

    private func thunderbolt() -> MatchUnitState {
        MatchUnitState(
            name: "Thunderbolt TDR-5S", side: .lanceB, pv: 36, sz: 3, mv: "8\"", tmm: 1,
            s: 3, m: 3, l: 1, ov: 1, armorCap: 7, structureCap: 5, abilities: "IF1"
        )
    }

    @Test("Overheat is legal only at short and medium, up to the card's OV, when the mission allows it")
    func usableOverheat() {
        let unit = catapult()
        #expect(AlphaStrikeHeat.usableOverheat(requested: 3, attacker: unit, bracket: .short, overheatAllowed: true) == 1)
        #expect(AlphaStrikeHeat.usableOverheat(requested: 1, attacker: unit, bracket: .medium, overheatAllowed: true) == 1)
        #expect(AlphaStrikeHeat.usableOverheat(requested: 1, attacker: unit, bracket: .long, overheatAllowed: true) == 0)
        #expect(AlphaStrikeHeat.usableOverheat(requested: 1, attacker: unit, bracket: .short, overheatAllowed: false) == 0)
        var ovl = unit
        ovl.abilities = "OVL"
        #expect(AlphaStrikeHeat.usableOverheat(requested: 1, attacker: ovl, bracket: .long, overheatAllowed: true) == 1)
    }

    @Test("Overheat adds damage now and heat in the End Phase, hit or miss")
    func overheatHeatLandsAtEnd() throws {
        for roll in [DiceRoll2D6(die1: 6, die2: 6), DiceRoll2D6(die1: 1, die2: 1)] {
            var session = combat([catapult(), thunderbolt()])
            let a = session.units[0], d = session.units[1]
            session = try MatchReducer.reduce(session, .resolveSATOR(SATORAttackCommand(
                attackerId: a.id, defenderId: d.id, range: .medium, roll: roll,
                attackerMove: .ground, targetMove: .standstill, overheatUsed: 1
            )))
            #expect(session.units[0].heat == 0)
            #expect(session.units[0].overheatThisTurn == 1)
            if roll.total == 12 {
                #expect(session.units[0].turnShot?.damage == 4) // M 3 + OV 1
            }
            session.phase = .end
            session = try MatchReducer.reduce(session, .resolveEndPhase)
            #expect(session.units[0].heat == 1)
            #expect(session.units[0].overheatThisTurn == 0)
        }
    }

    @Test("Overheat is ignored when the mission keeps it off")
    func overheatOffInRidgeLine() throws {
        var session = combat([catapult(), thunderbolt()], overheatAllowed: false)
        let a = session.units[0], d = session.units[1]
        session = try MatchReducer.reduce(session, .resolveSATOR(SATORAttackCommand(
            attackerId: a.id, defenderId: d.id, range: .short, roll: DiceRoll2D6(die1: 6, die2: 6),
            attackerMove: .ground, targetMove: .standstill, overheatUsed: 1
        )))
        #expect(session.units[0].turnShot?.damage == 2)
        #expect(session.units[0].overheatThisTurn == 0)
    }

    @Test("Heat stays while the 'Mech keeps firing and clears on a turn it doesn't")
    func coolingDown() {
        var unit = catapult(heat: 2)
        unit.hasAttackedThisTurn = true
        unit.overheatThisTurn = 1
        #expect(AlphaStrikeHeat.endPhase(&unit) == .rose(to: 3))
        #expect(unit.heat == 3)

        unit.hasAttackedThisTurn = true
        #expect(AlphaStrikeHeat.endPhase(&unit) == nil)
        #expect(unit.heat == 3)

        unit.hasAttackedThisTurn = false
        #expect(AlphaStrikeHeat.endPhase(&unit) == .cooled)
        #expect(unit.heat == 0)
    }

    @Test("Heat 4 shuts down for a turn, then restarts at 0")
    func shutdownAndRestart() {
        var unit = catapult(heat: 3)
        unit.hasAttackedThisTurn = true
        unit.overheatThisTurn = 1
        #expect(AlphaStrikeHeat.endPhase(&unit) == .shutDown)
        #expect(unit.isShutdown)
        #expect(unit.isImmobile)
        #expect(!unit.canAttackThisTurn)
        #expect(unit.legalMovementModes == [.standstill])

        unit.hasAttackedThisTurn = false
        #expect(AlphaStrikeHeat.endPhase(&unit) == .restarted)
        #expect(unit.heat == 0)
        #expect(!unit.isShutdown)
    }

    @Test("Heat never passes 4")
    func heatCap() {
        var unit = catapult(heat: 3)
        unit.ov = 2
        unit.hasAttackedThisTurn = true
        unit.overheatThisTurn = 2
        unit.crits.engineHits = 1
        _ = AlphaStrikeHeat.endPhase(&unit)
        #expect(unit.heat == 4)
    }

    @Test("Heat costs 2 inches of ground move per level and 1 TMM from heat 2, not jumping")
    func heatMovement() {
        #expect(catapult(heat: 1).effectiveMV == "6\"/8\"j")
        #expect(catapult(heat: 1).effectiveTMM == 1)
        #expect(catapult(heat: 2).effectiveMV == "4\"/8\"j")
        #expect(catapult(heat: 2).effectiveTMM == 0)
        var hawk = catapult(heat: 1)
        hawk.mv = "10\"/6\"j"
        #expect(hawk.effectiveMV == "8\"/6\"j")
        var walker = thunderbolt()
        walker.heat = 3
        #expect(walker.effectiveMV == "2\"")
        #expect(!walker.isImmobile)
        #expect(catapult(heat: 0).effectiveMV == "8\"j")
    }

    @Test("Heat adds to the shooter's number; heat 2 target is easier to hit unless it jumped")
    func heatInSATOR() throws {
        var shooter = catapult(heat: 2)
        shooter.movementMode = .ground
        var target = thunderbolt()
        target.heat = 2
        target.movementMode = .ground
        let insight = CombatTableInsight(rangeInches: 6, targetMove: .groundUsesTMM)
        let walked = CombatSolver.solve(attacker: shooter, defender: target, insight: insight, overheatAllowed: true)
        // Skill 4 + ground 0 + TMM (1 − 1 heat) + heat 2 + short 0 = 6
        #expect(walked.targetNumber?.value == 6)
        let jumped = CombatSolver.solve(
            attacker: shooter, defender: target,
            insight: CombatTableInsight(rangeInches: 6, targetMove: .jumpedUsesTMMPlus1),
            overheatAllowed: true
        )
        // TMM 1 + 1 for jumping, no heat cut
        #expect(jumped.targetNumber?.value == 8)
    }

    @Test("A shut-down 'Mech can't shoot and is an immobile target")
    func shutDownInCombat() {
        let down = catapult(heat: 4)
        let solve = CombatSolver.solve(
            attacker: down, defender: thunderbolt(),
            insight: CombatTableInsight(rangeInches: 6), overheatAllowed: true
        )
        #expect(solve.cannotShootReason?.contains("shut down") == true)
        #expect(down.isImmobile)
    }

    @Test("Overheat survives a save and reload")
    func codable() throws {
        var unit = catapult(heat: 2)
        unit.overheatThisTurn = 1
        let decoded = try JSONDecoder().decode(MatchUnitState.self, from: JSONEncoder().encode(unit))
        #expect(decoded.overheatThisTurn == 1)
        #expect(decoded.heat == 2)
    }

    private func combat(_ units: [MatchUnitState], overheatAllowed: Bool = true) -> MatchSession {
        var ruleset = ScenarioRuleset.ridgeLine
        ruleset.overheatAllowed = overheatAllowed
        return MatchSession(
            ruleset: ruleset,
            phase: .combat,
            activeSide: .lanceA,
            units: units,
            status: .active,
            tableReady: true,
            forcesLoaded: true
        )
    }
}
