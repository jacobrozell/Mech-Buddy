// PM7: three and four sides in Play (PlayModeSpec § 5.1, § 6, § 14, § 16). House rules, behind `playModeMultiSide`.
import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

private func mech(_ name: String, _ side: SideId, structure: Int = 3) -> MatchUnitState {
    MatchUnitState(
        name: name, side: side, pv: 20, sz: 2, mv: "6\"", tmm: 1,
        s: 2, m: 2, l: 1, ov: 0, armorCap: 4, structureCap: structure
    )
}

private func dice(_ total: Int) -> DiceRoll2D6 {
    let first = min(6, total - 1)
    return DiceRoll2D6(die1: first, die2: total - first)
}

private func pick(_ name: String) -> ForcePick {
    ForcePick(cardId: "x", name: name, basePV: 20, size: 2, skill: 4, isClan: false)
}

/// A started Play game: `counts[i]` 'Mechs for side i, sides in seat order.
private func playSession(_ counts: [Int]) throws -> MatchSession {
    var setup = PlaySetup.pickup()
    setup.setPlayerCounts(Array(repeating: 1, count: counts.count))
    var units: [MatchUnitState] = []
    for (index, count) in counts.enumerated() {
        let side = SideId.allCases[index]
        setup.forces[side] = (0..<count).map { pick("\(side.letter)\($0)") }
        units += (0..<count).map { mech("\(side.letter)\($0)", side) }
    }
    var session = try MatchReducer.reduce(MatchSession(ruleset: setup.ruleset), .startPlay(setup: setup, units: units))
    session = try MatchReducer.reduce(session, .markTableReady)
    session.deploymentAcknowledged = true
    return session
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private final class MultiSideBundleToken {}

@Suite("PM7 flag and presets")
struct MultiSideFlagTests {
    @Test("Setup offers free-for-all presets only when the flag is on")
    func gating() {
        #expect(TeamFormat.available(multiSide: false).map(\.title) == ["1 v 1", "1 v 2", "2 v 2", "1 v 3"])
        let on = TeamFormat.available(multiSide: true).map(\.title)
        #expect(on.contains("1 v 1 v 1") && on.contains("1 v 1 v 1 v 1") && on.contains("1 v 1 v 2"))
        #expect(TeamFormat.available(multiSide: false).allSatisfy { !$0.isHouseRule })
        #expect(TeamFormat.multiSide.allSatisfy { $0.isHouseRule })
    }

    @Test("A preset resizes the sides, edges and default budget; shrinking drops forces")
    func presets() {
        var setup = PlaySetup.pickup()
        #expect(!setup.usesHouseRules)
        setup.setPlayerCounts([1, 1, 1])
        #expect(setup.sides.map(\.id) == [.lanceA, .lanceB, .lanceC])
        #expect(setup.formatName == "1 v 1 v 1")
        #expect(setup.budget == .pointValue(200))
        #expect(setup.usesHouseRules)
        #expect(setup.sides.map(\.homeEdge) == [.west, .east, .south])
        setup.forces[.lanceC] = [pick("C0")]
        setup.setPlayerCounts([1, 1, 1, 1])
        #expect(setup.sides.map(\.id) == SideId.allCases)
        #expect(setup.budget == .pointValue(150))
        #expect(setup.sides.map(\.homeEdge) == [.west, .east, .south, .north])
        #expect(setup.forces[.lanceC]?.count == 1)
        #expect(setup.teamIssues.isEmpty)
        setup.setPlayerCounts([1, 1])
        #expect(setup.sides.count == 2)
        #expect(setup.forces[.lanceC] == nil)
        #expect(setup.budget == .pointValue(250))
    }

    @Test("A budget the players changed is kept when the format changes")
    func customBudgetKept() {
        var setup = PlaySetup.pickup(budgetPV: 300)
        setup.setPlayerCounts([1, 1, 1, 1])
        #expect(setup.budget == .pointValue(300))
    }

    @Test("1 v 1 v 2 is three sides and four players; five players is refused")
    func players() {
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 1, 2])
        #expect(setup.sides.count == 3 && setup.teamIssues.isEmpty)
        setup.setPlayerCounts([1, 1, 2, 1])
        #expect(setup.teamIssues == [.tooManyPlayers])
    }

    @Test("A saved two-side setup from before PM7 decodes and has no house rules")
    func oldSetupDecodes() throws {
        let json = #"{"budget":{"type":"pointValue","pv":250}}"#.data(using: .utf8)!
        let setup = try JSONDecoder().decode(PlaySetup.self, from: json)
        #expect(setup.sides.map(\.id) == [.lanceA, .lanceB])
        #expect(!setup.usesHouseRules)
        let session = MatchSession(ruleset: setup.ruleset)
        #expect(session.canSwapSides)
    }

    @Test("Table advice and checklist say [HOUSE] for three or four sides")
    func houseCopy() {
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 1, 1])
        #expect(PlayLayout.tableSteps(for: setup).contains { $0.hasPrefix("[HOUSE]") })
        #expect(Battlefield(kind: .mat, matWidth: 36, matDepth: 36).advice(sides: 3, budgetPV: 200) != nil)
        var two = PlaySetup.pickup()
        two.setPlayerCounts([2, 2])
        #expect(!PlayLayout.tableSteps(for: two).contains { $0.contains("[HOUSE]") })
    }

    @Test("The house rules topic ships in the Rules pack, labelled [HOUSE]")
    func topic() throws {
        let catalog = BundleContentCatalogRepository(bundle: Bundle(for: MultiSideBundleToken.self))
        let topic = try #require(try catalog.rulesTopics().topics.first { $0.id == "play-house-rules" })
        #expect(topic.game == RulesGameTag.alphaStrike)
        #expect(topic.sections.count >= 6)
        #expect(topic.sections.allSatisfy { $0.heading.contains("[HOUSE]") || $0.heading.hasPrefix("What the Quick-Start") })
        #expect(topic.sections.map(\.body).joined().contains("[HOUSE]"))
    }
}

@Suite("PM7 zones")
struct MultiSideZoneTests {
    @Test("Two sides keep full-width zones; three and four use the middle 3/8 of their edge")
    func zones() {
        let table = Battlefield(kind: .mat, matWidth: 48, matDepth: 48)
        let two = PlayLayout.layout(for: table, sides: PlaySetup.pickup().sides)
        #expect(two.zones.map(\.side) == ["A", "B"])
        #expect(two.zones[0].area.depth == 48)

        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 1, 1, 1])
        let four = PlayLayout.layout(for: table, sides: setup.sides)
        #expect(four.zones.map(\.side) == ["A", "B", "C", "D"])
        for zone in four.zones {
            let long = max(zone.area.width, zone.area.depth)
            let short = min(zone.area.width, zone.area.depth)
            #expect(long == 18)
            #expect(short == 6)
        }
        // Opposite zones are far apart and neighbours don't touch.
        let a = four.zones[0].area, c = four.zones[2].area
        #expect(a.maxX <= c.x || c.maxX <= a.x || a.maxY <= c.y || c.maxY <= a.y)
    }
}

@Suite("PM7 initiative")
struct MultiSideInitiativeTests {
    private func fill(_ entry: inout InitiativeEntry, round: Int, _ totals: [SideId: Int]) {
        for (side, total) in totals {
            let roll = dice(total)
            entry.set(round: round, side: side, die: 1, value: roll.die1)
            entry.set(round: round, side: side, die: 2, value: roll.die2)
        }
    }

    @Test("Four sides: lowest first, highest last")
    func fourSides() {
        var entry = InitiativeEntry(sides: SideId.allCases)
        #expect(entry.pending == .init(round: 0, sides: SideId.allCases))
        #expect(entry.order == nil)
        fill(&entry, round: 0, [.lanceA: 7, .lanceB: 3, .lanceC: 10, .lanceD: 5])
        #expect(entry.order == [.lanceB, .lanceD, .lanceA, .lanceC])
        #expect(entry.pending == nil)
        #expect(entry.initiativeRolls?.winner == .lanceC)
    }

    @Test("Three sides: a tie asks only the tied sides to roll again, among themselves")
    func tieAmongTwo() throws {
        var entry = InitiativeEntry(sides: [.lanceA, .lanceB, .lanceC])
        fill(&entry, round: 0, [.lanceA: 6, .lanceB: 9, .lanceC: 6])
        #expect(entry.order == nil)
        #expect(entry.pending == .init(round: 1, sides: [.lanceA, .lanceC]))
        #expect(entry.visibleRounds.map(\.round) == [0, 1])
        fill(&entry, round: 1, [.lanceA: 8, .lanceC: 4])
        // C re-rolled lower, so C first of the tied pair; B (9) still last.
        #expect(entry.order == [.lanceC, .lanceA, .lanceB])
        let rolls = try #require(entry.initiativeRolls)
        #expect(rolls.rerolls.count == 1)
        #expect(rolls.rerolls.first?.keys.sorted { $0.rawValue < $1.rawValue } == [.lanceA, .lanceC])
    }

    @Test("A re-roll that ties again goes to another round; a three-way tie rolls all three")
    func repeatedTies() {
        var entry = InitiativeEntry(sides: SideId.allCases)
        fill(&entry, round: 0, [.lanceA: 7, .lanceB: 7, .lanceC: 7, .lanceD: 2])
        #expect(entry.pending == .init(round: 1, sides: [.lanceA, .lanceB, .lanceC]))
        fill(&entry, round: 1, [.lanceA: 5, .lanceB: 9, .lanceC: 5])
        #expect(entry.pending == .init(round: 2, sides: [.lanceA, .lanceC]))
        fill(&entry, round: 2, [.lanceA: 6, .lanceC: 3])
        #expect(entry.order == [.lanceD, .lanceC, .lanceA, .lanceB])
    }

    @Test("Two separate tied pairs roll again in the same round")
    func twoPairs() {
        var entry = InitiativeEntry(sides: SideId.allCases)
        fill(&entry, round: 0, [.lanceA: 4, .lanceB: 4, .lanceC: 9, .lanceD: 9])
        #expect(entry.pending == .init(round: 1, sides: SideId.allCases))
        fill(&entry, round: 1, [.lanceA: 8, .lanceB: 5, .lanceC: 3, .lanceD: 11])
        #expect(entry.order == [.lanceB, .lanceA, .lanceC, .lanceD])
    }

    @Test("The app's roll always settles an order, for any seed")
    func autoRoll() {
        for seed in 1...60 {
            var generator = SeededGenerator(state: UInt64(seed))
            let count = 3 + seed % 2
            let entry = InitiativeEntry.autoRolled(sides: Array(SideId.allCases.prefix(count)), using: &generator)
            #expect(entry.isComplete)
            #expect(entry.order?.count == count)
        }
    }

    @Test("The reducer takes the finished rolls: order, winner last, first mover active, 4 sides")
    func reducer() throws {
        let session = try playSession([2, 2, 2, 2])
        var entry = InitiativeEntry(sides: session.sidesInGame)
        fill(&entry, round: 0, [.lanceA: 8, .lanceB: 5, .lanceC: 11, .lanceD: 2])
        let done = try MatchReducer.reduce(session, .setInitiative(try #require(entry.initiativeRolls)))
        #expect(done.initiativeOrder == [.lanceD, .lanceB, .lanceA, .lanceC])
        #expect(done.initiativeWinner == .lanceC)
        #expect(done.activeSide == .lanceD)
        #expect(done.phase == .movement)
        // Rolls for a side that isn't in the game are refused.
        var two = InitiativeEntry(sides: [.lanceA, .lanceB])
        fill(&two, round: 0, [.lanceA: 8, .lanceB: 5])
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .setInitiative(try #require(two.initiativeRolls)))
        }
    }

    @Test("Players can choose the whole order; it must name every side in the game")
    func chosenOrder() throws {
        let session = try playSession([1, 1, 1])
        let done = try MatchReducer.reduce(session, .agreeInitiativeOrder([.lanceC, .lanceA, .lanceB]))
        #expect(done.initiativeOrder == [.lanceC, .lanceA, .lanceB])
        #expect(done.initiativeWinner == .lanceB)
        #expect(done.activeSide == .lanceC)
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .agreeInitiativeOrder([.lanceA, .lanceB]))
        }
    }

    @Test("Movement order with four sides is round by round in initiative order, ending when everyone has moved")
    func movement() throws {
        var session = try playSession([4, 2, 2, 1])
        session = try MatchReducer.reduce(session, .agreeInitiativeOrder([.lanceC, .lanceA, .lanceD, .lanceB]))
        let sequence = AlphaStrikePhaseEngine.movementSequence(order: session.initiativeOrder, units: session.units)
        #expect(sequence.count == 9)
        for side in SideId.allCases {
            #expect(sequence.filter { $0 == side }.count == session.units.filter { $0.side == side }.count)
        }
        #expect(sequence.first == .lanceC)
        #expect(session.activeSide == .lanceC)
    }
}

@Suite("PM7 play")
struct MultiSidePlayTests {
    @Test("Swapping sides isn't offered with three or four sides")
    func noSwap() throws {
        #expect(try !playSession([1, 1, 1]).canSwapSides)
    }

    @Test("Home edges: taking an edge swaps with whoever holds it, and locks once placement is confirmed")
    func edges() throws {
        var session = try MatchReducer.reduce(MatchSession(ruleset: .ridgeLine), .startPlay(setup: {
            var setup = PlaySetup.pickup()
            setup.setPlayerCounts([1, 1, 1])
            return setup
        }(), units: [mech("A", .lanceA), mech("B", .lanceB), mech("C", .lanceC)]))
        #expect(session.sides.map(\.homeEdge) == [.west, .east, .south])
        session = try MatchReducer.reduce(session, .assignHomeEdge(side: .lanceC, edge: .west))
        #expect(session.sides.map(\.homeEdge) == [.south, .east, .west])
        session = try MatchReducer.reduce(session, .markTableReady)
        session.deploymentAcknowledged = true
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .assignHomeEdge(side: .lanceA, edge: .north))
        }
    }

    @Test("Conceding takes a side out, drops it from the order, and the last side standing wins")
    func concede() throws {
        var session = try playSession([2, 2, 2])
        session = try MatchReducer.reduce(session, .agreeInitiativeOrder([.lanceA, .lanceB, .lanceC]))
        session = try MatchReducer.reduce(session, .concede(side: .lanceB))
        #expect(session.sidesInGame == [.lanceA, .lanceC])
        #expect(session.initiativeOrder == [.lanceA, .lanceC])
        #expect(session.status == .active)
        #expect(session.units.filter { $0.side == .lanceB }.allSatisfy { $0.combatStatus == .removed })
        session = try MatchReducer.reduce(session, .concede(side: .lanceA))
        #expect(session.status == .completed)
        #expect(session.outcome == .winner(.lanceC))
        let standings = VictoryEvaluator.standings(in: session)
        #expect(standings.first == .lanceC)
        #expect(standings.last == .lanceB)
    }

    @Test("A side is out at the End Phase when nothing is left; the game continues with three sides, then ends")
    func goingOut() throws {
        var session = try playSession([1, 1, 1, 1])
        session = try MatchReducer.reduce(session, .agreeInitiativeOrder(SideId.allCases))
        session.phase = .end
        for index in session.units.indices where session.units[index].side == .lanceD {
            session.units[index].combatStatus = .destroyedPendingEnd
            session.units[index].structureDamage = session.units[index].structureCap
        }
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.status == .active)
        #expect(session.sidesInGame == [.lanceA, .lanceB, .lanceC])
        #expect(session.side(.lanceD)?.isOut == true)
        #expect(session.side(.lanceD)?.outOnTurn == 1)
        #expect(session.turn == 2 && session.phase == .initiative)
        #expect(session.eventLog.contains { $0.message == "Side D is out." })
        // Next turn's initiative needs rolls for the three sides still in.
        #expect(throws: MatchDomainError.self) {
            var entry = InitiativeEntry(sides: SideId.allCases)
            for side in SideId.allCases {
                entry.set(round: 0, side: side, die: 1, value: 1 + SideId.allCases.firstIndex(of: side)!)
                entry.set(round: 0, side: side, die: 2, value: 3)
            }
            try MatchReducer.reduce(session, .setInitiative(try #require(entry.initiativeRolls)))
        }
    }

    @Test("Victory with three sides: the last side with a 'Mech wins; everyone gone is a draw")
    func victory() throws {
        var session = try playSession([1, 1, 1])
        for index in session.units.indices where session.units[index].side != .lanceB {
            session.units[index].combatStatus = .removed
        }
        #expect(VictoryEvaluator.evaluate(session: session) == .winner(.lanceB))
        for index in session.units.indices { session.units[index].combatStatus = .removed }
        #expect(VictoryEvaluator.evaluate(session: session) == .draw)
    }

    @Test("Turn limit with three sides: most PV left wins; sides level at the top share the result")
    func turnLimit() throws {
        var session = try playSession([2, 2, 2])
        session.play?.turnLimit = 1
        session.units[0].combatStatus = .removed          // A loses a 'Mech
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == .tied([.lanceB, .lanceC]))
        session.units[2].combatStatus = .removed          // B loses one too
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == .winner(.lanceC))
        #expect(VictoryEvaluator.standings(in: {
            var done = session
            done.outcome = .winner(.lanceC)
            return done
        }()).first == .lanceC)
    }

    @Test("With several enemies the critical roller isn't recorded; with one it is the other side")
    func criticalRoller() throws {
        let three = try playSession([1, 1, 1])
        #expect(three.sideThatHit(three.units[0]) == nil)
        #expect(three.criticalRollerName(for: three.units[0]) == "The side that hit it")
        let two = try playSession([1, 1])
        #expect(two.sideThatHit(two.units[0]) == .lanceB)
        #expect(two.criticalRollerName(for: two.units[0]) == "Side B")
    }

    @Test("A 3-side session round-trips through its saved JSON")
    func roundTrip() throws {
        var session = try playSession([2, 1, 1])
        session = try MatchReducer.reduce(session, .agreeInitiativeOrder([.lanceB, .lanceC, .lanceA]))
        let data = try JSONEncoder().encode(session)
        let back = try JSONDecoder().decode(MatchSession.self, from: data)
        #expect(back.sides.map(\.id) == [.lanceA, .lanceB, .lanceC])
        #expect(back.initiativeOrder == [.lanceB, .lanceC, .lanceA])
        #expect(back.sides.map(\.homeEdge) == [.west, .east, .south])
    }
}
