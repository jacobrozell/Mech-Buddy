import Foundation
import Testing
import MechBuddyDomain

// PlayModeSpec § 20, PM1: N-side domain. Two sides must behave exactly as the QSR and missions did before.

private func unit(_ name: String, side: SideId, structure: Int = 4) -> MatchUnitState {
    MatchUnitState(
        name: name, side: side, pv: 20, sz: 2, mv: "10\"", tmm: 2,
        s: 2, m: 2, l: 1, ov: 0, armorCap: 4, structureCap: structure, abilities: ""
    )
}

private func units(_ counts: [SideId: Int]) -> [MatchUnitState] {
    SideId.allCases.flatMap { side in
        (0..<(counts[side] ?? 0)).map { unit("\(side.letter)\($0)", side: side) }
    }
}

private func roll(_ total: Int) -> DiceRoll2D6 {
    DiceRoll2D6(die1: max(1, total - 6), die2: min(6, total - 1))
}

private func session(sides: [SideId], units: [MatchUnitState], ruleset: ScenarioRuleset = .ridgeLine) -> MatchSession {
    MatchSession(
        ruleset: ruleset,
        sides: sides.map { MatchSide(id: $0) },
        units: units,
        tableReady: true,
        forcesLoaded: true,
        deploymentAcknowledged: true
    )
}

/// The two-side movement order exactly as `AlphaStrikePhaseEngine.movementSequence` computed it before PM1.
func legacyMovementSequence(firstToMove: SideId, second: SideId, units: [MatchUnitState]) -> [SideId] {
    let active = units.filter(AlphaStrikePhaseEngine.inMoveOrder)
    var first = active.filter { $0.side == firstToMove }.count
    var other = active.filter { $0.side != firstToMove }.count
    var sequence: [SideId] = []
    func batch(_ mine: Int, _ theirs: Int) -> Int {
        guard mine > 0 else { return 0 }
        guard theirs > 0 else { return mine }
        return mine >= 2 * theirs ? mine / theirs : 1
    }
    while first > 0 || other > 0 {
        let firstBatch = batch(first, other)
        let secondBatch = batch(other, first)
        sequence += Array(repeating: firstToMove, count: firstBatch)
        sequence += Array(repeating: second, count: secondBatch)
        first -= firstBatch
        other -= secondBatch
    }
    return sequence
}

@Suite("Play mode PM1: sides")
struct PlayModeSidesTests {
    @Test("SideId keeps A and B raw values and adds C and D")
    func rawValues() {
        #expect(SideId.allCases.map(\.rawValue) == ["lanceA", "lanceB", "lanceC", "lanceD"])
        #expect(SideId.allCases.map(\.letter) == ["A", "B", "C", "D"])
        #expect(SideId.lanceC.displayName == "Side C")
    }

    @Test("Two-side helpers give the old SideId.other answer")
    func twoSideHelpers() {
        let s = session(sides: SideId.missionPair, units: [])
        #expect(s.otherSide(of: .lanceA) == .lanceB)
        #expect(s.otherSide(of: .lanceB) == .lanceA)
        #expect(s.opponents(of: .lanceA) == [.lanceB])
        #expect(s.nextSide(after: .lanceB) == .lanceA)
    }

    @Test("Opponents and next side with four sides skip sides that are out")
    func fourSideHelpers() {
        var s = session(sides: SideId.allCases, units: [])
        s.sides[2].isOut = true
        #expect(s.opponents(of: .lanceA) == [.lanceB, .lanceD])
        #expect(s.nextSide(after: .lanceB) == .lanceD)
        #expect(s.nextSide(after: .lanceD) == .lanceA)
        #expect(s.sidesInGame == [.lanceA, .lanceB, .lanceD])
    }
}

@Suite("Play mode PM1: initiative order")
struct PlayModeInitiativeTests {
    @Test("Two sides: lower total first, higher wins, tie throws (p. 13)")
    func twoSides() throws {
        for a in 2...12 {
            for b in 2...12 {
                let rolls = InitiativeRolls(lanceA: roll(a), lanceB: roll(b))
                if a == b {
                    #expect(throws: MatchDomainError.initiativeTied) {
                        try AlphaStrikePhaseEngine.resolveInitiative(rolls: rolls)
                    }
                } else {
                    let winner: SideId = a > b ? .lanceA : .lanceB
                    let loser: SideId = a > b ? .lanceB : .lanceA
                    #expect(try AlphaStrikePhaseEngine.resolveInitiative(rolls: rolls) == winner)
                    #expect(try AlphaStrikePhaseEngine.initiativeOrder(rolls: rolls) == [loser, winner])
                }
            }
        }
    }

    @Test("Order is lowest first with four sides")
    func lowestFirst() throws {
        let rolls = InitiativeRolls(rolls: [.lanceA: roll(7), .lanceB: roll(11), .lanceC: roll(3), .lanceD: roll(9)])
        #expect(rolls.order == [.lanceC, .lanceA, .lanceD, .lanceB])
        #expect(rolls.winner == .lanceB)
    }

    @Test("Three-way tie re-rolls only the tied sides [HOUSE]")
    func threeWayTie() throws {
        let first: [SideId: DiceRoll2D6] = [.lanceA: roll(8), .lanceB: roll(8), .lanceC: roll(8), .lanceD: roll(4)]
        let pending = InitiativeOrder.resolve(rolls: first)
        #expect(pending.unresolvedTies == [[.lanceA, .lanceB, .lanceC]])
        #expect(throws: MatchDomainError.initiativeTied) {
            try AlphaStrikePhaseEngine.initiativeOrder(rolls: InitiativeRolls(rolls: first))
        }
        // D rolled 4 and stays first whatever the re-roll says.
        let rolls = InitiativeRolls(rolls: first, rerolls: [[.lanceA: roll(12), .lanceB: roll(2), .lanceC: roll(6)]])
        #expect(rolls.order == [.lanceD, .lanceB, .lanceC, .lanceA])
    }

    @Test("Two pairs tied: each pair is ordered by its own re-roll, and a pair can tie again")
    func twoPairs() {
        let first: [SideId: DiceRoll2D6] = [.lanceA: roll(5), .lanceB: roll(9), .lanceC: roll(5), .lanceD: roll(9)]
        #expect(InitiativeOrder.resolve(rolls: first).unresolvedTies == [[.lanceA, .lanceC], [.lanceB, .lanceD]])
        // Round 1: A/C break (C lower); B/D tie again. Round 2: only B and D roll.
        let round1: [SideId: DiceRoll2D6] = [.lanceA: roll(10), .lanceC: roll(2), .lanceB: roll(7), .lanceD: roll(7)]
        #expect(InitiativeOrder.resolve(rolls: first, rerolls: [round1]).unresolvedTies == [[.lanceB, .lanceD]])
        let round2: [SideId: DiceRoll2D6] = [.lanceB: roll(4), .lanceD: roll(3)]
        let rolls = InitiativeRolls(rolls: first, rerolls: [round1, round2])
        // A re-roll of 10 never lifts A past B and D, who tied higher on the first roll.
        #expect(rolls.order == [.lanceC, .lanceA, .lanceD, .lanceB])
    }

    @Test("Two sides tied then re-rolled resolves like a fresh roll")
    func twoSideReroll() throws {
        let rolls = InitiativeRolls(
            rolls: [.lanceA: roll(6), .lanceB: roll(6)],
            rerolls: [[.lanceA: roll(3), .lanceB: roll(9)]]
        )
        #expect(try AlphaStrikePhaseEngine.initiativeOrder(rolls: rolls) == [.lanceA, .lanceB])
    }

    @Test("setInitiative stores the order and starts the lowest side moving")
    func reducerOrder() throws {
        var s = session(sides: [.lanceA, .lanceB, .lanceC], units: units([.lanceA: 2, .lanceB: 2, .lanceC: 2]))
        s = try MatchReducer.reduce(s, .setInitiative(InitiativeRolls(rolls: [.lanceA: roll(9), .lanceB: roll(4), .lanceC: roll(7)])))
        #expect(s.initiativeOrder == [.lanceB, .lanceC, .lanceA])
        #expect(s.initiativeWinner == .lanceA)
        #expect(s.activeSide == .lanceB)
        #expect(s.eventLog.last?.message == "Initiative: A 9, B 4, C 7. Order: B, C, A. Side A goes last")
    }

    @Test("setInitiative needs a roll for every side still in the game, and none for sides that are out")
    func reducerNeedsEverySide() throws {
        var s = session(sides: [.lanceA, .lanceB, .lanceC], units: units([.lanceA: 1, .lanceB: 1, .lanceC: 1]))
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(s, .setInitiative(InitiativeRolls(lanceA: roll(5), lanceB: roll(6))))
        }
        s.sides[2].isOut = true
        let next = try MatchReducer.reduce(s, .setInitiative(InitiativeRolls(lanceA: roll(5), lanceB: roll(6))))
        #expect(next.initiativeOrder == [.lanceA, .lanceB])
    }

    @Test("Two-side log line is unchanged")
    func twoSideLog() throws {
        var s = session(sides: SideId.missionPair, units: units([.lanceA: 1, .lanceB: 1]))
        s = try MatchReducer.reduce(s, .setInitiative(InitiativeRolls(lanceA: roll(9), lanceB: roll(5))))
        #expect(s.eventLog.last?.message == "Initiative: 9 to 5. Side A goes last")
        #expect(s.initiativeOrder == [.lanceB, .lanceA])
    }

    @Test("Agreed order: players choose the whole order")
    func agreedOrder() throws {
        let s = session(sides: [.lanceA, .lanceB, .lanceC], units: units([.lanceA: 1, .lanceB: 1, .lanceC: 1]))
        let next = try MatchReducer.reduce(s, .agreeInitiativeOrder([.lanceC, .lanceA, .lanceB]))
        #expect(next.initiativeOrder == [.lanceC, .lanceA, .lanceB])
        #expect(next.initiativeWinner == .lanceB)
        #expect(next.activeSide == .lanceC)
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(s, .agreeInitiativeOrder([.lanceC, .lanceA]))
        }
    }

    @Test("Agreed first mover with two sides keeps its old meaning")
    func agreedFirstMover() throws {
        let s = session(sides: SideId.missionPair, units: units([.lanceA: 1, .lanceB: 1]))
        let next = try MatchReducer.reduce(s, .agreeInitiative(firstToMove: .lanceB))
        #expect(next.initiativeWinner == .lanceA)
        #expect(next.initiativeOrder == [.lanceB, .lanceA])
        #expect(next.activeSide == .lanceB)
    }
}

@Suite("Play mode PM1: movement order")
struct PlayModeMovementTests {
    @Test("Two sides: the § 6.2 sequence equals the pre-PM1 sequence for every count 0…10")
    func twoSideEquivalence() {
        for a in 0...10 {
            for b in 0...10 {
                let pool = units([.lanceA: a, .lanceB: b])
                for (first, second) in [(SideId.lanceA, SideId.lanceB), (.lanceB, .lanceA)] {
                    let legacy = legacyMovementSequence(firstToMove: first, second: second, units: pool)
                    #expect(AlphaStrikePhaseEngine.movementSequence(order: [first, second], units: pool) == legacy, "\(a) v \(b)")
                    #expect(AlphaStrikePhaseEngine.movementSequence(firstToMove: first, units: pool) == legacy, "\(a) v \(b)")
                }
            }
        }
    }

    @Test("p. 14 example, 8 vs 5: 1-1, 1-1, 1-2, 1-2, 1-2")
    func bookExample() {
        let sequence = AlphaStrikePhaseEngine.movementSequence(order: [.lanceB, .lanceA], units: units([.lanceA: 8, .lanceB: 5]))
        #expect(sequence == [.lanceB, .lanceA, .lanceB, .lanceA, .lanceB, .lanceA, .lanceA, .lanceB, .lanceA, .lanceA, .lanceB, .lanceA, .lanceA])
    }

    @Test("Three sides (4, 2, 2), order C, A, B: the spec example [HOUSE]")
    func threeSides422() {
        let sequence = AlphaStrikePhaseEngine.movementSequence(order: [.lanceC, .lanceA, .lanceB], units: units([.lanceC: 4, .lanceA: 2, .lanceB: 2]))
        #expect(sequence == [.lanceC, .lanceC, .lanceA, .lanceB, .lanceC, .lanceC, .lanceA, .lanceB])
    }

    @Test("Three sides (3, 3, 1) and (5, 0, 2) [HOUSE]")
    func threeSidesOther() {
        let order: [SideId] = [.lanceA, .lanceB, .lanceC]
        #expect(AlphaStrikePhaseEngine.movementSequence(order: order, units: units([.lanceA: 3, .lanceB: 3, .lanceC: 1]))
            == [.lanceA, .lanceA, .lanceA, .lanceB, .lanceB, .lanceB, .lanceC])
        #expect(AlphaStrikePhaseEngine.movementSequence(order: order, units: units([.lanceA: 5, .lanceC: 2]))
            == [.lanceA, .lanceA, .lanceC, .lanceA, .lanceA, .lanceA, .lanceC])
    }

    @Test("Four sides all equal alternate in order; a side at 0 is skipped")
    func fourSides() {
        let order: [SideId] = [.lanceD, .lanceB, .lanceA, .lanceC]
        #expect(AlphaStrikePhaseEngine.movementSequence(order: order, units: units([.lanceA: 2, .lanceB: 2, .lanceC: 2, .lanceD: 2]))
            == [.lanceD, .lanceB, .lanceA, .lanceC, .lanceD, .lanceB, .lanceA, .lanceC])
        #expect(AlphaStrikePhaseEngine.movementSequence(order: order, units: units([.lanceA: 2, .lanceC: 2, .lanceD: 2]))
            == [.lanceD, .lanceA, .lanceC, .lanceD, .lanceA, .lanceC])
    }

    @Test("Every N-side sequence moves each ’Mech exactly once")
    func conservesMoves() {
        let order: [SideId] = [.lanceB, .lanceD, .lanceA, .lanceC]
        for a in 0...5 { for b in 0...5 { for c in 0...5 { for d in 0...5 {
            let sequence = AlphaStrikePhaseEngine.movementSequence(order: order, units: units([.lanceA: a, .lanceB: b, .lanceC: c, .lanceD: d]))
            #expect(sequence.filter { $0 == .lanceA }.count == a)
            #expect(sequence.filter { $0 == .lanceB }.count == b)
            #expect(sequence.filter { $0 == .lanceC }.count == c)
            #expect(sequence.filter { $0 == .lanceD }.count == d)
        } } } }
    }

    @Test("Reducer follows the § 6.2 order through a three-side Movement phase")
    func reducerThreeSides() throws {
        var s = session(sides: [.lanceA, .lanceB, .lanceC], units: units([.lanceA: 2, .lanceB: 2, .lanceC: 4]))
        s = try MatchReducer.reduce(s, .agreeInitiativeOrder([.lanceC, .lanceA, .lanceB]))
        var seen: [SideId] = []
        while !AlphaStrikePhaseEngine.movementComplete(units: s.units) {
            seen.append(s.activeSide)
            let mover = try #require(AlphaStrikePhaseEngine.unitsNeedingMove(side: s.activeSide, units: s.units).first)
            s = try MatchReducer.reduce(s, .markMoved(unitId: mover.id))
        }
        #expect(seen == [.lanceC, .lanceC, .lanceA, .lanceB, .lanceC, .lanceC, .lanceA, .lanceB])
        s = try MatchReducer.reduce(s, .advancePhase)
        #expect(s.phase == .combat)
        #expect(s.activeSide == .lanceC)
    }
}

@Suite("Play mode PM1: elimination")
struct PlayModeEliminationTests {
    private func threeSideGame() throws -> MatchSession {
        var s = session(
            sides: [.lanceA, .lanceB, .lanceC],
            units: units([.lanceA: 2, .lanceB: 2, .lanceC: 1]),
            ruleset: ScenarioRuleset(overheatAllowed: false, physicalAttacksAllowed: false, forcedWithdrawal: false, maxTurns: nil, victory: .destroyAllEnemies)
        )
        s.phase = .end
        return s
    }

    @Test("A side goes out at the End Phase only, is logged, and is skipped next turn")
    func outAtEnd() throws {
        var s = try threeSideGame()
        s.phase = .combat
        let cIndex = try #require(s.units.firstIndex { $0.side == .lanceC })
        s.units[cIndex].combatStatus = .destroyedPendingEnd
        // Still in during Combat.
        #expect(s.sidesInGame == [.lanceA, .lanceB, .lanceC])
        s = try MatchReducer.reduce(s, .finishCombat)
        s = try MatchReducer.reduce(s, .resolveEndPhase)
        #expect(s.status == .active)
        #expect(s.side(.lanceC)?.isOut == true)
        #expect(s.side(.lanceC)?.outOnTurn == 1)
        #expect(s.eventLog.contains { $0.message == "Side C is out." })
        #expect(s.sidesInGame == [.lanceA, .lanceB])
        // Next turn: initiative and movement run without C.
        s = try MatchReducer.reduce(s, .setInitiative(InitiativeRolls(lanceA: roll(4), lanceB: roll(8))))
        #expect(s.initiativeOrder == [.lanceA, .lanceB])
        #expect(AlphaStrikePhaseEngine.movementSequence(order: s.initiativeOrder, units: s.units) == [.lanceA, .lanceB, .lanceA, .lanceB])
    }

    @Test("Concede removes the side's ’Mechs at once and the side is out")
    func concede() throws {
        var s = session(sides: [.lanceA, .lanceB, .lanceC], units: units([.lanceA: 2, .lanceB: 2, .lanceC: 2]))
        s = try MatchReducer.reduce(s, .agreeInitiativeOrder([.lanceB, .lanceC, .lanceA]))
        #expect(s.activeSide == .lanceB)
        s = try MatchReducer.reduce(s, .concede(side: .lanceB))
        #expect(s.units.filter { $0.side == .lanceB }.allSatisfy { $0.combatStatus == .removed })
        #expect(s.side(.lanceB)?.isOut == true)
        #expect(s.side(.lanceB)?.conceded == true)
        #expect(s.status == .active)
        #expect(s.initiativeOrder == [.lanceC, .lanceA])
        #expect(s.activeSide == .lanceC)
        #expect(throws: MatchDomainError.self) { try MatchReducer.reduce(s, .concede(side: .lanceB)) }
        // Down to one side: it wins at once.
        s = try MatchReducer.reduce(s, .concede(side: .lanceC))
        #expect(s.status == .completed)
        #expect(s.outcome == .winner(.lanceA))
    }

    @Test("Two sides: no 'is out' line, the game ends with a winner as before")
    func twoSidesNoNewLog() throws {
        var s = session(sides: SideId.missionPair, units: units([.lanceA: 1, .lanceB: 1]))
        s.phase = .end
        s.units[1].combatStatus = .destroyedPendingEnd
        s = try MatchReducer.reduce(s, .resolveEndPhase)
        #expect(s.outcome == .winner(.lanceA))
        #expect(!s.eventLog.contains { $0.message.hasSuffix("is out.") })
    }
}

@Suite("Play mode PM1: victory")
struct PlayModeVictoryTests {
    private let noCap = ScenarioRuleset(overheatAllowed: false, physicalAttacksAllowed: false, forcedWithdrawal: false, maxTurns: nil, victory: .destroyAllEnemies)

    @Test("Last side standing with 2, 3 and 4 sides", arguments: [2, 3, 4])
    func lastSideStanding(count: Int) {
        let sides = Array(SideId.allCases.prefix(count))
        var s = session(sides: sides, units: sides.flatMap { side in [unit("\(side.letter)", side: side)] }, ruleset: noCap)
        #expect(VictoryEvaluator.evaluate(session: s) == nil)
        for i in s.units.indices where s.units[i].side != sides.last {
            s.units[i].combatStatus = .removed
        }
        #expect(VictoryEvaluator.evaluate(session: s) == .winner(sides.last!))
    }

    @Test("Two of four sides left: no result yet")
    func twoLeft() {
        var s = session(sides: SideId.allCases, units: units([.lanceA: 1, .lanceB: 1, .lanceC: 1, .lanceD: 1]), ruleset: noCap)
        s.units[0].combatStatus = .removed
        s.units[2].combatStatus = .removed
        #expect(VictoryEvaluator.evaluate(session: s) == nil)
    }

    @Test("Mutual wipe is a draw with 2 and 3 sides", arguments: [2, 3])
    func mutualWipe(count: Int) {
        let sides = Array(SideId.allCases.prefix(count))
        var s = session(sides: sides, units: sides.map { unit("\($0.letter)", side: $0) }, ruleset: noCap)
        for i in s.units.indices { s.units[i].combatStatus = .removed }
        #expect(VictoryEvaluator.evaluate(session: s) == .draw)
    }

    @Test("Forced Withdrawal: crippled ’Mechs count as out with three sides too")
    func forcedWithdrawal() {
        var ruleset = noCap
        ruleset.forcedWithdrawal = true
        var s = session(sides: [.lanceA, .lanceB, .lanceC], units: units([.lanceA: 1, .lanceB: 1, .lanceC: 1]), ruleset: ruleset)
        s.units[1].combatStatus = .removed
        s.units[2].armorDamage = 4
        s.units[2].structureDamage = 2
        #expect(s.units[2].isCrippled)
        #expect(VictoryEvaluator.evaluate(session: s) == .winner(.lanceA))
    }

    @Test("Turn cap with two sides: equal structure is still a draw")
    func twoSideCapDraw() {
        var s = session(sides: SideId.missionPair, units: units([.lanceA: 1, .lanceB: 1]))
        s.turn = 6
        s.phase = .end
        #expect(VictoryEvaluator.evaluateAfterEnd(session: s) == .draw)
        s.units[0].structureDamage = 1
        #expect(VictoryEvaluator.evaluateAfterEnd(session: s) == .winner(.lanceB))
    }

    @Test("Turn cap with three sides: sides level at the top tie [HOUSE]")
    func threeSideCapTie() {
        var s = session(sides: [.lanceA, .lanceB, .lanceC], units: [
            unit("A", side: .lanceA, structure: 5), unit("B", side: .lanceB, structure: 5),
            unit("C", side: .lanceC, structure: 3), unit("D", side: .lanceC, structure: 3)
        ])
        s.turn = 6
        // C has 6 Structure: it wins.
        #expect(VictoryEvaluator.evaluateAfterEnd(session: s) == .winner(.lanceC))
        s.units[3].combatStatus = .removed
        #expect(VictoryEvaluator.evaluateAfterEnd(session: s) == .tied([.lanceA, .lanceB]))
    }
}

@Suite("Play mode PM1: payload v2")
struct PlayModeCodableTests {
    private func fixture() throws -> Data {
        let url = try #require(Bundle(for: PlayModeFixtureToken.self).url(forResource: "match-session-v1", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @Test("A v1 payload decodes as v2 with Side A and Side B and the old initiative shape")
    func v1Fixture() throws {
        let session = try decoder.decode(MatchSession.self, from: try fixture())
        #expect(session.schemaVersion == 2)
        #expect(session.sides == MatchSide.missionPair)
        #expect(session.sides.map(\.name) == ["Side A", "Side B"])
        #expect(session.initiativeWinner == .lanceA)
        #expect(session.initiativeRolls?.lanceA?.total == 9)
        #expect(session.initiativeRolls?.lanceB?.total == 5)
        #expect(session.initiativeRolls?.order == [.lanceB, .lanceA])
        #expect(session.initiativeOrder == [.lanceB, .lanceA])
        #expect(session.units.count == 2)
        #expect(session.activeSide == .lanceB)
        // It keeps playing: B moves next, then the turn's moves are done.
        let mover = try #require(session.units.first { $0.side == .lanceB })
        let next = try MatchReducer.reduce(session, .markMoved(unitId: mover.id))
        #expect(AlphaStrikePhaseEngine.movementComplete(units: next.units))
    }

    @Test("v2 round trip keeps sides, order and rerolls")
    func v2RoundTrip() throws {
        var s = session(sides: SideId.allCases, units: units([.lanceA: 1, .lanceC: 1]))
        s.sides[2].name = "Sam's Lance"
        s.sides[3].isOut = true
        s.sides[3].outOnTurn = 2
        s.initiativeRolls = InitiativeRolls(
            rolls: [.lanceA: roll(6), .lanceB: roll(6), .lanceC: roll(3)],
            rerolls: [[.lanceA: roll(8), .lanceB: roll(2)]]
        )
        s.initiativeOrder = s.initiativeRolls?.order ?? []
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(MatchSession.self, from: data)
        #expect(decoded == s)
        #expect(decoded.initiativeOrder == [.lanceC, .lanceB, .lanceA])
    }

    @Test("Outcomes: .tied round trip, and old draw and winner shapes")
    func outcomes() throws {
        let tied = MatchOutcome.tied([.lanceA, .lanceC])
        let data = try JSONEncoder().encode(tied)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["type"] as? String == "tied")
        #expect(json["sides"] as? [String] == ["lanceA", "lanceC"])
        #expect(try JSONDecoder().decode(MatchOutcome.self, from: data) == tied)
        #expect(try JSONDecoder().decode(MatchOutcome.self, from: Data(#"{"type":"draw"}"#.utf8)) == .draw)
        #expect(try JSONDecoder().decode(MatchOutcome.self, from: Data(#"{"type":"winner","side":"lanceB"}"#.utf8)) == .winner(.lanceB))
    }

    @Test("Old InitiativeRolls shape decodes")
    func oldInitiativeShape() throws {
        let json = #"{"lanceA":{"die1":1,"die2":2},"lanceB":{"die1":6,"die2":6}}"#
        let rolls = try JSONDecoder().decode(InitiativeRolls.self, from: Data(json.utf8))
        #expect(rolls.order == [.lanceA, .lanceB])
        #expect(rolls.winner == .lanceB)
    }
}

private final class PlayModeFixtureToken {}
