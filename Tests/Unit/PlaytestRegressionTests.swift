import Testing
import MechBuddyDomain

/// Regressions from the 2026-11-19 Ridge Line playtest (ongoing/play-2026-11-19/TRIAGE.md).
@Suite("Playtest 2026-11-19 regressions")
struct PlaytestRegressionTests {
    private func unit(_ name: String, side: SideId, armor: Int, structure: Int) -> MatchUnitState {
        MatchUnitState(
            name: name,
            side: side,
            pv: 18,
            sz: 1,
            mv: "16\"",
            tmm: 3,
            s: 1,
            m: 1,
            l: 0,
            ov: 0,
            armorCap: armor,
            structureCap: structure,
            movementMode: .standstill,
            hasMovedThisTurn: true
        )
    }

    @Test("P0-2: the killing blow owes no critical")
    func noCritOnKillingBlow() {
        let locust = unit("Locust", side: .lanceB, armor: 0, structure: 2)
        let result = AlphaStrikeDamage.apply(to: locust, amount: 2, naturalTwelveHit: false)
        #expect(result.unit.combatStatus == .destroyedPendingEnd)
        #expect(result.needsCritical == false)
        #expect(result.unit.criticalsOwed == 0)
    }

    @Test("P0-2: a natural 12 that wrecks the target owes no critical either")
    func noCritOnKillingNaturalTwelve() {
        let locust = unit("Locust", side: .lanceB, armor: 0, structure: 1)
        let result = AlphaStrikeDamage.apply(to: locust, amount: 2, naturalTwelveHit: true)
        #expect(result.needsCritical == false)
    }

    @Test("P0-2: structure damage that leaves the unit standing still owes a critical")
    func critStillOwedWhenSurviving() {
        let wolverine = unit("Wolverine", side: .lanceB, armor: 0, structure: 5)
        let result = AlphaStrikeDamage.apply(to: wolverine, amount: 2, naturalTwelveHit: false)
        #expect(result.needsCritical == true)
    }

    @Test("P0-1: a fire-control crit taken this phase does not change this phase's return fire")
    func fireControlWaitsForEndPhase() {
        var locust = unit("Locust", side: .lanceB, armor: 0, structure: 2)
        let commando = unit("Commando", side: .lanceA, armor: 0, structure: 1)
        locust.combatPhaseCrits = locust.crits          // snapshot taken when combat began
        locust.crits.fireControlHits = 1                // crit rolled mid-phase

        let insight = CombatTableInsight(rangeInches: 3, targetMove: .standstill)
        let solve = CombatSolver.solve(attacker: locust, defender: commando, insight: insight, overheatAllowed: false)
        // 4 skill − 1 stood still + 0 stood-still target + 0 short = 3, with no +2 fire control.
        #expect(solve.targetNumber?.value == 3)

        locust.combatPhaseCrits = nil                   // next phase: the crit now counts
        let later = CombatSolver.solve(attacker: locust, defender: commando, insight: insight, overheatAllowed: false)
        #expect(later.targetNumber?.value == 5)
    }

    @Test("P0-1: a weapon crit taken this phase does not cut this phase's damage")
    func weaponHitWaitsForEndPhase() {
        var commando = unit("Commando", side: .lanceA, armor: 0, structure: 2)
        commando.s = 2
        commando.combatPhaseCrits = commando.crits
        commando.crits.weaponHits = 1
        #expect(commando.firingDamage.s == 2)
        #expect(commando.effectiveDamage.s == 1)
    }
}
