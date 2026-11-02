import Testing
import MechBuddyDomain

@Suite("Victory and edge cases")
struct VictoryEdgeCaseTests {
    private func unit(
        name: String,
        side: SideId,
        structureCap: Int,
        structureDamage: Int = 0,
        status: UnitCombatStatus = .active
    ) -> MatchUnitState {
        MatchUnitState(
            name: name,
            side: side,
            pv: 1,
            sz: 1,
            mv: "10\"",
            tmm: 1,
            s: 1,
            m: 1,
            l: 0,
            ov: 0,
            armorCap: 2,
            structureCap: structureCap,
            structureDamage: structureDamage,
            combatStatus: status
        )
    }

    @Test("Structure victory after max turn prefers higher remaining structure")
    func structureVictory() {
        var session = MatchSession(
            ruleset: .ridgeLine,
            turn: 6,
            phase: .end,
            units: [
                unit(name: "A", side: .lanceA, structureCap: 5, structureDamage: 1),
                unit(name: "B", side: .lanceB, structureCap: 5, structureDamage: 4)
            ],
            tableReady: true,
            forcesLoaded: true
        )
        let outcome = VictoryEvaluator.evaluateAfterEnd(session: session)
        #expect(outcome == .winner(.lanceA))
    }

    @Test("Equal structure after max turn is draw")
    func structureDraw() {
        let session = MatchSession(
            ruleset: .ridgeLine,
            turn: 6,
            phase: .end,
            units: [
                unit(name: "A", side: .lanceA, structureCap: 5, structureDamage: 2),
                unit(name: "B", side: .lanceB, structureCap: 5, structureDamage: 2)
            ],
            tableReady: true,
            forcesLoaded: true
        )
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == .draw)
    }

    @Test("Before max turn, living both sides yields nil")
    func beforeCap() {
        let session = MatchSession(
            ruleset: .ridgeLine,
            turn: 3,
            phase: .end,
            units: [
                unit(name: "A", side: .lanceA, structureCap: 5),
                unit(name: "B", side: .lanceB, structureCap: 5)
            ],
            tableReady: true,
            forcesLoaded: true
        )
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == nil)
    }

    @Test("evaluate() structure path after max turn matches afterEnd helper")
    func evaluateStructurePath() {
        let session = MatchSession(
            ruleset: .ridgeLine,
            turn: 6,
            phase: .end,
            units: [
                unit(name: "A", side: .lanceA, structureCap: 5, structureDamage: 1),
                unit(name: "B", side: .lanceB, structureCap: 5, structureDamage: 4)
            ],
            tableReady: true,
            forcesLoaded: true
        )
        #expect(VictoryEvaluator.evaluate(session: session) == .winner(.lanceA))
        #expect(VictoryEvaluator.evaluate(session: session) == VictoryEvaluator.evaluateAfterEnd(session: session))
    }

    @Test("TN above 12 is auto-miss")
    func autoMiss() throws {
        let tn = try SATORResolver.resolve(
            SATORInput(
                skill: 4,
                attackerMove: .jump,
                targetMove: .jumpedUsesTMMPlus1,
                targetTMM: 3,
                other: OtherModifiers(woods: true, fireControlHits: 2, attackerHeat: 2),
                rangeBracket: .long
            )
        )
        #expect(tn.value > 12)
        #expect(tn.autoMiss)
        #expect(SATORResolver.isHit(tn: tn, roll: DiceRoll2D6(die1: 6, die2: 6)) == false)
    }

    @Test("Delivered damage ignores overheat when ruleset disallows")
    func noOVOnRidgeLine() {
        let result = AlphaStrikeDamage.delivered(
            DamageInput(short: 2, medium: 2, long: 0, bracket: .short, overheatUsed: 2),
            overheatAllowed: false
        )
        #expect(result.delivered == 2)
    }

    @Test("Rear hit adds one")
    func rear() {
        let result = AlphaStrikeDamage.delivered(
            DamageInput(short: 2, medium: 2, long: 0, bracket: .short, rearHit: true),
            overheatAllowed: false
        )
        #expect(result.delivered == 3)
    }
}
