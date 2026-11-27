// PM6: teams in Play (PlayModeSpec § 5.1, § 8.3, § 15). A team is one side (QSR p. 13, D3), so 1 v 2, 2 v 2
// and 1 v 3 are two sides with several players each.
import Foundation
import Testing
import MechBuddyDomain

private func mech(_ name: String, _ side: SideId, controller: String? = nil) -> MatchUnitState {
    var u = MatchUnitState(
        name: name, side: side, pv: 20, sz: 2, mv: "6\"", tmm: 1,
        s: 2, m: 2, l: 1, ov: 0, armorCap: 4, structureCap: 3
    )
    u.controller = controller
    return u
}

private func pick(_ name: String, controller: Int? = nil) -> ForcePick {
    ForcePick(cardId: "x", name: name, basePV: 20, size: 2, skill: 4, isClan: false, controllerIndex: controller)
}

@Suite("Play teams")
struct PlayTeamsTests {
    @Test("Presets set players per side and the format name")
    func presets() {
        var setup = PlaySetup.pickup()
        #expect(setup.playerCounts == [1, 1])
        for (format, name) in zip(TeamFormat.all, ["1 v 1", "1 v 2", "2 v 2", "1 v 3"]) {
            setup.setPlayerCounts(format.players)
            #expect(setup.formatName == name)
            #expect(setup.sides.count == 2)
            #expect(setup.teamIssues.isEmpty)
        }
    }

    @Test("Resizing keeps typed names and drops stale controller tags")
    func resize() {
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 3])
        setup.sides[1].players = ["Alex", "Sam", "Kim"]
        setup.forces[.lanceB] = [pick("A", controller: 2), pick("B", controller: 0)]
        setup.setPlayerCounts([1, 2])
        #expect(setup.sides[1].players == ["Alex", "Sam"])
        #expect(setup.forces[.lanceB]?.map(\.controllerIndex) == [nil, 0])
        setup.setPlayerCounts([1, 1])
        #expect(setup.forces[.lanceB]?.map(\.controllerIndex) == [nil, nil])
    }

    @Test("Validation: a side with no players, or more than four players, blocks Start")
    func validation() {
        var setup = PlaySetup.pickup()
        setup.sides[0].players = []
        #expect(setup.teamIssues == [.sideWithoutPlayer])
        setup = PlaySetup.pickup()
        setup.sides[0].players = ["", "", ""]
        setup.sides[1].players = ["", ""]
        #expect(setup.teamIssues == [.tooManyPlayers])
    }

    @Test("Uneven teams share one budget per side (D6): a 1 v 2 compares side totals, not head count")
    func budgetPerSide() {
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 2])
        setup.forces[.lanceA] = [pick("Solo"), pick("Solo2"), pick("Solo3")]
        setup.forces[.lanceB] = [pick("Pair1"), pick("Pair2"), pick("Pair3")]
        #expect(setup.totalPV(.lanceA) == setup.totalPV(.lanceB))
        #expect(setup.budgetCheck(.lanceA) == setup.budgetCheck(.lanceB))
    }

    @Test("Controller names appear only on a team side; blank players read Player N")
    func controllerNames() {
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 2])
        setup.sides[1].players = ["Alex", ""]
        #expect(setup.controllerName(of: pick("x", controller: 0), side: .lanceB) == "Alex")
        #expect(setup.controllerName(of: pick("x", controller: 1), side: .lanceB) == "Player 2")
        #expect(setup.controllerName(of: pick("x", controller: 0), side: .lanceA) == nil)
        #expect(setup.controllerName(of: pick("x"), side: .lanceB) == nil)
    }

    @Test("Pass line names the controller of the next unmoved 'Mech, else the side")
    func passLine() {
        var s = MatchSession(ruleset: .ridgeLine, units: [
            mech("A1", .lanceA),
            mech("B1", .lanceB, controller: "Alex"),
            mech("B2", .lanceB, controller: "Sam")
        ])
        s.sides = [MatchSide(id: .lanceA, name: "Reds"), MatchSide(id: .lanceB, name: "Blues", players: ["Alex", "Sam"])]
        #expect(s.passLine(for: .lanceA) == "Reds’s turn. Pass the phone.")
        #expect(s.passLine(for: .lanceB) == "Blues — Alex’s turn. Pass the phone.")
        s.units[1].hasMovedThisTurn = true
        #expect(s.passLine(for: .lanceB) == "Blues — Sam’s turn. Pass the phone.")
        s.units[2].hasMovedThisTurn = true
        #expect(s.passLine(for: .lanceB) == "Blues’s turn. Pass the phone.")
    }

    @Test("Opponents in a team game are the other side; a side wins when the other has none left")
    func opponentsAndVictory() {
        var s = MatchSession(ruleset: .ridgeLine, units: [
            mech("A1", .lanceA), mech("B1", .lanceB), mech("B2", .lanceB)
        ])
        s.sides = [MatchSide(id: .lanceA, players: ["Solo"]), MatchSide(id: .lanceB, players: ["Alex", "Sam"])]
        #expect(s.opponents(of: .lanceA) == [.lanceB])
        #expect(s.opponents(of: .lanceB) == [.lanceA])
        #expect(VictoryEvaluator.evaluate(session: s) == nil)
        s.units[0].combatStatus = .removed
        #expect(VictoryEvaluator.evaluate(session: s) == .winner(.lanceB))
    }

    @Test("Custom side names reach the roster groups")
    func namesInGroups() {
        var s = MatchSession(ruleset: .ridgeLine, units: [mech("A1", .lanceA), mech("B1", .lanceB)])
        s.sides = [MatchSide(id: .lanceA, name: "Wolves"), MatchSide(id: .lanceB, name: "Jackals")]
        #expect(SideGrouping.groups(in: s).map(\.name) == ["Wolves", "Jackals"])
    }

    @Test("Saves from before PM6 load: no controller on a unit or a pick")
    func oldSaves() throws {
        let unit = try JSONEncoder().encode(mech("A1", .lanceA))
        var json = try #require(try JSONSerialization.jsonObject(with: unit) as? [String: Any])
        json.removeValue(forKey: "controller")
        let decoded = try JSONDecoder().decode(MatchUnitState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.controller == nil)

        let pickData = try JSONEncoder().encode(pick("x", controller: 1))
        var pj = try #require(try JSONSerialization.jsonObject(with: pickData) as? [String: Any])
        pj.removeValue(forKey: "controllerIndex")
        let oldPick = try JSONDecoder().decode(ForcePick.self, from: JSONSerialization.data(withJSONObject: pj))
        #expect(oldPick.controllerIndex == nil)
    }
}
