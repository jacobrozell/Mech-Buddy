// PM11 leftovers: Find the Target, per-side objectives and MechWarrior cards (PlayModeSpec § 5.5, § 7.1).
import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

private func mech(_ name: String, _ side: SideId, size: Int = 2) -> MatchUnitState {
    MatchUnitState(
        name: name, side: side, pv: 20, sz: size, mv: "6\"", tmm: 1,
        s: 3, m: 3, l: 3, ov: 0, armorCap: 4, structureCap: 4
    )
}

private func buildings(_ count: Int) -> [BuildingState] {
    (1...max(count, 1)).prefix(count).map { BuildingState(id: "B\($0)", name: "Building \($0)", type: .medium) }
}

/// A Play game at the Clean up step of Turn 1: `objective` for everyone, or `perSide` for each side.
private func game(
    _ objective: ObjectiveId? = nil,
    perSide: [SideId: ObjectiveId] = [:],
    sides count: Int = 2,
    buildingCount: Int = 0,
    turn: Int = 1
) throws -> MatchSession {
    var setup = PlaySetup.pickup()
    setup.setPlayerCounts(Array(repeating: 1, count: count))
    setup.objectiveId = objective
    for (side, own) in perSide { setup.setObjective(own, for: side) }
    setup.rules.buildings = buildingCount > 0 ? buildings(buildingCount) : []
    let units = (0..<count).flatMap { index -> [MatchUnitState] in
        let side = SideId.allCases[index]
        return [mech("\(side.letter)0", side), mech("\(side.letter)1", side)]
    }
    var session = try MatchReducer.reduce(MatchSession(ruleset: setup.ruleset), .startPlay(setup: setup, units: units))
    session = try MatchReducer.reduce(session, .markTableReady)
    session.deploymentAcknowledged = true
    session.turn = turn
    session.phase = .end
    return session
}

private func unitId(_ session: MatchSession, _ name: String) -> UUID { session.units.first { $0.name == name }!.id }

@Suite("PM11 Find the Target")
struct FindTheTargetTests {
    @Test("Three buildings hide three targets, picked from the game id")
    func targetsHidden() throws {
        let session = try game(.findTheTarget, buildingCount: 4)
        #expect(session.objective == .findTheTarget)
        let state = try #require(session.objectiveState)
        #expect(state.targetBuildingIds.count == 3)
        #expect(Set(state.targetBuildingIds).isSubset(of: ["B1", "B2", "B3", "B4"]))
        #expect(state.foundTargets.isEmpty)
        // Same seed, same buildings, same choice.
        #expect(ObjectiveRules.pickTargets(buildings: buildings(4), seed: session.id) == state.targetBuildingIds)
    }

    @Test("Fewer than three buildings: the game plays last side standing")
    func needsBuildings() throws {
        let session = try game(.findTheTarget, buildingCount: 2)
        #expect(session.objective == nil)
        #expect(session.play?.objectiveId == nil)
        #expect(ObjectiveRules.sidesToScore(in: session).isEmpty)
    }

    @Test("Roll for it gives Find the Target on a 6 only with buildings")
    func rolls() {
        #expect(ObjectiveId.fromRoll(6) == nil)
        #expect(ObjectiveId.fromRoll(6, hasBuildings: true) == .findTheTarget)
        #expect([1, 2, 3, 4, 5].compactMap { ObjectiveId.fromRoll($0, hasBuildings: true) } == ObjectiveId.built)
    }

    @Test("Searching a target scores 5 once; an empty building and a repeat score nothing")
    func searching() throws {
        var session = try game(.findTheTarget, buildingCount: 4)
        let targets = try #require(session.objectiveState?.targetBuildingIds)
        let empty = try #require(["B1", "B2", "B3", "B4"].first { !targets.contains($0) })
        session = try MatchReducer.reduce(session, .scoreObjective(side: .lanceA, entries: [
            ObjectiveScoreEntry(kind: .searched, tokenId: targets[0]),
            ObjectiveScoreEntry(kind: .searched, tokenId: empty)
        ]))
        #expect(session.points(of: .lanceA) == 5)
        #expect(session.objectiveState?.foundTargets[targets[0]] == .lanceA)
        #expect(ObjectiveRules.searchableBuildings(in: session).map(\.id).contains(targets[0]) == false)
        // Side B searches the found one: already taken.
        session = try MatchReducer.reduce(session, .scoreObjective(side: .lanceB, entries: [
            ObjectiveScoreEntry(kind: .searched, tokenId: targets[0])
        ]))
        #expect(session.points(of: .lanceB) == 0)
    }

    @Test("Two targets make 10 and win")
    func winsAtTen() throws {
        var session = try game(.findTheTarget, buildingCount: 3)
        let targets = try #require(session.objectiveState?.targetBuildingIds)
        session = try MatchReducer.reduce(session, .scoreObjective(side: .lanceA, entries: targets.prefix(2).map {
            ObjectiveScoreEntry(kind: .searched, tokenId: $0)
        }))
        #expect(session.points(of: .lanceA) == 10)
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == .winner(.lanceA))
    }

    @Test("A building that isn't on the table is refused")
    func unknownBuilding() throws {
        let session = try game(.findTheTarget, buildingCount: 3)
        #expect(throws: (any Error).self) {
            try MatchReducer.reduce(session, .scoreObjective(side: .lanceA, entries: [ObjectiveScoreEntry(kind: .searched, tokenId: "B9")]))
        }
    }

    @Test("Find the Target asks every turn, from Turn 1")
    func asks() {
        #expect(ObjectiveRules.asksQuestions(.findTheTarget, turn: 1))
    }
}

@Suite("PM11 per-side objectives")
struct PerSideObjectiveTests {
    @Test("Each side plays its own objective and the shared one reads nil")
    func own() throws {
        let session = try game(perSide: [.lanceA: .controlTheField, .lanceB: .breakthrough])
        #expect(session.objective == nil)
        #expect(session.hasObjective)
        #expect(session.hasPerSideObjectives)
        #expect(session.objective(for: .lanceA) == .controlTheField)
        #expect(session.objective(for: .lanceB) == .breakthrough)
        #expect(ObjectiveRules.sidesToScore(in: session) == [.lanceA, .lanceB])
    }

    @Test("A side missing an objective clears the lot")
    func incomplete() throws {
        let session = try game(perSide: [.lanceA: .controlTheField])
        #expect(!session.hasPerSideObjectives)
        #expect(session.play?.sideObjectives.isEmpty == true)
    }

    @Test("Each side scores by its own objective")
    func scoring() throws {
        var session = try game(perSide: [.lanceA: .controlTheField, .lanceB: .breakthrough])
        session = try MatchReducer.reduce(session, .scoreObjective(side: .lanceA, entries: [
            ObjectiveScoreEntry(kind: .inPosition, unitId: unitId(session, "A0"))
        ]))
        session = try MatchReducer.reduce(session, .scoreObjective(side: .lanceB, entries: [
            ObjectiveScoreEntry(kind: .exited, unitId: unitId(session, "B0"))
        ]))
        #expect(session.points(of: .lanceA) == 2)
        #expect(session.points(of: .lanceB) == 2)
        // Side A can't answer Breakthrough: its objective is Control the Field.
        #expect(session.units.first { $0.name == "B0" }?.leftTable == true)
    }

    @Test("A side wins when it reaches its own threshold")
    func threshold() throws {
        var session = try game(perSide: [.lanceA: .controlTheField, .lanceB: .raid])
        session.victoryPoints[.lanceA] = 10
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == .winner(.lanceA))
        session.victoryPoints[.lanceA] = 9
        #expect(VictoryEvaluator.evaluateAfterEnd(session: session) == nil)
    }

    @Test("Raid tokens go out for every side when any side plays Raid; Hold the Fort tokens have their own ids")
    func tokens() throws {
        let raid = try game(perSide: [.lanceA: .raid, .lanceB: .controlTheField])
        #expect(raid.objectiveState?.tokens.count == 6)
        #expect(Set(raid.objectiveState?.tokens.compactMap(\.objective) ?? []) == [.raid])
        let mixed = try game(perSide: [.lanceA: .raid, .lanceB: .holdTheFort])
        let ids = mixed.objectiveState?.tokens.map(\.id) ?? []
        #expect(ids.count == Set(ids).count)
        #expect(ids.contains("BH1") && ids.contains("A1"))
        #expect(ObjectiveRules.holdTokens(of: .lanceB, in: mixed).count == 2)
        #expect(ObjectiveRules.holdTokens(of: .lanceA, in: mixed).isEmpty)
        // A Raid side only takes Raid tokens, never Hold the Fort ones.
        #expect(ObjectiveRules.availableTokens(for: .lanceA, in: mixed).allSatisfy { $0.objective == .raid })
    }

    @Test("Destroy the Enemy banks kills only for sides that play it")
    func destroyOnlyForThatSide() throws {
        var session = try game(perSide: [.lanceA: .destroyTheEnemy, .lanceB: .controlTheField])
        // A downs a B 'Mech and B downs an A 'Mech in the same turn.
        let b = session.units.firstIndex { $0.name == "B0" }!
        let a = session.units.firstIndex { $0.name == "A0" }!
        session.units[b].structureDamage = session.units[b].structureCap
        session.units[b].combatStatus = .destroyedPendingEnd
        session.units[b].downedBy = .lanceA
        session.units[a].structureDamage = session.units[a].structureCap
        session.units[a].combatStatus = .destroyedPendingEnd
        session.units[a].downedBy = .lanceB
        session = try MatchReducer.reduce(session, .scoreObjective(side: .lanceB, entries: []))
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.points(of: .lanceA) == 2)
        #expect(session.points(of: .lanceB) == 0)
    }

    @Test("Old saves: no per-side field, no card fields")
    func oldSaves() throws {
        let setup = try JSONDecoder().decode(PlaySetup.self, from: Data("{}".utf8))
        #expect(setup.sideObjectives.isEmpty)
        #expect(!setup.rules.mechWarriorCards)
        let round = try JSONDecoder().decode(PlaySetup.self, from: JSONEncoder().encode(PlaySetup.pickup()))
        #expect(round == PlaySetup.pickup())
        let rules = try JSONDecoder().decode(PlayRules.self, from: Data(#"{"overheat":true}"#.utf8))
        #expect(!rules.mechWarriorCards)
    }

    @Test("A per-side setup survives encoding")
    func roundTrip() throws {
        var setup = PlaySetup.pickup()
        setup.setObjective(.raid, for: .lanceA)
        setup.setObjective(.findTheTarget, for: .lanceB)
        let back = try JSONDecoder().decode(PlaySetup.self, from: JSONEncoder().encode(setup))
        #expect(back.objectiveId(for: .lanceB) == .findTheTarget)
        #expect(back.perSideObjectives)
    }
}

@Suite("PM11 MechWarrior cards")
struct MechWarriorCardTests {
    private func pick(_ name: String, base: Int = 30, skill: Int = 4, clan: Bool = false) -> ForcePick {
        ForcePick(cardId: name, name: name, basePV: base, size: 2, skill: skill, isClan: clan)
    }

    @Test("One card per side: giving it to another 'Mech takes it off the first")
    func oneCard() {
        var setup = PlaySetup.pickup()
        setup.rules.mechWarriorCards = true
        let first = pick("Atlas"), second = pick("Locust")
        setup.forces[.lanceA] = [first, second]
        PlayCards.setCard("Kell", on: first.id, side: .lanceA, in: &setup)
        PlayCards.setCard("Vance", on: second.id, side: .lanceA, in: &setup)
        #expect(setup.force(.lanceA).map(\.pilotName) == [nil, "Vance"])
        PlayCards.setCard(nil, on: second.id, side: .lanceA, in: &setup)
        #expect(PlayCards.card(of: .lanceA, in: setup) == nil)
    }

    @Test("A card may go below the setup's best skill; without cards the range is unchanged")
    func range() {
        var setup = PlaySetup.pickup()
        setup.minimumSkill = 3
        var carded = pick("Atlas")
        #expect(PlayUnits.skillRange(for: carded, setup: setup) == 3...4)
        setup.rules.mechWarriorCards = true
        carded.pilotName = "Kell"
        #expect(PlayUnits.skillRange(for: carded, setup: setup) == 0...4)
        #expect(PlayUnits.skillRange(for: pick("Locust"), setup: setup) == 3...4)
    }

    @Test("Cost is the PV above the card skill; the opponent improves by the same amount")
    func cost() {
        var atlas = pick("Atlas", base: 40)
        atlas.skill = 2
        #expect(PlayCards.improvement(atlas) == 2)
        #expect(PlayCards.cost(atlas) == atlas.adjustedPV - 40)
        #expect(PlayCards.cost(atlas) > 0)
        var clan = pick("Timber Wolf", base: 40, skill: 2, clan: true)
        #expect(PlayCards.improvement(clan) == 1)
        clan.skill = 3
        #expect(PlayCards.cost(clan) == 0)
    }

    @Test("The review warns about missing and unequal cards")
    func warnings() {
        var setup = PlaySetup.pickup()
        #expect(PlayCards.warnings(setup: setup).isEmpty)
        setup.rules.mechWarriorCards = true
        #expect(PlayCards.warnings(setup: setup).count == 1)
        var a = pick("Atlas"), b = pick("Locust")
        a.skill = 2
        a.pilotName = "Kell"
        b.skill = 3
        b.pilotName = "Vance"
        setup.forces[.lanceA] = [a]
        setup.forces[.lanceB] = [b]
        #expect(PlayCards.warnings(setup: setup).count == 1)
        #expect(PlayCards.warnings(setup: setup)[0].contains("different"))
        setup.forces[.lanceB] = [pick("Locust", skill: 3)]
        #expect(PlayCards.warnings(setup: setup).contains { $0.contains("has none") })
    }

    @Test("Cards off: a stray pilot name never reaches the game")
    func ignoredWhenOff() throws {
        var setup = PlaySetup.pickup()
        var a = pick("Atlas")
        a.pilotName = "Kell"
        setup.forces[.lanceA] = [a]
        #expect(PlayCards.card(of: .lanceA, in: setup) == nil)
        #expect(PlayCards.warnings(setup: setup).isEmpty)
    }
}
