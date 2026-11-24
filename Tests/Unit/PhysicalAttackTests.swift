import Foundation
import Testing
import MechBuddyDomain

/// Standard physical attacks (punch or kick), Alpha Strike Quick-Start Rulebook pp. 20–24.
/// Rules intake: docs/game-modes/alpha-strike/mission-ladder-rules-intake.md §3.
@Suite("Physical attacks")
struct PhysicalAttackTests {
    private func blr(heat: Int = 0, crits: CritFlags = CritFlags()) -> MatchUnitState {
        MatchUnitState(
            name: "BattleMaster BLR-1G", side: .lanceA, pv: 40, sz: 4, mv: "8\"", tmm: 1,
            s: 3, m: 3, l: 1, ov: 1, armorCap: 8, structureCap: 7, heat: heat,
            abilities: "REAR1/1/-", crits: crits, movementMode: .ground, hasMovedThisTurn: true
        )
    }

    private func thunderbolt(armorDamage: Int = 0) -> MatchUnitState {
        MatchUnitState(
            name: "Thunderbolt TDR-5S", side: .lanceB, pv: 36, sz: 3, mv: "8\"", tmm: 1,
            s: 3, m: 3, l: 1, ov: 1, armorCap: 7, structureCap: 5, armorDamage: armorDamage,
            abilities: "IF1", movementMode: .ground, hasMovedThisTurn: true
        )
    }

    private func locust(side: SideId = .lanceA) -> MatchUnitState {
        MatchUnitState(
            name: "Locust LCT-1V", side: side, pv: 18, sz: 1, mv: "16\"", tmm: 3,
            s: 1, m: 1, l: 0, ov: 0, armorCap: 2, structureCap: 2,
            movementMode: .ground, hasMovedThisTurn: true
        )
    }

    private func combat(_ units: [MatchUnitState], physical: Bool = true) -> MatchSession {
        var ruleset = ScenarioRuleset.ridgeLine
        ruleset.overheatAllowed = true
        ruleset.physicalAttacksAllowed = physical
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

    private func punch(
        _ session: MatchSession,
        from a: Int = 0,
        at d: Int = 1,
        roll: DiceRoll2D6,
        targetMove: TargetMoveModifier = .standstill,
        rearHit: Bool = false
    ) throws -> MatchSession {
        try MatchReducer.reduce(session, .resolveSATOR(.physical(
            attackerId: session.units[a].id,
            defenderId: session.units[d].id,
            roll: roll,
            attackerMove: .ground,
            targetMove: targetMove,
            rearHit: rearHit
        )))
    }

    // MARK: To-hit

    @Test("To-hit is Skill + move + target move + cover: no range, heat or fire control")
    func toHit() throws {
        var fireControl = CritFlags()
        fireControl.fireControlHits = 1
        let attacker = blr(heat: 2, crits: fireControl)
        let input = SATORInput(
            skill: 4,
            attackerMove: .ground,
            targetMove: .groundUsesTMM,
            targetTMM: 1,
            other: OtherModifiers(woods: true, fireControlHits: 1, attackerHeat: 2),
            attackKind: .physical
        )
        let tn = try SATORResolver.resolve(input)
        #expect(tn.value == 6) // 4 + 0 + 1 + 1 woods
        #expect(!tn.breakdown.contains { $0.hasPrefix("R ") })
        #expect(tn.reasons.contains("Punch or kick, no range modifier"))
        #expect(tn.reasons.contains { $0.hasPrefix("Attacker walked") })

        // Same pair as a weapon shot at short range: heat and fire control count.
        var weapon = input
        weapon.attackKind = .weapon
        weapon.rangeBracket = .short
        #expect(try SATORResolver.resolve(weapon).value == 10)

        // The solver ignores the range setting for a punch.
        var insight = CombatTableInsight(rangeInches: 30, targetMove: .groundUsesTMM, woods: true)
        insight.attackKind = .physical
        let solve = CombatSolver.solve(
            attacker: attacker, defender: thunderbolt(), insight: insight,
            overheatAllowed: true, physicalAttacksAllowed: true
        )
        #expect(solve.cannotShootReason == nil)
        #expect(solve.targetNumber?.value == 6)
        #expect(solve.isPhysical)
    }

    @Test("Sprinted, shut-down, or out-of-arc attackers can't punch")
    func blocked() {
        var insight = CombatTableInsight()
        insight.attackKind = .physical
        var sprinted = blr()
        sprinted.movementMode = .sprint
        #expect(CombatSolver.solve(
            attacker: sprinted, defender: thunderbolt(), insight: insight,
            overheatAllowed: true, physicalAttacksAllowed: true
        ).cannotShootReason?.contains("sprinted") == true)
        #expect(CombatSolver.solve(
            attacker: blr(heat: 4), defender: thunderbolt(), insight: insight,
            overheatAllowed: true, physicalAttacksAllowed: true
        ).cannotShootReason?.contains("shut down") == true)
        insight.targetInFrontArc = false
        #expect(CombatSolver.solve(
            attacker: blr(), defender: thunderbolt(), insight: insight,
            overheatAllowed: true, physicalAttacksAllowed: true
        ).cannotShootReason == "You can only punch or kick a ’Mech in front of you.")
    }

    // MARK: Damage

    @Test("Damage is the attacker's Size; weapon hits don't lower it, overheat can't add to it")
    func damageIsSize() throws {
        var weaponHits = CritFlags()
        weaponHits.weaponHits = 2
        #expect(AlphaStrikeDamage.physical(attacker: blr(crits: weaponHits), rearHit: false).delivered == 4)
        #expect(AlphaStrikeDamage.physical(attacker: locust(), rearHit: false).delivered == 1)
        var mel = locust()
        mel.abilities = "MEL"
        #expect(AlphaStrikeDamage.physical(attacker: mel, rearHit: false).delivered == 2)

        // Overheat declared on a punch is dropped: no extra damage, no heat.
        var session = combat([blr(crits: weaponHits), thunderbolt()])
        session = try MatchReducer.reduce(session, .resolveSATOR(SATORAttackCommand(
            attackerId: session.units[0].id, defenderId: session.units[1].id, range: .medium,
            roll: DiceRoll2D6(die1: 5, die2: 4), attackerMove: .ground, targetMove: .standstill,
            overheatUsed: 1, attackKind: .physical
        )))
        #expect(session.units[0].turnShot?.damage == 4)
        #expect(session.units[0].turnShot?.kind == .physical)
        #expect(session.units[0].overheatThisTurn == 0)
        #expect(session.units[1].remainingArmor == 3)
    }

    @Test("A punch from behind adds 1")
    func rearPlusOne() throws {
        var insight = CombatTableInsight(targetMove: .standstill, rearHit: true)
        insight.attackKind = .physical
        let solve = CombatSolver.solve(
            attacker: blr(), defender: thunderbolt(), insight: insight,
            overheatAllowed: true, physicalAttacksAllowed: true
        )
        #expect(solve.ifHit.delivered == 5)

        let session = try punch(combat([blr(), thunderbolt()]), roll: DiceRoll2D6(die1: 4, die2: 4), rearHit: true)
        #expect(session.units[0].turnShot?.damage == 5)
        #expect(session.units[1].remainingArmor == 2)
    }

    @Test("A punch that reaches structure owes a critical, like a shot")
    func critical() throws {
        let session = try punch(combat([blr(), thunderbolt(armorDamage: 6)]), roll: DiceRoll2D6(die1: 3, die2: 4))
        #expect(session.units[1].remainingArmor == 0)
        #expect(session.units[1].remainingStructure == 2)
        #expect(session.units[1].criticalsOwed == 1)
        #expect(session.eventLog.last?.message.hasSuffix("A critical is owed.") == true)
    }

    // MARK: One attack a turn

    @Test("One attack a turn: a punch uses the shot and a shot uses the punch")
    func oneAttackPerTurn() throws {
        let punched = try punch(combat([blr(), thunderbolt()]), roll: DiceRoll2D6(die1: 1, die2: 2))
        #expect(punched.units[0].hasAttackedThisTurn)
        #expect(!punched.units[0].canAttackThisTurn)
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(punched, .resolveSATOR(SATORAttackCommand(
                attackerId: punched.units[0].id, defenderId: punched.units[1].id, range: .short,
                roll: DiceRoll2D6(die1: 6, die2: 6), targetMove: .standstill
            )))
        }

        var shot = combat([blr(), thunderbolt()])
        shot = try MatchReducer.reduce(shot, .resolveSATOR(SATORAttackCommand(
            attackerId: shot.units[0].id, defenderId: shot.units[1].id, range: .short,
            roll: DiceRoll2D6(die1: 6, die2: 5), targetMove: .standstill
        )))
        #expect(throws: MatchDomainError.self) {
            try punch(shot, roll: DiceRoll2D6(die1: 6, die2: 6))
        }
    }

    // MARK: Gating

    @Test("Missions without physical attacks refuse a punch")
    func gating() {
        let session = combat([blr(), thunderbolt()], physical: false)
        #expect(throws: MatchDomainError.self) {
            try punch(session, roll: DiceRoll2D6(die1: 6, die2: 6))
        }
        var insight = CombatTableInsight()
        insight.attackKind = .physical
        let solve = CombatSolver.solve(
            attacker: blr(), defender: thunderbolt(), insight: insight,
            overheatAllowed: false, physicalAttacksAllowed: false
        )
        #expect(solve.cannotShootReason == "Punches and kicks aren’t used in this mission.")
        #expect(!solve.canApply)
    }

    @Test("Bases touching blocks the shot but not the punch")
    func basesTouching() {
        var insight = CombatTableInsight(targetMove: .standstill)
        insight.basesTouching = true
        let shot = CombatSolver.solve(
            attacker: blr(), defender: thunderbolt(), insight: insight,
            overheatAllowed: true, physicalAttacksAllowed: true
        )
        #expect(shot.cannotShootReason?.hasSuffix("Punch or kick instead.") == true)
        let ridgeLine = CombatSolver.solve(
            attacker: blr(), defender: thunderbolt(), insight: insight, overheatAllowed: false
        )
        #expect(ridgeLine.cannotShootReason?.hasSuffix("Move apart first.") == true)

        insight.attackKind = .physical
        let punch = CombatSolver.solve(
            attacker: blr(), defender: thunderbolt(), insight: insight,
            overheatAllowed: true, physicalAttacksAllowed: true
        )
        #expect(punch.cannotShootReason == nil)
        #expect(punch.ifHit.delivered == 4)
    }

    @Test("A 'Mech with no long-range damage can still punch")
    func noDamageBandDoesNotApply() throws {
        var session = combat([locust(), thunderbolt()])
        session = try MatchReducer.reduce(session, .resolveSATOR(.physical(
            attackerId: session.units[0].id, defenderId: session.units[1].id,
            roll: DiceRoll2D6(die1: 6, die2: 4), targetMove: .standstill
        )))
        #expect(session.units[0].turnShot?.hit == true)
        #expect(session.units[0].turnShot?.damage == 1)
    }

    // MARK: Log and heat

    @Test("Log lines keep the shot-feed shape and say it was a punch or kick")
    func logSentences() throws {
        let hit = try punch(combat([blr(), thunderbolt()]), roll: DiceRoll2D6(die1: 4, die2: 4))
        let hitLine = try #require(hit.eventLog.last?.message)
        #expect(hitLine == "BattleMaster BLR-1G hit Thunderbolt TDR-5S for 4. Rolled 8, needed 4. Punch or kick.")
        let shot = try #require(hit.units[0].turnShot)
        #expect(hitLine.contains("BattleMaster BLR-1G hit \(shot.targetName) for \(shot.damage). Rolled \(shot.total), needed \(shot.targetNumber)."))
        #expect(shot.rowDetail == "Punch or kick. Rolled 8, needed 4.")

        let miss = try punch(combat([blr(), thunderbolt()]), roll: DiceRoll2D6(die1: 1, die2: 1))
        #expect(miss.eventLog.last?.message == "BattleMaster BLR-1G missed Thunderbolt TDR-5S. Rolled 2, needed 4. Punch or kick. No damage.")
    }

    @Test("A punch isn't a weapon attack: heat clears and an engine hit adds none")
    func heatCools() throws {
        var engine = CritFlags()
        engine.engineHits = 1
        var session = combat([blr(heat: 2, crits: engine), thunderbolt()])
        session = try punch(session, roll: DiceRoll2D6(die1: 5, die2: 5))
        #expect(!session.units[0].madeWeaponAttackThisTurn)
        session.phase = .end
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.units[0].heat == 0)
    }

    @Test("Saved shots from before punches decode as weapon shots")
    func turnShotDecoding() throws {
        let legacy = #"{"targetName":"Locust LCT-1V","hit":true,"total":9,"targetNumber":6,"damage":2}"#
        let old = try JSONDecoder().decode(TurnShot.self, from: Data(legacy.utf8))
        #expect(old.kind == .weapon)
        let punch = TurnShot(targetName: "Locust LCT-1V", hit: true, total: 9, targetNumber: 6, damage: 4, kind: .physical)
        let decoded = try JSONDecoder().decode(TurnShot.self, from: JSONEncoder().encode(punch))
        #expect(decoded == punch)
    }
}
