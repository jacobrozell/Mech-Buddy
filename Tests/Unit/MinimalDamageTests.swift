import Foundation
import Testing
import MechBuddyDomain
import MechBuddyData

/// Quick-Start Rulebook 3rd printing: "0*" on a card (p. 4), Minimal Damage (p. 21), Weapon Hit (p. 23).
@Suite("Minimal damage (0*)")
struct MinimalDamageTests {
    /// Short 0*, medium 1, long plain 0 (a dash).
    private func attacker(minimal: MinimalDamageBands = MinimalDamageBands(short: true), s: Int = 0, m: Int = 1) -> MatchUnitState {
        MatchUnitState(
            name: "Probe", side: .lanceA, pv: 10, sz: 1, mv: "8\"", tmm: 1,
            s: s, m: m, l: 0, ov: 0, armorCap: 3, structureCap: 3, minimalDamage: minimal
        )
    }

    private func target() -> MatchUnitState {
        MatchUnitState(name: "Target", side: .lanceB, pv: 10, sz: 1, mv: "8\"", tmm: 0, s: 1, m: 1, l: 1, ov: 0, armorCap: 3, structureCap: 3)
    }

    private func session(_ a: MatchUnitState, _ d: MatchUnitState) -> MatchSession {
        MatchSession(ruleset: .ridgeLine, phase: .combat, activeSide: .lanceA, units: [a, d], status: .active, tableReady: true, forcesLoaded: true)
    }

    private func shoot(_ s: MatchSession, range: RangeBracket = .short, roll: DiceRoll2D6 = DiceRoll2D6(die1: 6, die2: 6), die: Int?) throws -> MatchSession {
        try MatchReducer.reduce(s, .resolveSATOR(SATORAttackCommand(
            attackerId: s.units[0].id, defenderId: s.units[1].id, range: range, roll: roll,
            attackerMove: .ground, targetMove: .standstill, minimalDie: die
        )))
    }

    @Test("Printed values: 0* parses as minimal, a dash or 0 as plain 0 (p. 4)")
    func parse() {
        #expect(MinimalDamage.parse("0*")?.minimal == true)
        #expect(MinimalDamage.parse("0")?.minimal == false)
        #expect(MinimalDamage.parse("—")?.value == 0)
        #expect(MinimalDamage.parse("3")?.value == 3)
        #expect(MinimalDamage.parse("x") == nil)
    }

    @Test("The die: 4, 5, 6 deal 1; 1, 2, 3 deal nothing (p. 21)")
    func die() {
        #expect((1...6).map(MinimalDamage.damage(forDie:)) == [0, 0, 0, 1, 1, 1])
        #expect(!MinimalDamage.isValid(die: 0) && !MinimalDamage.isValid(die: 7))
    }

    @Test("A 0* band allows the shot; a plain 0 still has none")
    func shotAllowed() {
        let a = attacker()
        #expect(CombatSolver.noDamageReason(attacker: a, bracket: .short) == nil)
        #expect(CombatSolver.noDamageReason(attacker: a, bracket: .long) != nil)
        let plain = attacker(minimal: .none)
        #expect(CombatSolver.noDamageReason(attacker: plain, bracket: .short) != nil)
    }

    @Test("The solver flags a minimal hit and prices it at 0 until the die is rolled")
    func solverFlag() {
        let solve = CombatSolver.solve(
            attacker: attacker(), defender: target(),
            insight: CombatTableInsight(rangeInches: 3, targetMove: .standstill), overheatAllowed: false
        )
        #expect(solve.cannotShootReason == nil)
        #expect(solve.needsMinimalRoll)
        #expect(solve.ifHit.delivered == 0)
        #expect(!solve.ifHit.zeroDamage)
        let medium = CombatSolver.solve(
            attacker: attacker(), defender: target(),
            insight: CombatTableInsight(rangeInches: 12, targetMove: .standstill), overheatAllowed: false
        )
        #expect(!medium.needsMinimalRoll)
    }

    @Test("Overheat points are ordinary damage, so that shot is not minimal")
    func overheatNotMinimal() {
        var a = attacker()
        a.ov = 1
        #expect(CombatSolver.isMinimalAttack(attacker: a, bracket: .short, overheatUsed: 0))
        #expect(!CombatSolver.isMinimalAttack(attacker: a, bracket: .short, overheatUsed: 1))
    }

    @Test("Hit with die 4+: 1 damage to armor")
    func hitDeals1() throws {
        let s = try shoot(session(attacker(), target()), die: 4)
        #expect(s.units[1].armorDamage == 1)
        #expect(s.units[0].turnShot?.damage == 1)
        #expect(s.eventLog.last?.message.contains("hit Target for 1") == true)
    }

    @Test("Hit with die 1-3: hit, no damage, and no critical even on a natural 12 (p. 21)")
    func hitDeals0NoCrit() throws {
        let s = try shoot(session(attacker(), target()), roll: DiceRoll2D6(die1: 6, die2: 6), die: 3)
        #expect(s.units[1].armorDamage == 0 && s.units[1].structureDamage == 0)
        #expect(s.units[1].criticalsOwed == 0)
        #expect(s.units[0].turnShot?.hit == true)
        #expect(s.units[0].turnShot?.damage == 0)
    }

    @Test("A natural 12 with a successful minimal die still owes its critical")
    func twelveCrit() throws {
        let s = try shoot(session(attacker(), target()), roll: DiceRoll2D6(die1: 6, die2: 6), die: 6)
        #expect(s.units[1].criticalsOwed == 1)
    }

    @Test("A hit with no die is refused; a miss needs none")
    func dieRequired() throws {
        let base = session(attacker(), target())
        #expect(throws: MatchDomainError.self) { try shoot(base, die: nil) }
        #expect(throws: MatchDomainError.self) { try shoot(base, die: 9) }
        let miss = try shoot(base, roll: DiceRoll2D6(die1: 1, die2: 1), die: nil)
        #expect(miss.units[0].turnShot?.hit == false)
    }

    @Test("Weapon Hit: a printed 0* stays 0*; a printed 1 reduced to 0 is a plain 0 (p. 23)")
    func weaponHit() {
        var a = attacker(minimal: MinimalDamageBands(short: true, medium: true))
        a.crits.weaponHits = 1
        #expect(a.hasMinimalDamage(at: .short))
        #expect(CombatSolver.noDamageReason(attacker: a, bracket: .short) == nil)
        // Medium printed 1, minimal flag stale: not a 0*, so a weapon hit leaves no shot.
        #expect(!a.hasMinimalDamage(at: .medium))
        #expect(CombatSolver.noDamageReason(attacker: a, bracket: .medium) != nil)
    }

    @Test("Card JSON: numbers decode as before, \"0*\" sets the band flag, and it round-trips")
    func dtoDecoding() throws {
        let json = #"""
        {"name":"X","pv":10,"mv":"8\"","tmm":1,"sz":1,"s":"0*","m":2,"l":"0*","ov":0,"armor":3,"structure":3,"skill":4,"abilities":""}
        """#
        let dto = try JSONDecoder().decode(ScenarioUnitDTO.self, from: Data(json.utf8))
        #expect(dto.s == 0 && dto.m == 2 && dto.l == 0)
        #expect(dto.minimalDamage == MinimalDamageBands(short: true, medium: false, long: true))
        let scenarioJSON = #"""
        {"schemaVersion":1,"contentVersion":"t","scenarioId":"t","title":"T","tableSteps":[],
         "ruleset":{"overheatAllowed":false,"physicalAttacksAllowed":false,"forcedWithdrawal":false,"victory":{"type":"destroyAllEnemies"}},
         "sides":{"lanceA":[\#(json)],"lanceB":[]}}
        """#
        let scenario = try JSONDecoder().decode(GuidedScenarioDTO.self, from: Data(scenarioJSON.utf8))
        let unit = GuidedScenarioFactory.makeUnits(from: scenario).first
        #expect(unit?.minimalDamage == dto.minimalDamage)
        let again = try JSONDecoder().decode(ScenarioUnitDTO.self, from: JSONEncoder().encode(dto))
        #expect(again.minimalDamage == dto.minimalDamage && again.s == 0)
        let plain = json.replacingOccurrences(of: "\"0*\"", with: "0")
        let old = try JSONDecoder().decode(ScenarioUnitDTO.self, from: Data(plain.utf8))
        #expect(old.minimalDamage.isEmpty)
    }

    @Test("Box roster cards accept 0* too, and missing damage stays nil")
    func boxCard() throws {
        let json = #"{"name":"Y","sz":1,"defaultSide":"lanceA","s":"0*","m":1}"#
        let card = try JSONDecoder().decode(BoxCardDTO.self, from: Data(json.utf8))
        #expect(card.s == 0 && card.m == 1 && card.l == nil)
        #expect(card.minimalDamage == MinimalDamageBands(short: true))
    }

    @Test("Saved matches without the new fields still decode; the fields round-trip")
    func persistence() throws {
        let encoder = JSONEncoder()
        var unit = attacker()
        let legacy = try encoder.encode(unit)
        var object = try #require(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
        #expect(object["minimalDamage"] != nil)
        object.removeValue(forKey: "minimalDamage")
        object.removeValue(forKey: "inWater")
        let old = try JSONDecoder().decode(MatchUnitState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.minimalDamage.isEmpty && !old.inWater)
        unit.inWater = true
        let back = try JSONDecoder().decode(MatchUnitState.self, from: encoder.encode(unit))
        #expect(back.minimalDamage == unit.minimalDamage && back.inWater)
    }
}
