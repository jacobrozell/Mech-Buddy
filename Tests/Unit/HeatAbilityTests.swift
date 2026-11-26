// HT#/#/# heat attacks (Alpha Strike Quick-Start p. 24–25), Point Value by skill (p. 35),
// and OmniMech configuration names matching box minis.
import Foundation
import Testing
import MechBuddyDomain
import MechBuddyData

@Suite("Heat attacks (HT)")
struct HeatAbilityTests {
    private func pouncer() -> MatchUnitState {
        MatchUnitState(
            name: "Pouncer T", side: .lanceA, pv: 35, sz: 2, mv: "12\"/10\"j", tmm: 2,
            s: 3, m: 3, l: 0, ov: 0, armorCap: 4, structureCap: 2, abilities: "ENE, HT1/1/-, OMNI"
        )
    }

    private func atlas() -> MatchUnitState {
        MatchUnitState(
            name: "Atlas AS7-S4", side: .lanceB, pv: 55, sz: 4, mv: "6\"", tmm: 1,
            s: 4, m: 4, l: 4, ov: 1, armorCap: 10, structureCap: 8, abilities: "CASEII, ECM, STL"
        )
    }

    private func combat(_ units: [MatchUnitState]) -> MatchSession {
        var ruleset = ScenarioRuleset.ridgeLine
        ruleset.overheatAllowed = true
        return MatchSession(
            ruleset: ruleset, phase: .combat, activeSide: .lanceA, units: units,
            status: .active, tableReady: true, forcesLoaded: true
        )
    }

    private func shoot(_ session: MatchSession, range: RangeBracket, roll: DiceRoll2D6) throws -> MatchSession {
        try MatchReducer.reduce(session, .resolveSATOR(SATORAttackCommand(
            attackerId: session.units[0].id, defenderId: session.units[1].id, range: range, roll: roll,
            attackerMove: .ground, targetMove: .standstill, overheatUsed: 0
        )))
    }

    @Test("HT values by range: 1 short, 1 medium, none long; none without HT")
    func values() {
        #expect(pouncer().heatAbility(at: .short) == 1)
        #expect(pouncer().heatAbility(at: .medium) == 1)
        #expect(pouncer().heatAbility(at: .long) == 0)
        #expect(atlas().heatAbility(at: .short) == 0)
    }

    @Test("A hit adds heat in the End Phase, even to a target that didn't fire")
    func hitAddsHeat() throws {
        var session = try shoot(combat([pouncer(), atlas()]), range: .short, roll: DiceRoll2D6(die1: 6, die2: 6))
        #expect(session.units[1].incomingHeatThisTurn == 1)
        #expect(session.units[1].heat == 0)
        session.phase = .end
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.units[1].heat == 1)
        #expect(session.units[1].incomingHeatThisTurn == 0)
    }

    @Test("A miss adds no heat")
    func missAddsNone() throws {
        let session = try shoot(combat([pouncer(), atlas()]), range: .short, roll: DiceRoll2D6(die1: 1, die2: 1))
        #expect(session.units[1].incomingHeatThisTurn == 0)
    }

    @Test("At most 2 heat a turn from HT; it lands after the target cools")
    func capAndOrder() {
        var unit = atlas()
        unit.heat = 3
        unit.incomingHeatThisTurn = 5
        // Didn't fire: cooling clears its 3 heat, then the HT heat lands, capped at 2.
        _ = AlphaStrikeHeat.endPhase(&unit)
        #expect(unit.heat == 2)
    }

    @Test("Saved matches without HT heat still load")
    func legacyDecode() throws {
        let data = try JSONEncoder().encode(atlas())
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["incomingHeatThisTurn"] = nil
        let decoded = try JSONDecoder().decode(MatchUnitState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.incomingHeatThisTurn == 0)
    }
}

@Suite("Point Value by skill")
struct PointValueTests {
    @Test("Improved Skill PV Increase Table bands (p. 35)")
    func table() {
        let bands: [(Int, Int)] = [(5, 1), (7, 1), (8, 2), (12, 2), (13, 3), (27, 5), (31, 6), (42, 8), (52, 10), (53, 11), (57, 11), (58, 12)]
        for (base, increase) in bands {
            #expect(AlphaStrikePointValue.increasePerSkillPoint(base: base) == increase, "\(base)")
        }
    }

    @Test("The book's example: 39 PV at Skill 2 costs 55; Skill 4 and worse keep the card's PV")
    func adjusted() {
        #expect(AlphaStrikePointValue.adjusted(base: 39, skill: 2) == 55)
        #expect(AlphaStrikePointValue.adjusted(base: 39, skill: 4) == 39)
        #expect(AlphaStrikePointValue.adjusted(base: 39, skill: 5) == 39)
    }
}

@Suite("OmniMech names")
struct OmniNameTests {
    @Test("Configuration letters and Prime drop; Mk II and model codes behave as before")
    func chassis() {
        #expect(UnitChassis.name("Nova T") == "Nova")
        #expect(UnitChassis.name("Fire Moth G") == "Fire Moth")
        #expect(UnitChassis.name("Timber Wolf Prime") == "Timber Wolf")
        #expect(UnitChassis.name("Mad Cat Mk II") == "Mad Cat Mk II")
        #expect(UnitChassis.name("Locust LCT-1V") == "Locust")
        #expect(UnitChassis.name("Atlas") == "Atlas")
        #expect(UnitChassis.matches("Pouncer T", "Pouncer"))
    }
}
