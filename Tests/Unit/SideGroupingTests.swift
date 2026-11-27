import Foundation
import Testing
import MechBuddyDomain

@Suite("Battle roster grouping by side")
struct SideGroupingTests {
    private func unit(_ name: String, _ side: SideId, removed: Bool = false) -> MatchUnitState {
        var u = MatchUnitState(
            name: name, side: side, pv: 1, sz: 1, mv: "10\"", tmm: 1,
            s: 1, m: 1, l: 0, ov: 0, armorCap: 2, structureCap: 2
        )
        if removed { u.combatStatus = .removed }
        return u
    }

    private func session(sides: [MatchSide], units: [MatchUnitState]) -> MatchSession {
        var s = MatchSession(ruleset: .ridgeLine, units: units)
        s.sides = sides
        return s
    }

    @Test("Two sides group in seat order, keeping unit order")
    func twoSides() {
        let s = session(sides: MatchSide.missionPair,
                        units: [unit("B1", .lanceB), unit("A1", .lanceA), unit("A2", .lanceA)])
        let g = SideGrouping.groups(in: s)
        #expect(g.map(\.side) == [.lanceA, .lanceB])
        #expect(g[0].units.map(\.name) == ["A1", "A2"])
        #expect(g[0].name == "Side A")
    }

    @Test("Removed units and empty sides are dropped; custom names and four sides work")
    func fourSidesCustomNames() {
        let sides = [
            MatchSide(id: .lanceA, name: "Wolves"), MatchSide(id: .lanceB),
            MatchSide(id: .lanceC), MatchSide(id: .lanceD)
        ]
        let s = session(sides: sides, units: [
            unit("A1", .lanceA), unit("B1", .lanceB, removed: true),
            unit("C1", .lanceC), unit("D1", .lanceD)
        ])
        let g = SideGrouping.groups(in: s)
        #expect(g.map(\.side) == [.lanceA, .lanceC, .lanceD])
        #expect(g[0].name == "Wolves")
    }
}

@Suite("Pinned side")
struct SideGroupingPinTests {
    @Test("Pinning moves the acting side first and keeps the rest in seat order")
    func pin() {
        func u(_ n: String, _ s: SideId) -> MatchUnitState {
            MatchUnitState(name: n, side: s, pv: 1, sz: 1, mv: "10\"", tmm: 1,
                           s: 1, m: 1, l: 0, ov: 0, armorCap: 2, structureCap: 2)
        }
        var session = MatchSession(ruleset: .ridgeLine, units: [u("A", .lanceA), u("B", .lanceB), u("C", .lanceC)])
        session.sides = [MatchSide(id: .lanceA), MatchSide(id: .lanceB), MatchSide(id: .lanceC)]
        #expect(SideGrouping.groups(in: session, pinned: .lanceC).map(\.side) == [.lanceC, .lanceA, .lanceB])
        #expect(SideGrouping.groups(in: session, pinned: nil).map(\.side) == [.lanceA, .lanceB, .lanceC])
    }
}
