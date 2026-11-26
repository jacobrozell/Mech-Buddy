import Foundation
import Testing
import MechBuddyDomain

/// Quick-Start Rulebook 3rd printing: Water terrain (p. 10), Partial Cover Modifier (p. 19), Cooling Down (p. 24).
@Suite("Water")
struct WaterTests {
    private func mech(_ name: String = "A", side: SideId = .lanceA, heat: Int = 0, inWater: Bool = false) -> MatchUnitState {
        MatchUnitState(
            name: name, side: side, pv: 20, sz: 2, mv: "8\"", tmm: 1,
            s: 2, m: 2, l: 1, ov: 1, armorCap: 4, structureCap: 4, heat: heat, inWater: inWater
        )
    }

    private func targetNumber(inWater: Bool, cover: Bool = false) -> Int {
        let solve = CombatSolver.solve(
            attacker: mech(), defender: mech("B", side: .lanceB, inWater: inWater),
            insight: CombatTableInsight(rangeInches: 3, targetMove: .standstill, partialCover: cover), overheatAllowed: false
        )
        return solve.targetNumber?.value ?? -1
    }

    @Test("A target in water counts partial cover: +1 to the target number (pp. 10, 19)")
    func partialCover() {
        let dry = targetNumber(inWater: false)
        #expect(targetNumber(inWater: true) == dry + 1)
        let solve = CombatSolver.solve(
            attacker: mech(), defender: mech("B", side: .lanceB, inWater: true),
            insight: CombatTableInsight(rangeInches: 3, targetMove: .standstill), overheatAllowed: false
        )
        #expect(solve.targetInWater)
        #expect(solve.targetNumber?.reasons.contains("Partial cover, +1") == true)
    }

    @Test("Water cover does not stack with cover from other terrain")
    func noStacking() {
        #expect(targetNumber(inWater: true, cover: true) == targetNumber(inWater: false, cover: true))
    }

    @Test("The reducer path applies the same cover")
    func reducerCover() throws {
        func needed(_ water: Bool) throws -> Int {
            let s = MatchSession(ruleset: .ridgeLine, phase: .combat, activeSide: .lanceA,
                                 units: [mech(), mech("B", side: .lanceB, inWater: water)], status: .active, tableReady: true, forcesLoaded: true)
            let out = try MatchReducer.reduce(s, .resolveSATOR(SATORAttackCommand(
                attackerId: s.units[0].id, defenderId: s.units[1].id, range: .short,
                roll: DiceRoll2D6(die1: 3, die2: 3), attackerMove: .ground, targetMove: .standstill)))
            return try #require(out.units[0].turnShot?.targetNumber)
        }
        #expect(try needed(true) == needed(false) + 1)
    }

    private func endHeat(start: Int, fired: Bool, overheat: Int = 0, water: Bool, incoming: Int = 0) -> Int {
        var u = mech(heat: start, inWater: water)
        u.hasAttackedThisTurn = fired
        u.overheatThisTurn = overheat
        u.incomingHeatThisTurn = incoming
        _ = AlphaStrikeHeat.endPhase(&u)
        return u.heat
    }

    @Test("End Phase: −1 heat in water after adding overheat, never below 0 (p. 24, step 2)")
    func cooling() {
        #expect(endHeat(start: 1, fired: true, overheat: 1, water: false) == 2)
        #expect(endHeat(start: 1, fired: true, overheat: 1, water: true) == 1)
        #expect(endHeat(start: 0, fired: true, water: true) == 0)
        #expect(endHeat(start: 2, fired: true, water: true) == 1)
    }

    @Test("Step order: water comes before external heat, which lands last (steps 2 and 5)")
    func externalHeatAfterWater() {
        #expect(endHeat(start: 1, fired: true, water: true, incoming: 1) == 1)
        #expect(endHeat(start: 0, fired: true, water: true, incoming: 1) == 1)
    }

    @Test("A ’Mech that did not fire still clears all heat, in water or not")
    func idleClears() {
        #expect(endHeat(start: 3, fired: false, water: true) == 0)
    }

    @Test("Water takes a ’Mech out of shutdown only through the normal restart")
    func shutdownRestarts() {
        var u = mech(heat: 4, inWater: true)
        #expect(AlphaStrikeHeat.endPhase(&u) == .restarted)
        #expect(u.heat == 0)
    }

    @Test("setInWater marks the unit, and the next turn's reset clears it")
    func flagLifecycle() throws {
        var s = MatchSession(ruleset: .ridgeLine, phase: .movement, activeSide: .lanceA,
                             units: [mech(), mech("B", side: .lanceB)], status: .active, tableReady: true, forcesLoaded: true)
        s = try MatchReducer.reduce(s, .setInWater(unitId: s.units[0].id, inWater: true))
        #expect(s.units[0].inWater)
        AlphaStrikePhaseEngine.resetTurnFlags(&s.units)
        #expect(!s.units[0].inWater)
        #expect(throws: MatchDomainError.self) { try MatchReducer.reduce(s, .setInWater(unitId: UUID(), inWater: true)) }
    }
}
