import Testing
import MechBuddyDomain

@Suite("Combat solver")
struct CombatSolverTests {
    private func hawk() -> MatchUnitState {
        MatchUnitState(
            name: "Shadow Hawk",
            side: .lanceA,
            skill: 4,
            pv: 30,
            sz: 2,
            mv: "10\"",
            tmm: 2,
            s: 2,
            m: 2,
            l: 1,
            ov: 0,
            armorCap: 5,
            structureCap: 5,
            movementMode: .ground
        )
    }

    private func locust() -> MatchUnitState {
        MatchUnitState(
            name: "Locust",
            side: .lanceB,
            skill: 4,
            pv: 18,
            sz: 1,
            mv: "16\"",
            tmm: 3,
            s: 1,
            m: 1,
            l: 0,
            ov: 0,
            armorCap: 2,
            structureCap: 2,
            movementMode: .ground
        )
    }

    @Test("Short-range hit preview chips armor, no crit")
    func shortArmorOnly() {
        let solve = CombatSolver.solve(
            attacker: hawk(),
            defender: locust(),
            insight: CombatTableInsight(rangeInches: 4, targetMove: .standstill),
            overheatAllowed: false
        )
        #expect(solve.targetNumber?.value == 4) // skill 4, standstill T +0, short
        #expect(solve.ifHit.delivered == 2)
        #expect(solve.ifHit.armorAfter == 0)
        #expect(solve.ifHit.structureAfter == 2)
        #expect(solve.ifHit.needsCritical == false)
        #expect(solve.ifHit.wrecksThisTurn == false)
        #expect(solve.canApply)
    }

    @Test("Long range on Locust is 0 damage")
    func longZeroDamage() {
        let solve = CombatSolver.solve(
            attacker: locust(),
            defender: hawk(),
            insight: CombatTableInsight(rangeInches: 30, targetMove: .standstill),
            overheatAllowed: false
        )
        #expect(solve.rangeBracket == .long)
        #expect(solve.ifHit.delivered == 0)
        #expect(solve.ifHit.zeroDamage)
    }

    @Test("Structure mark previews a critical")
    func structureCrit() {
        var target = locust()
        target.armorDamage = 2
        let solve = CombatSolver.solve(
            attacker: hawk(),
            defender: target,
            insight: CombatTableInsight(rangeInches: 5, targetMove: .standstill),
            overheatAllowed: false
        )
        #expect(solve.ifHit.chipsStructure == 2)
        #expect(solve.ifHit.needsCritical)
        #expect(solve.ifHit.wrecksThisTurn)
    }

    @Test("Natural 12 through armor still previews a critical")
    func twelveThroughArmor() {
        let solve = CombatSolver.solve(
            attacker: hawk(),
            defender: locust(),
            insight: CombatTableInsight(rangeInches: 4, targetMove: .standstill),
            overheatAllowed: false,
            roll: DiceRoll2D6(die1: 6, die2: 6)
        )
        #expect(solve.isHit == true)
        #expect(solve.ifNaturalTwelve.needsCritical)
        #expect(solve.ifHit.needsCritical == false)
    }

    @Test("Out of range cannot shoot")
    func tooFar() {
        let solve = CombatSolver.solve(
            attacker: hawk(),
            defender: locust(),
            insight: CombatTableInsight(rangeInches: 50),
            overheatAllowed: false
        )
        #expect(solve.cannotShootReason != nil)
        #expect(solve.canApply == false)
    }

    @Test("A hidden target cannot be shot")
    func hiddenTarget() {
        let solve = CombatSolver.solve(
            attacker: hawk(),
            defender: locust(),
            insight: CombatTableInsight(canSeeTarget: false),
            overheatAllowed: false
        )
        #expect(solve.canApply == false)
    }

    @Test("Sprint cannot shoot")
    func sprint() {
        var attacker = hawk()
        attacker.movementMode = .sprint
        let solve = CombatSolver.solve(
            attacker: attacker,
            defender: locust(),
            insight: CombatTableInsight(),
            overheatAllowed: false
        )
        #expect(solve.cannotShootReason != nil)
    }

    @Test("Miss vs hit from entered dice")
    func diceHitMiss() {
        let insight = CombatTableInsight(rangeInches: 4, targetMove: .standstill)
        let miss = CombatSolver.solve(
            attacker: hawk(),
            defender: locust(),
            insight: insight,
            overheatAllowed: false,
            roll: DiceRoll2D6(die1: 1, die2: 1)
        )
        let hit = CombatSolver.solve(
            attacker: hawk(),
            defender: locust(),
            insight: insight,
            overheatAllowed: false,
            roll: DiceRoll2D6(die1: 3, die2: 3)
        )
        #expect(miss.isHit == false)
        #expect(hit.isHit == true)
    }

    @Test("Rear hit adds one damage")
    func rear() {
        let front = CombatSolver.solve(
            attacker: hawk(),
            defender: locust(),
            insight: CombatTableInsight(rangeInches: 4),
            overheatAllowed: false
        )
        let rear = CombatSolver.solve(
            attacker: hawk(),
            defender: locust(),
            insight: CombatTableInsight(rangeInches: 4, rearHit: true),
            overheatAllowed: false
        )
        #expect(rear.ifHit.delivered == front.ifHit.delivered + 1)
    }

    @Test("Shot preview and applied target number agree for stealth")
    func stealthTargetNumberParity() throws {
        var attacker = locust()
        attacker.side = .lanceA
        attacker.skill = 4
        attacker.movementMode = .standstill
        var defender = hawk()
        defender.side = .lanceB
        defender.abilities = "STL"
        defender.movementMode = .standstill

        let preview = try #require(
            CombatSolver.solve(
                attacker: attacker,
                defender: defender,
                insight: CombatTableInsight(
                    rangeInches: 12,
                    targetMove: .standstill,
                    attackerMoveOverride: .standstill
                ),
                overheatAllowed: false
            ).targetNumber
        )

        let session = try appliedShot(
            attacker: attacker,
            defender: defender,
            range: .medium,
            overheatUsed: 0,
            overheatAllowed: false
        )
        let shot = try #require(session.units.first { $0.id == attacker.id }?.turnShot)
        #expect(shot.targetNumber == preview.value)
    }

    @Test("Shot preview and applied damage agree for OVL overheat")
    func ovlDamageParity() throws {
        var attacker = hawk()
        attacker.abilities = "OVL"
        attacker.ov = 2
        attacker.l = 1
        attacker.movementMode = .standstill
        var defender = locust()
        defender.movementMode = .standstill

        let preview = CombatSolver.solve(
            attacker: attacker,
            defender: defender,
            insight: CombatTableInsight(
                rangeInches: 30,
                targetMove: .standstill,
                overheatUsed: 2,
                attackerMoveOverride: .standstill
            ),
            overheatAllowed: true,
            roll: DiceRoll2D6(die1: 6, die2: 6)
        )

        let session = try appliedShot(
            attacker: attacker,
            defender: defender,
            range: .long,
            overheatUsed: 2,
            overheatAllowed: true
        )
        let shot = try #require(session.units.first { $0.id == attacker.id }?.turnShot)
        #expect(shot.damage == preview.ifHit.delivered)
        #expect(preview.ifHit.delivered == 3)
    }

    private func appliedShot(
        attacker: MatchUnitState,
        defender: MatchUnitState,
        range: RangeBracket,
        overheatUsed: Int,
        overheatAllowed: Bool
    ) throws -> MatchSession {
        var ruleset = ScenarioRuleset.ridgeLine
        ruleset.overheatAllowed = overheatAllowed
        let session = MatchSession(
            ruleset: ruleset,
            phase: .combat,
            activeSide: attacker.side,
            units: [attacker, defender],
            status: .active,
            tableReady: true,
            forcesLoaded: true
        )
        return try MatchReducer.reduce(
            session,
            .resolveSATOR(
                SATORAttackCommand(
                    attackerId: attacker.id,
                    defenderId: defender.id,
                    range: range,
                    roll: DiceRoll2D6(die1: 6, die2: 6),
                    attackerMove: .standstill,
                    targetMove: .standstill,
                    overheatUsed: overheatUsed
                )
            )
        )
    }
}
