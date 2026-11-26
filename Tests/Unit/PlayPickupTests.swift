// PM4: 1 v 1 pickup game (PlayModeSpec § 5, § 7.3, § 7.4, § 11, § 20).
import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

private func pick(_ pv: Int, skill: Int = 4, size: Int = 2, clan: Bool = false) -> ForcePick {
    ForcePick(cardId: "x", name: "Test \(pv)", basePV: pv, size: size, skill: skill, isClan: clan)
}

private final class PlayPickupBundleToken {}

private var catalog: BundleContentCatalogRepository {
    BundleContentCatalogRepository(bundle: Bundle(for: PlayPickupBundleToken.self))
}

private func library() throws -> CardLibrary {
    CardLibrary(try catalog.cardLibrary())
}

@Suite("Play pickup: PV and budget")
struct PlayBudgetTests {
    @Test("Skill 2 in a 39 PV 'Mech is 55 PV, and the side total includes it")
    func bookExample() {
        var setup = PlaySetup.pickup()
        setup.forces[.lanceA] = [pick(39, skill: 2), pick(20)]
        #expect(setup.force(.lanceA)[0].adjustedPV == 55)
        #expect(setup.totalPV(.lanceA) == 75)
    }

    @Test("Under, exact and over a PV budget")
    func pvBudget() {
        #expect(BudgetCheck.evaluate(.pointValue(50), picks: [pick(30)]).text == "20 PV left")
        #expect(BudgetCheck.evaluate(.pointValue(30), picks: [pick(30)]).status == .exact)
        let over = BudgetCheck.evaluate(.pointValue(25), picks: [pick(30)])
        #expect(over.isOver && over.text == "5 PV over")
    }

    @Test("Count budget with a Size cap")
    func countBudget() {
        let picks = [pick(10, size: 4), pick(10, size: 4), pick(10, size: 4)]
        #expect(BudgetCheck.evaluate(.count(units: 3, sizeCap: nil), picks: picks).status == .exact)
        #expect(BudgetCheck.evaluate(.count(units: 3, sizeCap: 11), picks: picks).isOver)
        #expect(BudgetCheck.evaluate(.count(units: 4, sizeCap: 12), picks: picks).text == "1 ’Mech left")
    }

    @Test("Default budgets by sides (D5)")
    func defaults() {
        #expect(ForceBudget.defaultPV(sides: 2) == 250)
        #expect(ForceBudget.defaultPV(sides: 3) == 200)
        #expect(ForceBudget.defaultPV(sides: 4) == 150)
    }

    @Test("Skill range: card skill down to the best skill; Clan starts at 3; never worse than 4")
    func skillRange() {
        var setup = PlaySetup.pickup()
        #expect(PlayUnits.skillRange(for: pick(30), setup: setup) == 2...4)
        #expect(PlayUnits.skillRange(for: pick(30, skill: 3, clan: true), setup: setup) == 2...4)
        setup.allowImprovedSkills = false
        #expect(PlayUnits.skillRange(for: pick(30), setup: setup) == 4...4)
        #expect(PlayUnits.skillRange(for: pick(30, skill: 3, clan: true), setup: setup) == 3...3)
        setup.forces[.lanceA] = [pick(30, skill: 2)]
        PlayUnits.resetSkills(&setup)
        #expect(setup.force(.lanceA)[0].skill == 4)
    }
}

@Suite("Play pickup: forces from the card library")
struct PlayForcesTests {
    @Test("Checked faces make picks at card skill; unchecked faces can't be picked")
    func picks() throws {
        let lib = try library()
        let clan = try #require(lib.checkedFaces.first { $0.techBase == .clan })
        let clanPick = try #require(PlayUnits.pick(clan))
        #expect(clanPick.skill == 3)
        #expect(clanPick.adjustedPV > clan.pv!)
        let unchecked = try #require(lib.faces.first { !$0.isChecked })
        #expect(PlayUnits.pick(unchecked) == nil)
    }

    @Test("Units are built per side with the pick's skill")
    func units() throws {
        let lib = try library()
        var setup = PlaySetup.pickup()
        let locust = try #require(lib.face(id: "locust-lct-7v").flatMap(PlayUnits.pick))
        var better = locust
        better.skill = 2
        setup.forces[.lanceA] = [better]
        setup.forces[.lanceB] = [locust, locust]
        let units = PlayUnits.make(setup: setup, library: lib)
        #expect(units.count == 3)
        #expect(units.filter { $0.side == .lanceB }.count == 2)
        #expect(units.first { $0.side == .lanceA }?.skill == 2)
    }

    @Test("Switching face keeps id and skill")
    func switchFace() throws {
        let lib = try library()
        let wasp = try #require(lib.face(id: "wasp-wsp-5a").flatMap(PlayUnits.pick))
        var picked = wasp
        picked.skill = 3
        let other = try #require(lib.face(id: "locust-lct-7v"))
        let switched = try #require(PlayUnits.switchFace(picked, to: other))
        #expect(switched.id == picked.id && switched.skill == 3 && switched.cardId == "locust-lct-7v")
    }

    @Test("Owned chassis list faces and count minis left after picks")
    func owned() throws {
        let lib = try library()
        let boxes = try catalog.boxSets().boxes
        let collection = OwnedCollection(boxes: ["alpha-strike-box": 1])
        let owned = PlayPicker.ownedChassis(collection: collection, boxes: boxes, library: lib)
        let locust = try #require(owned.first { $0.chassis == "Locust" })
        #expect(locust.faces.count >= 2)
        var setup = PlaySetup.pickup()
        setup.forces[.lanceA] = [try #require(lib.face(id: "locust-lct-7v").flatMap(PlayUnits.pick))]
        #expect(PlayPicker.left(of: "Locust", owned: locust.owned, setup: setup) == locust.owned - 1)
    }
}

@Suite("Play pickup: battlefield")
struct PlayBattlefieldTests {
    @Test("Mapsheet arrangements give the table size")
    func sizes() {
        #expect(Battlefield(kind: .mapsheets, arrangement: .pair).width == 22)
        #expect(Battlefield(kind: .mapsheets, arrangement: .pair).depth == 34)
        #expect(Battlefield(kind: .mapsheets, arrangement: .threeByTwo).width == 66)
        #expect(Battlefield(kind: .mat, matWidth: 72, matDepth: 48).width == 72)
    }

    @Test("Layout has one zone per side on its home edge and a rect per sheet")
    func layout() {
        let field = Battlefield(kind: .mapsheets, arrangement: .twoByTwo, sheets: ["A", "B", "C", "D"])
        let layout = PlayLayout.layout(for: field)
        #expect(layout.sheets.count == 4)
        #expect(layout.zones.map(\.side) == ["A", "B"])
        #expect(layout.zones[0].area.x == 0)
        #expect(layout.zones[1].area.maxX == layout.width)
    }

    @Test("Small tables are flagged")
    func advice() {
        #expect(Battlefield(kind: .mat, matWidth: 30, matDepth: 30).advice(sides: 2, budgetPV: 250) != nil)
        #expect(Battlefield(kind: .mat, matWidth: 48, matDepth: 36).advice(sides: 2, budgetPV: 250) == nil)
    }
}

@Suite("Play pickup: game")
struct PlayGameTests {
    private func started(_ a: [MatchUnitState], _ b: [MatchUnitState], turnLimit: Int? = nil) throws -> MatchSession {
        var setup = PlaySetup.pickup()
        setup.sides[1].name = "Raiders"
        setup.turnLimit = turnLimit
        return try MatchReducer.reduce(MatchSession(ruleset: setup.ruleset), .startPlay(setup: setup, units: a + b))
    }

    private func unit(_ side: SideId, pv: Int = 20, skill: Int = 4) -> MatchUnitState {
        MatchUnitState(name: "U", side: side, skill: skill, pv: pv, sz: 2, mv: "10\"", tmm: 2,
                       s: 2, m: 2, l: 1, ov: 0, armorCap: 4, structureCap: 4, abilities: "")
    }

    @Test("startPlay makes a Play session with the setup's sides, dice and rules")
    func start() throws {
        let session = try started([unit(.lanceA)], [unit(.lanceB)])
        #expect(session.isPlayGame && session.scenarioId == nil)
        #expect(session.displayName(of: .lanceB) == "Raiders")
        #expect(session.ruleset.forcedWithdrawal && session.ruleset.overheatAllowed)
        #expect(!session.tableReady && session.status == .active)
    }

    @Test("All of Side B destroyed: Side A wins, then Side B in the standings")
    func wipe() throws {
        var session = try started([unit(.lanceA)], [unit(.lanceB)])
        session.units[1].combatStatus = .destroyedPendingEnd
        session.phase = .end
        let ended = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(ended.outcome == .winner(.lanceA))
        #expect(VictoryEvaluator.standings(in: ended) == [.lanceA, .lanceB])
    }

    @Test("Turn limit: most PV left wins; equal PV is a draw")
    func turnLimit() throws {
        var session = try started([unit(.lanceA, pv: 20)], [unit(.lanceB, pv: 20, skill: 3)], turnLimit: 6)
        session.turn = 6
        session.phase = .end
        let ended = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(ended.outcome == .winner(.lanceB))
        #expect(VictoryEvaluator.standings(in: ended).first == .lanceB)

        var level = try started([unit(.lanceA)], [unit(.lanceB)], turnLimit: 6)
        level.turn = 6
        level.phase = .end
        #expect(try MatchReducer.reduce(level, .resolveEndPhase).outcome == .draw)
    }

    @Test("Setup draft round-trips and is cleared")
    func draftStore() throws {
        let defaults = try #require(UserDefaults(suiteName: "play-pickup-tests"))
        defaults.removePersistentDomain(forName: "play-pickup-tests")
        var setup = PlaySetup.pickup()
        setup.forces[.lanceA] = [pick(25)]
        PlaySetupStore.save(setup, key: PlaySetupStore.draftKey, to: defaults)
        #expect(PlaySetupStore.load(PlaySetupStore.draftKey, from: defaults) == setup)
        PlaySetupStore.save(nil, key: PlaySetupStore.draftKey, to: defaults)
        #expect(PlaySetupStore.load(PlaySetupStore.draftKey, from: defaults) == nil)
    }
}
