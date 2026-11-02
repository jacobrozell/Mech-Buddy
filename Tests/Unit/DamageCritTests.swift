import Testing
import MechBuddyDomain

@Suite("Damage and crits")
struct DamageCritTests {
    private func freshUnit(armor: Int, structure: Int) -> MatchUnitState {
        MatchUnitState(
            name: "Test",
            side: .lanceA,
            pv: 10,
            sz: 1,
            mv: "10\"",
            tmm: 2,
            s: 2,
            m: 2,
            l: 0,
            ov: 0,
            armorCap: armor,
            structureCap: structure
        )
    }

    @Test("Armor absorbs before structure")
    func armorFirst() {
        let unit = freshUnit(armor: 5, structure: 5)
        let result = AlphaStrikeDamage.apply(to: unit, amount: 3, naturalTwelveHit: false)
        #expect(result.unit.remainingArmor == 2)
        #expect(result.unit.structureDamage == 0)
        #expect(result.needsCritical == false)
    }

    @Test("Structure mark needs critical")
    func structureCrit() {
        let unit = freshUnit(armor: 0, structure: 5)
        let result = AlphaStrikeDamage.apply(to: unit, amount: 2, naturalTwelveHit: false)
        #expect(result.unit.structureDamage == 2)
        #expect(result.needsCritical == true)
    }

    @Test("Natural 12 through armor needs critical")
    func natural12() {
        let unit = freshUnit(armor: 5, structure: 5)
        let result = AlphaStrikeDamage.apply(to: unit, amount: 1, naturalTwelveHit: true)
        #expect(result.needsCritical == true)
        #expect(result.unit.structureDamage == 0)
    }

    @Test("Structure zero → destroyedPendingEnd")
    func destroyedPending() {
        let unit = freshUnit(armor: 0, structure: 2)
        let result = AlphaStrikeDamage.apply(to: unit, amount: 2, naturalTwelveHit: false)
        #expect(result.unit.combatStatus == .destroyedPendingEnd)
        #expect(result.unit.canFire == true)
    }

    @Test("Ammo crit destroys without CASE")
    func ammoDestroys() {
        let unit = freshUnit(armor: 2, structure: 2)
        let roll = DiceRoll2D6(die1: 1, die2: 1) // total 2
        let result = AlphaStrikeCriticals.apply(to: unit, roll: roll)
        #expect(result.resultId == .ammo)
        #expect(result.unit.crits.destroyedByCrit == true)
    }

    @Test("Ammo survives with ENE")
    func ammoENE() {
        var unit = freshUnit(armor: 2, structure: 2)
        unit.abilities = "ENE"
        let roll = DiceRoll2D6(die1: 1, die2: 1)
        let result = AlphaStrikeCriticals.apply(to: unit, roll: roll)
        #expect(result.unit.crits.destroyedByCrit == false)
    }

    @Test("Initiative tie errors")
    func initiativeTie() {
        let rolls = InitiativeRolls(
            lanceA: DiceRoll2D6(die1: 3, die2: 4),
            lanceB: DiceRoll2D6(die1: 5, die2: 2)
        )
        #expect(throws: MatchDomainError.initiativeTied) {
            try AlphaStrikePhaseEngine.resolveInitiative(rolls: rolls)
        }
    }

    @Test("Initiative winner is higher total")
    func initiativeWinner() throws {
        let rolls = InitiativeRolls(
            lanceA: DiceRoll2D6(die1: 6, die2: 6),
            lanceB: DiceRoll2D6(die1: 1, die2: 1)
        )
        let winner = try AlphaStrikePhaseEngine.resolveInitiative(rolls: rolls)
        #expect(winner == .lanceA)
        #expect(AlphaStrikePhaseEngine.initiativeLoser(winner: winner) == .lanceB)
    }

    @Test("MP hit halves TMM and MV display")
    func mpHitHalves() {
        var unit = freshUnit(armor: 2, structure: 2)
        unit.tmm = 2
        unit.mv = "10\""
        let result = AlphaStrikeCriticals.apply(to: unit, roll: DiceRoll2D6(die1: 3, die2: 4)) // 7
        #expect(result.resultId == .mp)
        #expect(result.unit.crits.mpHit)
        #expect(result.unit.effectiveTMM == 1)
        #expect(result.unit.effectiveMV == "5\"")
        var hawk = freshUnit(armor: 2, structure: 2)
        hawk.mv = "10\"/6\"j"
        hawk.crits.mpHit = true
        #expect(hawk.effectiveMV == "5\"/3\"j")
    }

    @Test("Second MP hit immobilizes")
    func secondMPImmobilizes() {
        var unit = freshUnit(armor: 2, structure: 2)
        unit.tmm = 2
        unit.mv = "10\""
        unit.crits.mpHit = true
        let result = AlphaStrikeCriticals.apply(to: unit, roll: DiceRoll2D6(die1: 3, die2: 4))
        #expect(result.unit.tmm == 0)
        #expect(result.unit.mv == "0\"")
    }

    @Test("Overheat clamped to unit OV")
    func overheatClamp() {
        let result = AlphaStrikeDamage.delivered(
            DamageInput(short: 2, medium: 2, long: 0, bracket: .short, overheatUsed: 5, maxOverheat: 1),
            overheatAllowed: true
        )
        #expect(result.delivered == 3)
    }

    @Test("Two hits owe two critical rolls")
    func twoCritsQueue() {
        var unit = freshUnit(armor: 0, structure: 5)
        unit = AlphaStrikeDamage.apply(to: unit, amount: 1, naturalTwelveHit: false).unit
        unit = AlphaStrikeDamage.apply(to: unit, amount: 1, naturalTwelveHit: false).unit
        #expect(unit.criticalsOwed == 2)
        unit = AlphaStrikeCriticals.apply(to: unit, roll: DiceRoll2D6(die1: 2, die2: 3)).unit
        #expect(unit.criticalsOwed == 1)
        #expect(unit.pendingCritical)
    }

    @Test("Heat added to the target number stops at 4")
    func heatCap() throws {
        let tn = try SATORResolver.resolve(
            SATORInput(
                skill: 4,
                attackerMove: .ground,
                targetMove: .standstill,
                targetTMM: 0,
                other: OtherModifiers(attackerHeat: 6),
                rangeBracket: .short
            )
        )
        #expect(tn.value == 8)
    }
}
