import Foundation
import Testing
import MechBuddyDomain

/// Fixes from the 2026-11-24 rulebook audit (Alpha Strike Box Set Quick-Start Rulebook, 3rd printing).
@Suite("Rulebook audit")
struct RulebookAuditTests {
    private func unit(
        _ name: String,
        side: SideId,
        mv: String = "10\"",
        tmm: Int = 2,
        dmg: (Int, Int, Int) = (2, 2, 1),
        armor: Int = 4,
        structure: Int = 4,
        abilities: String = ""
    ) -> MatchUnitState {
        MatchUnitState(
            name: name, side: side, pv: 20, sz: 2, mv: mv, tmm: tmm,
            s: dmg.0, m: dmg.1, l: dmg.2, ov: 0, armorCap: armor, structureCap: structure, abilities: abilities
        )
    }

    @Test("Weak jump jets: a jumping Shadow Hawk (TMM 2, JMPW1) is +2, not +3 (p. 20)")
    func weakJumpJets() throws {
        var hawk = unit("Shadow Hawk SHD-2H", side: .lanceB, mv: "10\"/6\"j", abilities: "IF0*,JMPW1")
        hawk.movementMode = .jump
        var shooter = unit("Locust LCT-1V", side: .lanceA)
        shooter.movementMode = .ground
        let solve = CombatSolver.solve(
            attacker: shooter, defender: hawk,
            insight: CombatTableInsight(rangeInches: 6, targetMove: .jumpedUsesTMMPlus1),
            overheatAllowed: false
        )
        // Skill 4 + ground 0 + (TMM 2 + 1 jump − 1 JMPW) + short 0 = 6
        #expect(solve.targetNumber?.value == 6)
        var strong = hawk
        strong.abilities = "JMPS2"
        let strongSolve = CombatSolver.solve(
            attacker: shooter, defender: strong,
            insight: CombatTableInsight(rangeInches: 6, targetMove: .jumpedUsesTMMPlus1),
            overheatAllowed: false
        )
        #expect(strongSolve.targetNumber?.value == 9)
    }

    @Test("Natural 12 that reaches structure owes two critical rolls (p. 21-22)")
    func naturalTwelveTwoCrits() {
        let target = unit("Target", side: .lanceB, armor: 1, structure: 4)
        let both = AlphaStrikeDamage.apply(to: target, amount: 2, naturalTwelveHit: true)
        #expect(both.unit.criticalsOwed == 2)
        let armorOnly = AlphaStrikeDamage.apply(to: unit("T", side: .lanceB, armor: 4), amount: 2, naturalTwelveHit: true)
        #expect(armorOnly.unit.criticalsOwed == 1)
        let killed = AlphaStrikeDamage.apply(to: target, amount: 9, naturalTwelveHit: true)
        #expect(killed.unit.criticalsOwed == 0)
    }

    @Test("A weapon hit on a 'Mech with no damage left does 1 damage instead, with no new crit (p. 23)")
    func weaponHitFallsBackToDamage() {
        var target = unit("Locust", side: .lanceB, dmg: (1, 1, 0), armor: 0, structure: 2)
        target.crits.weaponHits = 1
        target.criticalsOwed = 1
        let result = AlphaStrikeCriticals.apply(to: target, roll: DiceRoll2D6(die1: 3, die2: 3)) // 6 weapon
        #expect(result.unit.crits.weaponHits == 1)
        #expect(result.unit.remainingStructure == 1)
        #expect(result.unit.criticalsOwed == 0)
    }

    @Test("CASE turns an ammo hit into 1 damage; ENE ignores it; none destroys (p. 23)")
    func ammoProtection() {
        let roll = DiceRoll2D6(die1: 1, die2: 1)
        let withCase = AlphaStrikeCriticals.apply(to: unit("A", side: .lanceB, abilities: "CASE"), roll: roll).unit
        #expect(withCase.combatStatus == .active)
        #expect(withCase.remainingArmor == 3)
        let withENE = AlphaStrikeCriticals.apply(to: unit("B", side: .lanceB, abilities: "ENE"), roll: roll).unit
        #expect(withENE.remainingArmor == 4)
        #expect(withENE.combatStatus == .active)
        let bare = AlphaStrikeCriticals.apply(to: unit("C", side: .lanceB), roll: roll).unit
        #expect(bare.combatStatus == .destroyedPendingEnd)
    }

    @Test("No shot at a range where the card does no damage (p. 20)")
    func noDamageNoShot() {
        let shooter = unit("Commando", side: .lanceA, dmg: (2, 2, 0))
        let solve = CombatSolver.solve(
            attacker: shooter, defender: unit("T", side: .lanceB),
            insight: CombatTableInsight(rangeInches: 30), overheatAllowed: false
        )
        #expect(solve.cannotShootReason?.contains("no damage at long range") == true)
        #expect(!solve.canApply)
    }

    @Test("Bases touching blocks weapon shots (p. 20)")
    func basesTouching() {
        var insight = CombatTableInsight(rangeInches: 1)
        insight.basesTouching = true
        let solve = CombatSolver.solve(
            attacker: unit("A", side: .lanceA), defender: unit("B", side: .lanceB),
            insight: insight, overheatAllowed: false
        )
        #expect(solve.cannotShootReason != nil)
    }

    @Test("Uneven numbers move in proportion (p. 14 example: 8 vs 5)")
    func proportionalMovement() {
        let a = (0..<8).map { unit("A\($0)", side: .lanceA) }
        let b = (0..<5).map { unit("B\($0)", side: .lanceB) }
        // Side A won initiative, so Side B moves first.
        let sequence = AlphaStrikePhaseEngine.movementSequence(firstToMove: .lanceB, units: a + b)
        #expect(sequence.count == 13)
        #expect(Array(sequence.prefix(7)) == [.lanceB, .lanceA, .lanceB, .lanceA, .lanceB, .lanceA, .lanceA])

        // 2 vs 1 with the larger side moving first: A, A, B.
        let two = [unit("A0", side: .lanceA), unit("A1", side: .lanceA), unit("B0", side: .lanceB)]
        #expect(AlphaStrikePhaseEngine.movementSequence(firstToMove: .lanceA, units: two) == [.lanceA, .lanceA, .lanceB])
    }
}
