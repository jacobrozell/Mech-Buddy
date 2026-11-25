// REAR#/#/# rear-firing weapons (Alpha Strike Quick-Start p. 25).
import Foundation
import Testing
import MechBuddyDomain

@Suite("Rear-firing weapons (REAR)")
struct RearFiringTests {
    /// Archer ARC-7C: 5/5/4, REAR2/2/-.
    private func archer() -> MatchUnitState {
        MatchUnitState(
            name: "Archer ARC-7C", side: .lanceA, pv: 49, sz: 3, mv: "10\"", tmm: 2,
            s: 5, m: 5, l: 4, ov: 0, armorCap: 7, structureCap: 3, abilities: "CASEII, IF2, REAR2/2/-"
        )
    }

    private func target(_ name: String) -> MatchUnitState {
        MatchUnitState(
            name: name, side: .lanceB, pv: 40, sz: 3, mv: "8\"", tmm: 1,
            s: 4, m: 4, l: 2, ov: 1, armorCap: 20, structureCap: 6, abilities: ""
        )
    }

    private func combat() -> MatchSession {
        MatchSession(
            ruleset: .ridgeLine, phase: .combat, activeSide: .lanceA,
            units: [archer(), target("Warhammer WHM-8R"), target("Nova T")],
            status: .active, tableReady: true, forcesLoaded: true
        )
    }

    private func attack(
        _ session: MatchSession, defender: Int, kind: AttackKind, range: RangeBracket = .medium,
        roll: DiceRoll2D6 = DiceRoll2D6(die1: 5, die2: 5)
    ) throws -> MatchSession {
        try MatchReducer.reduce(session, .resolveSATOR(SATORAttackCommand(
            attackerId: session.units[0].id, defenderId: session.units[defender].id, range: range, roll: roll,
            attackerMove: .ground, targetMove: .standstill, overheatUsed: 0, attackKind: kind
        )))
    }

    @Test("REAR values by range")
    func values() {
        #expect(archer().rearDamage(at: .short) == 2)
        #expect(archer().rearDamage(at: .medium) == 2)
        #expect(archer().rearDamage(at: .long) == 0)
        #expect(archer().hasRearFiring)
        #expect(!target("x").hasRearFiring)
    }

    @Test("A rear shot does the REAR damage at +1 to hit, then the forward shot loses that much")
    func rearThenForward() throws {
        var session = try attack(combat(), defender: 2, kind: .rearFiring)
        let rear = try #require(session.units[0].rearShot)
        #expect(rear.damage == 2)
        #expect(session.units[0].rearFireReduction == 2)
        #expect(!session.units[0].hasAttackedThisTurn)
        #expect(session.units[0].canAttackThisTurn)
        #expect(!session.units[0].canRearFireThisTurn)

        session = try attack(session, defender: 1, kind: .weapon)
        #expect(session.units[0].turnShot?.damage == 3) // M 5 − REAR 2
        #expect(session.units[0].madeWeaponAttackThisTurn)
    }

    @Test("The rear shot's to-hit is 1 higher than the same forward shot")
    func plusOne() {
        let archer = archer(), target = target("Nova T")
        var insight = CombatTableInsight(rangeInches: 12, targetMove: .standstill)
        let forward = CombatSolver.solve(attacker: archer, defender: target, insight: insight, overheatAllowed: false)
        insight.attackKind = .rearFiring
        insight.targetInFrontArc = false
        let rear = CombatSolver.solve(attacker: archer, defender: target, insight: insight, overheatAllowed: false)
        #expect(forward.targetNumber != nil)
        #expect(rear.targetNumber?.value == forward.targetNumber.map { $0.value + 1 })
        #expect(rear.ifHit.delivered == 2)
    }

    @Test("No rear shot at a target in front, at a range with no REAR damage, or after the forward shot")
    func limits() throws {
        let archer = archer(), target = target("Nova T")
        var insight = CombatTableInsight(rangeInches: 12, targetMove: .standstill)
        insight.attackKind = .rearFiring
        #expect(CombatSolver.solve(attacker: archer, defender: target, insight: insight, overheatAllowed: false)
            .cannotShootReason != nil) // still "in front"
        insight.targetInFrontArc = false
        insight.rangeInches = 30
        #expect(CombatSolver.solve(attacker: archer, defender: target, insight: insight, overheatAllowed: false)
            .cannotShootReason != nil) // REAR is "-" at long

        let afterForward = try attack(combat(), defender: 1, kind: .weapon)
        #expect(!afterForward.units[0].canRearFireThisTurn)
        #expect(throws: (any Error).self) { try attack(afterForward, defender: 2, kind: .rearFiring) }
    }

    @Test("Rear shots never overheat and clear at the end of the turn")
    func overheatAndReset() throws {
        let start = combat()
        var session = try MatchReducer.reduce(start, .resolveSATOR(SATORAttackCommand(
            attackerId: start.units[0].id, defenderId: start.units[2].id, range: .short,
            roll: DiceRoll2D6(die1: 6, die2: 6), attackerMove: .ground, targetMove: .standstill,
            overheatUsed: 2, attackKind: .rearFiring
        )))
        #expect(session.units[0].overheatThisTurn == 0)
        var units = session.units
        AlphaStrikePhaseEngine.resetTurnFlags(&units)
        session.units = units
        #expect(session.units[0].rearShot == nil && session.units[0].rearFireReduction == 0)
    }
}
