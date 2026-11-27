// Seams between PM5–PM13 features: boards + buildings + Find the Target, per-side objectives with 3–4 sides and
// teams, saved forces with hand-entered and MechWarrior cards, release flags in any combination, board "changed since".
import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

private func mech(_ name: String, _ side: SideId) -> MatchUnitState {
    MatchUnitState(name: name, side: side, pv: 20, sz: 2, mv: "6\"", tmm: 1, s: 3, m: 3, l: 3, ov: 0, armorCap: 4, structureCap: 4)
}

private func buildings(_ count: Int) -> [BuildingState] {
    (1...count).map { BuildingState(id: "B\($0)", name: "Building \($0)", type: .medium) }
}

private func units(_ setup: PlaySetup) -> [MatchUnitState] {
    setup.sides.flatMap { [mech("\($0.id.letter)0", $0.id), mech("\($0.id.letter)1", $0.id)] }
}

private func start(_ setup: PlaySetup) throws -> MatchSession {
    try MatchReducer.reduce(MatchSession(ruleset: setup.ruleset), .startPlay(setup: setup, units: units(setup)))
}

private func board(_ pieces: Int = 3, name: String = "Home table") -> BoardLayout {
    var board = BoardLayout(width: 48, depth: 48)
    for index in 0..<pieces {
        board.features.append(.init(kind: index == 0 ? .building : .woods, area: .init(x: 10 + Double(index) * 7, y: 20, width: 5, depth: 5)))
    }
    board.name = name
    return board.assigningIDs()
}

@Suite("Polish: objectives across sides, teams and buildings")
struct ObjectiveSeamTests {
    @Test("Four sides, each with its own objective, a board and three buildings: every piece lines up")
    func fourSidesBoardBuildingsFindTarget() throws {
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 1, 1, 1])
        setup.battlefield.board = board()
        setup.rules.buildings = buildings(3)
        setup.setObjective(.findTheTarget, for: .lanceA)
        setup.setObjective(.raid, for: .lanceB)
        setup.setObjective(.holdTheFort, for: .lanceC)
        setup.setObjective(.destroyTheEnemy, for: .lanceD)

        let session = try start(setup)
        let state = try #require(session.objectiveState)
        #expect(session.hasPerSideObjectives)
        #expect(session.objective == nil)
        #expect(state.targetBuildingIds.count == 3)
        // Raid puts tokens out for every side; Hold the Fort only for its side, marked apart from Raid's.
        #expect(state.tokens.filter { $0.objective == .raid }.count == 4 * ObjectiveId.raid.tokensPerSide)
        #expect(state.tokens.filter { $0.objective == .holdTheFort }.allSatisfy { $0.owner == .lanceC })
        #expect(session.boxRules?.buildings.count == 3)
        // The table checklist names the board, each side's own placing step and the briefing keeps all four.
        let steps = PlayLayout.tableSteps(for: setup)
        #expect(steps.contains { $0.contains("terrain piece") || $0.contains("terrain pieces") })
        #expect(steps.contains { $0.contains("Side C objective") || $0.contains("Side C") })
        #expect(PlayLayout.winningSummary(for: setup).contains("Side D"))
        // Four sides on a board: the zones are generated for four, none overlapping.
        let table = PlayLayout.board(for: setup.battlefield, sides: setup.sides)
        #expect(table.zones.count == 4)
    }

    @Test("Teams (1 v 3) keep per-side objectives per side, not per player")
    func teamsAreOneSide() throws {
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 3])
        setup.setObjective(.raid, for: .lanceA)
        setup.setObjective(.breakthrough, for: .lanceB)
        let session = try start(setup)
        #expect(session.sideIds.count == 2)
        #expect(session.objective(for: .lanceA) == .raid)
        #expect(session.objective(for: .lanceB) == .breakthrough)
        #expect(setup.formatName == "1 v 3")
    }

    @Test("Dropping sides drops their objectives; adding one leaves it unrolled, and starting plays on")
    func resizingKeepsObjectivesHonest() throws {
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 1, 1, 1])
        for side in setup.sides { setup.setObjective(.raid, for: side.id) }
        setup.setPlayerCounts([1, 1])
        #expect(Set(setup.sideObjectives.keys) == [SideId.lanceA.rawValue, SideId.lanceB.rawValue])

        setup.setPlayerCounts([1, 1, 1])
        #expect(setup.objectiveId(for: .lanceC) == nil)
        let session = try start(setup)
        // Not every side rolled: the game plays on with the shared objective (none here) rather than half a set.
        #expect(session.hasPerSideObjectives == false)
        #expect(session.objective == nil)
    }

    @Test("Buildings taken away after Find the Target was rolled for a side: nobody keeps half a set")
    func buildingsRemoved() throws {
        var setup = PlaySetup.pickup()
        setup.rules.buildings = buildings(2)
        setup.setObjective(.findTheTarget, for: .lanceA)
        setup.setObjective(.raid, for: .lanceB)
        let session = try start(setup)
        #expect(session.play?.sideObjectives.isEmpty == true)
        #expect(session.objectiveState?.targetBuildingIds.isEmpty ?? true)
    }
}

@Suite("Polish: release flags in any combination")
struct FlagSeamTests {
    private func fullSetup() -> PlaySetup {
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 1, 2])
        setup.battlefield.board = board()
        setup.rules.buildings = buildings(3)
        setup.rules.mechWarriorCards = true
        setup.setObjective(.findTheTarget, for: .lanceA)
        setup.setObjective(.raid, for: .lanceB)
        setup.setObjective(.holdTheFort, for: .lanceC)
        return setup
    }

    @Test("Objectives off strips every objective; boards off strips the board; everything else stays")
    func limiting() {
        let full = fullSetup()
        let noObjectives = full.limited(objectives: false, boards: true)
        #expect(noObjectives.objective == nil && noObjectives.sideObjectives.isEmpty)
        #expect(noObjectives.battlefield.board != nil)
        let noBoards = full.limited(objectives: true, boards: false)
        #expect(noBoards.battlefield.board == nil)
        #expect(noBoards.sideObjectives == full.sideObjectives)
        let neither = full.limited(objectives: false, boards: false)
        #expect(neither.sides == full.sides && neither.rules == full.rules && neither.forces == full.forces)
        #expect(full.limited(objectives: true, boards: true) == full)
    }

    @Test("A game starts, reads and re-encodes with every objectives × boards combination")
    func everyCombination() throws {
        for objectives in [false, true] {
            for boards in [false, true] {
                let setup = fullSetup().limited(objectives: objectives, boards: boards)
                let session = try start(setup)
                #expect(session.hasObjective == objectives)
                #expect(session.play?.battlefield.board == nil || boards)
                let decoded = try JSONDecoder().decode(MatchSession.self, from: JSONEncoder().encode(session))
                #expect(decoded.play == session.play)
                #expect(!PlayLayout.tableSteps(for: setup).isEmpty)
                #expect(!PlayLayout.winningSummary(for: setup).isEmpty)
                #expect(PlayLayout.board(for: setup.battlefield, sides: setup.sides).zones.count == 3)
            }
        }
    }
}

@Suite("Polish: saved forces with hand-entered and MechWarrior cards")
struct SavedForceSeamTests {
    private func userFace() throws -> CardFaceDTO {
        var d = UserCardDraft()
        d.name = "Raven RVN-3L"
        d.pv = "28"
        d.size = 1
        d.move = "6"
        d.tmm = "2"
        d.short = "2"
        d.medium = "1"
        d.long = "0"
        d.overheat = "0"
        d.armor = "3"
        d.structure = "3"
        return try #require(d.makeFace())
    }

    private func carded(_ face: CardFaceDTO) -> SavedForce {
        var pilot = PlayUnits.pick(face)!
        pilot.skill = 1
        pilot.pilotName = "Kai"
        let other = PlayUnits.pick(face)!
        return SavedForce(name: "Strike", picks: [pilot, other], cards: [face])
    }

    @Test("A force with a hand-entered card and a MechWarrior card loads into side D of a four-side game and plays")
    func loadsIntoFourSideGame() throws {
        let face = try userFace()
        let library = CardLibrary(CardLibraryDTO(contentVersion: "t", cards: []), userCards: [face])
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 1, 1, 1])
        setup.rules.mechWarriorCards = true
        let result = SavedForces.load(carded(face), into: &setup, side: .lanceD, library: library)
        #expect(result == .init(added: 2, skipped: 0))
        let picks = setup.force(.lanceD)
        #expect(picks.filter { $0.pilotName != nil }.count == 1)
        #expect(picks.first { $0.pilotName != nil }?.skill == 1)

        let made = PlayUnits.make(setup: setup, library: library)
        #expect(made.count == 2)
        #expect(made.allSatisfy { $0.side == .lanceD })
        #expect(made.filter { $0.pilotName == "Kai" }.count == 1)
    }

    @Test("MechWarrior cards off: the pilot doesn't come along, and the skill is the setup's own")
    func cardsOffDropsPilot() throws {
        let face = try userFace()
        let library = CardLibrary(CardLibraryDTO(contentVersion: "t", cards: []), userCards: [face])
        var setup = PlaySetup.pickup()
        setup.rules.mechWarriorCards = false
        SavedForces.load(carded(face), into: &setup, side: .lanceA, library: library)
        #expect(setup.force(.lanceA).allSatisfy { $0.pilotName == nil })
        #expect(setup.force(.lanceA).allSatisfy { PlayUnits.skillRange(for: $0, setup: setup).contains($0.skill) })
    }

    @Test("A saved force can't be loaded past the per-game cap")
    func gameCap() throws {
        let face = try userFace()
        let library = CardLibrary(CardLibraryDTO(contentVersion: "t", cards: []), userCards: [face])
        var setup = PlaySetup.pickup()
        setup.setPlayerCounts([1, 1, 1, 1])
        let filler = PlayUnits.pick(face)!
        for side in [SideId.lanceA, .lanceB] { setup.forces[side] = Array(repeating: filler, count: PlaySetup.maxUnitsPerSide) }
        setup.forces[.lanceC] = Array(repeating: filler, count: 3)
        let force = SavedForce(name: "Big", picks: Array(repeating: filler, count: 5), cards: [face])
        let result = SavedForces.load(force, into: &setup, side: .lanceD, library: library)
        #expect(result.added == 1)
        #expect(result.skipped == 4)
        #expect(setup.unitCount == PlaySetup.maxUnitsPerGame)
    }
}

@Suite("Polish: board changed since a setup")
struct BoardChangedSinceTests {
    @Test("A setup's board copy notices a newer save, and stops noticing once it takes the new version")
    func newerVersion() throws {
        var saved = board()
        saved.id = UUID()
        saved.updatedAt = Date(timeIntervalSince1970: 1_000)
        var setup = PlaySetup.pickup()
        setup.battlefield.board = BoardPresets.copyForSetup(saved, now: Date(timeIntervalSince1970: 2_000))
        #expect(setup.battlefield.board?.presetID == saved.id)
        #expect(BoardPresets.newerVersion(of: setup.battlefield.board!, in: [saved]) == nil)

        saved.updatedAt = Date(timeIntervalSince1970: 3_000)
        let newer = try #require(BoardPresets.newerVersion(of: setup.battlefield.board!, in: [saved]))
        setup.battlefield.board = BoardPresets.copyForSetup(newer)
        #expect(BoardPresets.newerVersion(of: setup.battlefield.board!, in: [saved]) == nil)

        // The saved board deleted, or the boards switched off: no note, no crash.
        #expect(BoardPresets.newerVersion(of: setup.battlefield.board!, in: []) == nil)
        #expect(setup.limited(objectives: true, boards: false).battlefield.board == nil)
    }
}
