// PM8: objectives and victory points in Play (PlayModeSpec § 6.6, § 7, § 12), behind `playObjectives`.
import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

private func mech(_ name: String, _ side: SideId, size: Int = 2, structure: Int = 4, armor: Int = 4, damage: Int = 3, clan: Bool = false) -> MatchUnitState {
    var unit = MatchUnitState(
        name: name, side: side, pv: 20, sz: size, mv: "6\"", tmm: 1,
        s: damage, m: damage, l: damage, ov: 0, armorCap: armor, structureCap: structure
    )
    unit.isClan = clan
    return unit
}

/// A Play game with an objective, one or more 'Mechs per side, standing at the Clean up step of `turn`.
private func game(
    _ objective: ObjectiveId?,
    sides counts: [Int] = [2, 2],
    turn: Int = 1,
    turnLimit: Int? = nil,
    clan: Set<SideId> = []
) throws -> MatchSession {
    var setup = PlaySetup.pickup()
    setup.setPlayerCounts(Array(repeating: 1, count: counts.count))
    setup.objectiveId = objective
    setup.turnLimit = turnLimit
    var units: [MatchUnitState] = []
    for (index, count) in counts.enumerated() {
        let side = SideId.allCases[index]
        units += (0..<count).map { mech("\(side.letter)\($0)", side, clan: clan.contains(side)) }
    }
    var session = try MatchReducer.reduce(MatchSession(ruleset: setup.ruleset), .startPlay(setup: setup, units: units))
    session = try MatchReducer.reduce(session, .markTableReady)
    session.deploymentAcknowledged = true
    session.turn = turn
    session.phase = .end
    return session
}

private func unit(_ session: MatchSession, _ name: String) -> MatchUnitState { session.units.first { $0.name == name }! }

private func score(_ session: MatchSession, _ side: SideId, _ entries: [ObjectiveScoreEntry]) throws -> MatchSession {
    try MatchReducer.reduce(session, .scoreObjective(side: side, entries: entries))
}

/// Everyone answers "no one" so the End Phase can close.
private func scoreNobody(_ session: MatchSession) throws -> MatchSession {
    var next = session
    for side in ObjectiveRules.sidesStillToScore(in: next) { next = try score(next, side, []) }
    return next
}

private func shoot(_ session: MatchSession, from attacker: String, at defender: String, total: Int = 11, targetMove: TargetMoveModifier = .immobile) throws -> MatchSession {
    var next = session
    next.phase = .combat
    let roll = DiceRoll2D6(die1: min(6, total - 1), die2: total - min(6, total - 1))
    return try MatchReducer.reduce(next, .resolveSATOR(SATORAttackCommand(
        attackerId: unit(session, attacker).id, defenderId: unit(session, defender).id,
        range: .short, roll: roll, attackerMove: .standstill, targetMove: targetMove
    )))
}

/// A shot, then the critical it owes rolled as "no effect" (5), so the next shot is allowed.
private func shootAndClearCrit(_ session: MatchSession, from attacker: String, at defender: String) throws -> MatchSession {
    var next = try shoot(session, from: attacker, at: defender)
    if unit(next, defender).criticalsOwed > 0 {
        next = try MatchReducer.reduce(next, .applyCritical(unitId: unit(next, defender).id, roll: DiceRoll2D6(die1: 2, die2: 3)))
    }
    return next
}

private func closeEndPhase(_ session: MatchSession) throws -> MatchSession {
    var next = session
    next.phase = .end
    return try MatchReducer.reduce(next, .resolveEndPhase)
}

@Suite("PM8 flag and setup")
struct PlayObjectivesFlagTests {
    @Test("Roll for it follows the book order; a 6 is Find the Target, so it rolls again")
    func rollMapping() {
        #expect([1, 2, 3, 4, 5].compactMap(ObjectiveId.fromRoll) == ObjectiveId.built)
        #expect(ObjectiveId.fromRoll(6) == nil)
        struct Fixed: RandomNumberGenerator { var values: [UInt64]; mutating func next() -> UInt64 { values.removeFirst() } }
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<50 { #expect(ObjectiveId.roll(using: &generator).isBuilt) }
    }

    @Test("Find the Target is not scored: a game that names it plays last side standing")
    func findTheTargetNotBuilt() throws {
        let session = try game(.findTheTarget)
        #expect(session.objective == nil)
        #expect(ObjectiveRules.sidesToScore(in: session).isEmpty)
    }

    @Test("Raid and Hold the Fort make tokens at the start; the others make none")
    func tokens() throws {
        #expect(try game(.raid, sides: [1, 1, 1]).objectiveState?.tokens.count == 9)
        #expect(try game(.holdTheFort).objectiveState?.tokens.count == 4)
        #expect(try game(.breakthrough).objectiveState?.tokens.isEmpty == true)
        #expect(try game(nil).objectiveState == nil)
    }
}

@Suite("PM8 attacker per damage event")
struct AttackerRecordingTests {
    @Test("A hit records the attacking side on the target")
    func records() throws {
        let session = try shoot(try game(nil, sides: [1, 1, 1]), from: "C0", at: "A0")
        #expect(unit(session, "A0").lastDamagedBy == .lanceC)
        #expect(unit(session, "B0").lastDamagedBy == nil)
    }

    @Test("A miss records nothing")
    func miss() throws {
        let session = try shoot(try game(nil), from: "B0", at: "A0", total: 2, targetMove: .groundUsesTMM)
        #expect(unit(session, "A0").lastDamagedBy == nil)
    }

    @Test("The critical prompt names the side that caused the roll with three sides")
    func critRoller() throws {
        var session = try game(nil, sides: [1, 1, 1])
        // Natural 12 owes a critical.
        session = try shoot(session, from: "B0", at: "A0", total: 12)
        let target = unit(session, "A0")
        #expect(target.criticalsOwed >= 1)
        #expect(target.critCausedBy == .lanceB)
        #expect(session.sideThatHit(target) == .lanceB)
        #expect(session.criticalRollerName(for: target) == "Side B")
        // Another side hits later: the crit still belongs to the side whose hit caused it.
        session = try MatchReducer.reduce(session, .applyCritical(unitId: target.id, roll: DiceRoll2D6(die1: 2, die2: 3)))
        #expect(unit(session, "A0").critCausedBy == nil)
    }

    @Test("Without a record and with three sides, the prompt still says the side that hit it")
    func oldSave() throws {
        let session = try game(nil, sides: [1, 1, 1])
        #expect(session.sideThatHit(unit(session, "A0")) == nil)
        #expect(session.criticalRollerName(for: unit(session, "A0")) == "The side that hit it")
    }

    @Test("A critical that destroys scores for the side whose hit caused the roll")
    func critKill() throws {
        var session = try game(.destroyTheEnemy, sides: [1, 1, 1])
        // Armor soaks the hit, so only the natural 12 owes a critical.
        session = try shoot(session, from: "B0", at: "A0", total: 12)
        #expect(unit(session, "A0").criticalsOwed == 1)
        #expect(unit(session, "A0").downedBy == nil)
        session = try MatchReducer.reduce(session, .applyCritical(unitId: unit(session, "A0").id, roll: DiceRoll2D6(die1: 6, die2: 6)))
        #expect(unit(session, "A0").combatStatus == .destroyedPendingEnd)
        #expect(unit(session, "A0").downedBy == .lanceB)
        session = try closeEndPhase(session)
        #expect(session.points(of: .lanceB) == 2)
    }

    @Test("A critical that cripples (second MP hit) scores for the side that caused it")
    func critCripple() throws {
        var session = try game(.destroyTheEnemy, sides: [1, 1, 1])
        session.units[0].crits.mpHits = 1
        session.units[0].mv = "4\""
        session = try shoot(session, from: "C0", at: "A0", total: 12)
        session = try MatchReducer.reduce(session, .applyCritical(unitId: unit(session, "A0").id, roll: DiceRoll2D6(die1: 3, die2: 4)))
        #expect(unit(session, "A0").isImmobilizedByCrits)
        #expect(unit(session, "A0").downedBy == .lanceC)
    }
}

@Suite("PM8 Destroy the Enemy")
struct DestroyTheEnemyTests {
    @Test("The side whose attack crossed the crippled line scores the Size, once")
    func scoresOnce() throws {
        // Armor 1, structure 4: three damage leaves 2 structure with no armor, which is crippled (p. 12).
        var session = try game(.destroyTheEnemy, sides: [1, 1, 1])
        session.units[0].armorCap = 1
        session.units[0].structureCap = 4
        session = try shootAndClearCrit(session, from: "B0", at: "A0")
        #expect(unit(session, "A0").isCrippled)
        #expect(unit(session, "A0").downedBy == .lanceB)
        session = try shootAndClearCrit(session, from: "C0", at: "A0")
        #expect(unit(session, "A0").downedBy == .lanceB)
        session = try closeEndPhase(session)
        #expect(session.points(of: .lanceB) == 2)
        #expect(session.points(of: .lanceC) == 0)
        #expect(unit(session, "A0").scoredFor == .lanceB)
    }

    @Test("Own heat shutdown and Forced Withdrawal score for nobody")
    func noAttackNoScore() throws {
        var session = try game(.destroyTheEnemy)
        session.units[0].structureDamage = 3
        session.units[0].armorDamage = 4
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.victoryPoints.values.allSatisfy { $0 == 0 })
    }

    @Test("Clan against Inner Sphere scores 1.5 x Size and needs 12; mixed forces use no multiplier")
    func clanMultiplier() throws {
        let clash = try game(.destroyTheEnemy, clan: [.lanceA])
        #expect(ObjectiveRules.clanMultiplier(for: .lanceA, objective: .destroyTheEnemy, in: clash) == 1.5)
        #expect(ObjectiveRules.clanMultiplier(for: .lanceB, objective: .destroyTheEnemy, in: clash) == 1)
        #expect(ObjectiveRules.threshold(for: .lanceA, objective: .destroyTheEnemy, in: clash) == 12)
        #expect(ObjectiveRules.threshold(for: .lanceB, objective: .destroyTheEnemy, in: clash) == 10)
        var mixed = clash
        mixed.units[0].isClan = false
        #expect(ObjectiveRules.clanMultiplier(for: .lanceA, objective: .destroyTheEnemy, in: mixed) == 1)
        #expect(ObjectiveRules.threshold(for: .lanceA, objective: .destroyTheEnemy, in: mixed) == 10)
        // Control the Field has no multiplier.
        #expect(ObjectiveRules.clanMultiplier(for: .lanceA, objective: .controlTheField, in: clash) == 1)
    }

    @Test("Clan scores half points, kept as 3, and reaching 12 wins")
    func clanScoring() throws {
        var session = try game(.destroyTheEnemy, sides: [1, 1], clan: [.lanceA])
        // Forced Withdrawal off, so a crippled 'Mech still counts as standing and a wipe doesn't end the game first.
        session.ruleset.forcedWithdrawal = false
        session.units[1].armorCap = 1
        session.units[1].structureCap = 4
        session = try shootAndClearCrit(session, from: "A0", at: "B0")
        session = try closeEndPhase(session)
        #expect(session.points(of: .lanceA) == 3)
        #expect(ObjectiveRules.format(3) == "3" && ObjectiveRules.format(7.5) == "7.5")
        session.victoryPoints[.lanceA] = 11
        session.phase = .end
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.status == .active)
        session.victoryPoints[.lanceA] = 12
        session.phase = .end
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.outcome == .winner(.lanceA))
    }

    @Test("Conceded 'Mechs score for nobody")
    func concededScoreNothing() throws {
        var session = try game(.destroyTheEnemy, sides: [1, 1, 1])
        session.units[0].armorCap = 1
        session.units[0].structureCap = 4
        session = try shootAndClearCrit(session, from: "B0", at: "A0")
        session = try MatchReducer.reduce(session, .concede(side: .lanceA))
        session = try closeEndPhase(session)
        #expect(session.points(of: .lanceB) == 0)
    }

    @Test("Destroy the Enemy asks no questions, so the End Phase needs no Score step")
    func noScoreStep() throws {
        let session = try game(.destroyTheEnemy)
        #expect(ObjectiveRules.sidesToScore(in: session).isEmpty)
        _ = try MatchReducer.reduce(session, .resolveEndPhase)
    }
}

@Suite("PM8 Raid")
struct RaidTests {
    @Test("Pick up, carry, return: 2 points a token, and a carrier that is destroyed drops it")
    func raid() throws {
        var session = try game(.raid)
        #expect(throws: (any Error).self) { try MatchReducer.reduce(session, .resolveEndPhase) }
        let a0 = unit(session, "A0").id
        session = try score(session, .lanceA, [ObjectiveScoreEntry(kind: .pickedUp, unitId: a0)])
        session = try score(session, .lanceB, [])
        #expect(session.points(of: .lanceA) == 0)
        #expect(ObjectiveRules.carriedToken(by: a0, in: session)?.owner == .lanceB)
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.turn == 2)
        session.phase = .end
        session = try score(session, .lanceA, [ObjectiveScoreEntry(kind: .returned, unitId: a0)])
        session = try score(session, .lanceB, [])
        #expect(session.points(of: .lanceA) == 2)
        #expect(session.objectiveState?.tokens.filter(\.returned).count == 1)
        #expect(ObjectiveRules.carriedToken(by: a0, in: session) == nil)
    }

    @Test("A destroyed carrier drops its token, which can be picked up again")
    func drop() throws {
        var session = try game(.raid)
        let a0 = unit(session, "A0").id
        session = try score(session, .lanceA, [ObjectiveScoreEntry(kind: .pickedUp, unitId: a0)])
        session = try score(session, .lanceB, [])
        session.units[0].combatStatus = .destroyedPendingEnd
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.objectiveState?.tokens.allSatisfy { $0.carrier == nil } == true)
        #expect(ObjectiveRules.availableTokens(for: .lanceA, in: session).count == 3)
    }

    @Test("Only enemy tokens can be picked up, one per 'Mech, and only by a 'Mech on the table")
    func validation() throws {
        let session = try game(.raid, sides: [1, 1])
        let a0 = unit(session, "A0").id
        let twice = [ObjectiveScoreEntry(kind: .pickedUp, unitId: a0), ObjectiveScoreEntry(kind: .pickedUp, unitId: a0)]
        #expect(throws: (any Error).self) { try score(session, .lanceA, twice) }
        #expect(throws: (any Error).self) { try score(session, .lanceA, [ObjectiveScoreEntry(kind: .pickedUp, unitId: unit(session, "B0").id)]) }
        #expect(throws: (any Error).self) { try score(session, .lanceA, [ObjectiveScoreEntry(kind: .returned, unitId: a0)]) }
        // Four 'Mechs, but only three enemy tokens.
        var big = try game(.raid, sides: [4, 1])
        let entries = (0..<4).map { ObjectiveScoreEntry(kind: .pickedUp, unitId: unit(big, "A\($0)").id) }
        #expect(throws: (any Error).self) { try score(big, .lanceA, entries) }
        big = try score(big, .lanceA, Array(entries.prefix(3)))
        #expect(ObjectiveRules.availableTokens(for: .lanceA, in: big).isEmpty)
    }

    @Test("Ten points win; ten reached by two sides together goes to the higher score")
    func threshold() throws {
        var session = try game(.raid, sides: [1, 1, 1])
        session.victoryPoints = [.lanceA: 10, .lanceB: 12]
        session = try scoreNobody(session)
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.outcome == .winner(.lanceB))
    }

    @Test("Equal scores at the threshold tie with three sides")
    func tie() throws {
        var session = try game(.raid, sides: [1, 1, 1])
        session.victoryPoints = [.lanceA: 10, .lanceB: 10, .lanceC: 6]
        session = try scoreNobody(session)
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.outcome == .tied([.lanceA, .lanceB]))
    }
}

@Suite("PM8 Control the Field, Hold the Fort, Breakthrough")
struct OtherObjectiveTests {
    @Test("Control the Field scores the Size of each 'Mech in position, 12 wins")
    func controlTheField() throws {
        var session = try game(.controlTheField, sides: [2, 2])
        session.units[0].sz = 3
        session = try score(session, .lanceA, [
            ObjectiveScoreEntry(kind: .inPosition, unitId: unit(session, "A0").id),
            ObjectiveScoreEntry(kind: .inPosition, unitId: unit(session, "A1").id),
            ObjectiveScoreEntry(kind: .inPosition, unitId: unit(session, "A1").id) // duplicate counts once
        ])
        #expect(session.points(of: .lanceA) == 5)
        session = try score(session, .lanceB, [])
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        session.victoryPoints[.lanceA] = 12
        session.phase = .end
        session = try scoreNobody(session)
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.outcome == .winner(.lanceA))
    }

    @Test("Control the Field refuses another side's 'Mech")
    func controlOwnOnly() throws {
        let session = try game(.controlTheField)
        #expect(throws: (any Error).self) {
            try score(session, .lanceA, [ObjectiveScoreEntry(kind: .inPosition, unitId: unit(session, "B0").id)])
        }
    }

    @Test("Hold the Fort asks nothing before Turn 3")
    func holdTheFortEarly() throws {
        let early = try game(.holdTheFort, turn: 2)
        #expect(ObjectiveRules.sidesToScore(in: early).isEmpty)
        _ = try MatchReducer.reduce(early, .resolveEndPhase)
        let late = try game(.holdTheFort, turn: 3)
        #expect(ObjectiveRules.sidesToScore(in: late).count == 2)
    }

    @Test("Hold the Fort scores 1 per guarded token, own tokens only, at most 2 a turn")
    func holdTheFort() throws {
        var session = try game(.holdTheFort, turn: 3)
        session = try score(session, .lanceA, [
            ObjectiveScoreEntry(kind: .guarded, tokenId: "A1"),
            ObjectiveScoreEntry(kind: .guarded, tokenId: "A2")
        ])
        #expect(session.points(of: .lanceA) == 2)
        #expect(throws: (any Error).self) { try score(session, .lanceB, [ObjectiveScoreEntry(kind: .guarded, tokenId: "A1")]) }
        session = try score(session, .lanceB, [ObjectiveScoreEntry(kind: .guarded, tokenId: "B2")])
        #expect(session.points(of: .lanceB) == 1)
        #expect(throws: (any Error).self) { try score(session, .lanceB, []) } // once a turn
    }

    @Test("Hold the Fort: five turns of two tokens reach 10")
    func holdTheFortWins() throws {
        var session = try game(.holdTheFort, turn: 3)
        for _ in 0..<5 {
            session = try score(session, .lanceA, [ObjectiveScoreEntry(kind: .guarded, tokenId: "A1"), ObjectiveScoreEntry(kind: .guarded, tokenId: "A2")])
            session = try score(session, .lanceB, [])
            session = try MatchReducer.reduce(session, .resolveEndPhase)
            if session.status == .completed { break }
            session.phase = .end
        }
        #expect(session.outcome == .winner(.lanceA))
    }

    @Test("Breakthrough: 'Mechs that touch an enemy edge leave, score their Size, and are not destroyed")
    func breakthrough() throws {
        var session = try game(.breakthrough, sides: [2, 1])
        session.units[0].sz = 3
        let a0 = unit(session, "A0").id
        session = try score(session, .lanceA, [ObjectiveScoreEntry(kind: .exited, unitId: a0)])
        session = try score(session, .lanceB, [])
        #expect(session.points(of: .lanceA) == 3)
        #expect(unit(session, "A0").combatStatus == .removed)
        #expect(unit(session, "A0").leftTable)
        #expect(unit(session, "A0").downedBy == nil)
        #expect(VictoryEvaluator.pvLeft(side: .lanceA, in: session) == 20)
    }

    @Test("Breakthrough: a Clan 'Mech against the Inner Sphere scores 1.5 x Size; threshold stays 10")
    func breakthroughClan() throws {
        var session = try game(.breakthrough, clan: [.lanceA])
        session.units[0].sz = 3
        session = try score(session, .lanceA, [ObjectiveScoreEntry(kind: .exited, unitId: unit(session, "A0").id)])
        #expect(session.points(of: .lanceA) == 4.5)
        #expect(ObjectiveRules.threshold(for: .lanceA, objective: .breakthrough, in: session) == 10)
    }

    @Test("A side whose last 'Mech broke through is out but keeps its points and can still win")
    func breakthroughWins() throws {
        var session = try game(.breakthrough, sides: [1, 1])
        session.units[0].sz = 3
        session.victoryPoints[.lanceA] = 8
        session = try score(session, .lanceA, [ObjectiveScoreEntry(kind: .exited, unitId: unit(session, "A0").id)])
        session = try score(session, .lanceB, [])
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.outcome == .winner(.lanceA))
    }
}

@Suite("PM8 victory, turn limit and teams")
struct VictoryPointsTests {
    @Test("The objective comes before last side standing in the win check")
    func objectiveBeforeWipe() throws {
        var session = try game(.controlTheField, sides: [1, 1])
        session.victoryPoints[.lanceA] = 12
        session.units[0].combatStatus = .removed
        session.units[1].combatStatus = .removed
        let outcome = VictoryEvaluator.evaluateAfterEnd(session: session)
        #expect(outcome == .winner(.lanceA))
    }

    @Test("Turn limit with an objective: most points, then PV, then a tie")
    func turnLimit() throws {
        var session = try game(.controlTheField, sides: [1, 1, 1], turn: 8, turnLimit: 8)
        session.victoryPoints = [.lanceA: 4, .lanceB: 6, .lanceC: 3]
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == .winner(.lanceB))
        session.victoryPoints = [.lanceA: 6, .lanceB: 6, .lanceC: 3]
        session.units[0].pv = 30
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == .winner(.lanceA))
        session.units[0].pv = 20
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == .tied([.lanceA, .lanceB]))
    }

    @Test("Turn limit with two sides level on points and PV is a draw, as before")
    func twoSidesDraw() throws {
        var session = try game(.controlTheField, turn: 6, turnLimit: 6)
        session.victoryPoints = [.lanceA: 5, .lanceB: 5]
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == .draw)
    }

    @Test("Without an objective the turn limit still decides on PV")
    func pickupUnchanged() throws {
        var session = try game(nil, turn: 6, turnLimit: 6)
        session.units[0].pv = 40
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == .winner(.lanceA))
    }

    @Test("Standings put points ahead of PV when an objective is on")
    func standings() throws {
        var session = try game(.raid, sides: [1, 1, 1])
        session.victoryPoints = [.lanceA: 2, .lanceB: 6, .lanceC: 4]
        session.outcome = .winner(.lanceB)
        #expect(VictoryEvaluator.standings(in: session) == [.lanceB, .lanceC, .lanceA])
    }

    @Test("A team is one side: its points are the side's")
    func teams() throws {
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 2])
        setup.objectiveId = .controlTheField
        let units = [mech("A0", .lanceA), mech("B0", .lanceB), mech("B1", .lanceB)]
        var session = try MatchReducer.reduce(MatchSession(ruleset: setup.ruleset), .startPlay(setup: setup, units: units))
        session.phase = .end
        session = try score(session, .lanceB, [
            ObjectiveScoreEntry(kind: .inPosition, unitId: units[1].id),
            ObjectiveScoreEntry(kind: .inPosition, unitId: units[2].id)
        ])
        #expect(session.points(of: .lanceB) == 4)
        #expect(session.sides.count == 2)
    }

    @Test("Four sides: a side with nothing left on the table isn't asked")
    func outSidesSkipped() throws {
        var session = try game(.controlTheField, sides: [1, 1, 1, 1])
        session.units[3].combatStatus = .removed
        #expect(ObjectiveRules.sidesToScore(in: session) == [.lanceA, .lanceB, .lanceC])
        session = try scoreNobody(session)
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.sidesInGame.count == 3)
    }
}

@Suite("PM8 saves")
struct PlayObjectivesCodingTests {
    @Test("A session from before PM8 decodes with no points, no state and no attribution")
    func oldSave() throws {
        let session = try game(.raid)
        let data = try JSONEncoder().encode(session)
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "victoryPoints")
        json.removeValue(forKey: "objectiveState")
        var units = try #require(json["units"] as? [[String: Any]])
        for index in units.indices {
            for key in ["isClan", "lastDamagedBy", "critCausedBy", "downedBy", "scoredFor", "controller"] { units[index].removeValue(forKey: key) }
        }
        json["units"] = units
        let old = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(MatchSession.self, from: old)
        #expect(decoded.victoryPoints.isEmpty)
        #expect(decoded.objectiveState == nil)
        #expect(decoded.units.allSatisfy { !$0.isClan && $0.lastDamagedBy == nil && $0.downedBy == nil && $0.scoredFor == nil })
    }

    @Test("Points, tokens, attribution and the Clan flag survive a round trip")
    func roundTrip() throws {
        var session = try game(.raid, sides: [1, 1, 1], clan: [.lanceA])
        session = try score(session, .lanceA, [ObjectiveScoreEntry(kind: .pickedUp, unitId: unit(session, "A0").id)])
        session.victoryPoints = [.lanceA: 7.5, .lanceC: 2]
        session.units[1].lastDamagedBy = .lanceC
        session.units[1].downedBy = .lanceA
        session.units[1].controller = "Sam"
        let decoded = try JSONDecoder().decode(MatchSession.self, from: try JSONEncoder().encode(session))
        #expect(decoded == session)
        #expect(decoded.points(of: .lanceA) == 7.5)
        #expect(decoded.units[0].isClan)
    }

    @Test("A setup saved with an unknown objective reads as last side standing")
    func unknownObjective() throws {
        var setup = PlaySetup.pickup()
        setup.objective = "somethingNew"
        #expect(setup.objectiveId == nil)
        let decoded = try JSONDecoder().decode(PlaySetup.self, from: try JSONEncoder().encode(setup))
        #expect(decoded.objective == "somethingNew")
    }

    @Test("A mission is untouched: no objective, no score step")
    func missionUnchanged() throws {
        var session = MatchSession(ruleset: .ridgeLine, units: [mech("A0", .lanceA), mech("B0", .lanceB)])
        session.phase = .end
        #expect(session.objective == nil)
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.turn == 2)
    }
}
