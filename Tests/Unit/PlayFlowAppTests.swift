// Rules behind the Play and Learn screens: the mission ladder, the setup flow's footer rules, the Rules tab
// grouping, the board builder's model and the coordinator that opens a game.
import Foundation
import SwiftData
import Testing
import MechBuddyData
import MechBuddyDomain
@testable import MechBuddy

// MARK: - Mission ladder

@MainActor
@Suite("Mission ladder")
struct MissionLadderModelTests {
    private func item(_ id: String, number: Int, gated: Bool = false, stage: String? = nil, icon: String? = nil) throws -> ScenarioCatalogItemDTO {
        let json = """
        {"id":"\(id)","title":"Mission \(id)","missionNumber":\(number),"gated":\(gated),"introduces":["Rule \(id)"],
         "comingSoonSummary":"later"\(stage.map { ",\"stage\":\"\($0)\"" } ?? "")\(icon.map { ",\"icon\":\"\($0)\"" } ?? "")}
        """
        return try JSONDecoder().decode(ScenarioCatalogItemDTO.self, from: Data(json.utf8))
    }

    private func mission(_ id: String, number: Int? = nil, minutes: Int? = nil, subtitle: String? = nil, a: Int = 2, b: Int = 2) throws -> GuidedScenarioDTO {
        let unit = #"{"name":"X","pv":10,"mv":"8\"","tmm":1,"sz":1,"s":1,"m":1,"l":0,"ov":0,"armor":2,"structure":2,"skill":4,"abilities":""}"#
        let json = """
        {"schemaVersion":1,"contentVersion":"t","scenarioId":"\(id)","title":"Pack \(id)",
         \(subtitle.map { "\"subtitle\":\"\($0)\"," } ?? "")\(number.map { "\"missionNumber\":\($0)," } ?? "")\(minutes.map { "\"estimatedMinutes\":\($0)," } ?? "")
         "tableSteps":[],"ruleset":{"overheatAllowed":false,"physicalAttacksAllowed":false,"forcedWithdrawal":false,"victory":{"type":"destroyAllEnemies"}},
         "sides":{"lanceA":[\(Array(repeating: unit, count: a).joined(separator: ","))],"lanceB":[\(Array(repeating: unit, count: b).joined(separator: ","))]}}
        """
        return try JSONDecoder().decode(GuidedScenarioDTO.self, from: Data(json.utf8))
    }

    private func ladder(completed: Set<String> = [], ridgeLine: Bool = true) throws -> MissionLadder {
        let items = [
            try item("one", number: 1),
            try item("two", number: 2),
            try item("three", number: 3, gated: true),
            try item("book", number: 4, stage: "From the box", icon: "book"),
            try item("book2", number: 5, stage: "From the box")
        ]
        let packs = [
            "one": try mission("one", number: 1),
            "two": try mission("two", number: 2, minutes: 15),
            "book": try mission("book", number: 4)
        ]
        return MissionLadder(items: items, missions: packs, completed: completed, ridgeLineEnabled: ridgeLine)
    }

    @Test("The featured mission is the first one not finished, else the last playable one")
    func featured() throws {
        #expect(try ladder().featured?.scenarioId == "one")
        #expect(try ladder(completed: ["one"]).featured?.scenarioId == "two")
        #expect(try ladder(completed: ["one", "two", "book"]).featured?.scenarioId == "book")
        #expect(try ladder(ridgeLine: false).featured == nil)
        #expect(try ladder().playable.map(\.scenarioId) == ["one", "two", "book"])
    }

    @Test("Stops are cleared, next, open or locked; gated and pack-less missions are locked")
    func stops() throws {
        let model = try ladder(completed: ["one"])
        #expect(model.training.map(\.id) == ["one", "two", "three"])
        #expect(model.stops.map(\.state) == [.cleared, .next, .locked])
        #expect(model.stops.map(\.label) == ["Mission 1", "Mission 2", "Mission 3"])
        #expect(model.stops[2].comingSoon == "later" && model.stops[0].unlocks == ["Rule one"] && model.stops[0].icon == "scope")
        let later = model.stops(for: model.staged[0].items)
        // "book" has a pack, "book2" doesn't. The next mission is on the training path, so "book" is only open.
        #expect(later.map(\.state) == [.open, .locked])
        #expect(later.map(\.label) == ["From the box", "From the box"])
        #expect(later[0].icon == "book")
        #expect(MissionStop(id: "x", number: 1, title: "x", icon: "x", unlocks: [], state: .next).statusText == "Up next")
        #expect([MissionStop.State.cleared, .open, .locked].map { MissionStop(id: "x", number: 1, title: "x", icon: "x", unlocks: [], state: $0).statusText }
                == ["Cleared", "Ready", "Coming soon"])
    }

    @Test("Later sections group by stage in catalog order")
    func staged() throws {
        let model = try ladder()
        #expect(model.staged.map(\.title) == ["From the box"])
        #expect(model.staged[0].items.map(\.id) == ["book", "book2"])
    }

    @Test("Eyebrow: stage name, 'Beginner mission' for the first, else 'Mission n of total'")
    func eyebrow() throws {
        let model = try ladder()
        #expect(model.eyebrow(for: try mission("one", number: 1)) == "Beginner mission")
        #expect(model.eyebrow(for: try mission("two", number: 2)) == "Mission 2 of 3")
        #expect(model.eyebrow(for: try mission("book", number: 4)) == "From the box")
        #expect(model.eyebrow(for: try mission("zzz", number: 9)) == "Mission 9 of 9")
        #expect(model.eyebrow(for: try mission("zzz")) == "Beginner mission")
    }

    @Test("Subtitle: force size with minutes, else the pack's subtitle, else the force size")
    func subtitle() throws {
        #expect(MissionLadder.subtitle(for: try mission("a", minutes: 20, a: 4, b: 3)) == "4 vs 3 · about 20 minutes")
        #expect(MissionLadder.subtitle(for: try mission("a", subtitle: "Learn to shoot")) == "Learn to shoot")
        #expect(MissionLadder.subtitle(for: try mission("a", a: 1, b: 2)) == "1 vs 2")
    }

    @Test("A mission's name comes from its pack, then the catalog, then Ridge Line")
    func titles() throws {
        let model = try ladder()
        #expect(model.title(for: ScenarioId(rawValue: "one")) == "Pack one")
        #expect(model.title(for: ScenarioId(rawValue: "three")) == "Mission three")
        #expect(model.title(for: ScenarioId(rawValue: "unknown")) == "Ridge Line")
        #expect(model.title(for: nil) == "Ridge Line")
    }
}

// MARK: - Setup flow

@MainActor
@Suite("Play setup flow rules")
struct PlaySetupRulesTests {
    private func pick(_ pv: Int = 30) -> ForcePick {
        ForcePick(cardId: "x", name: "X", basePV: pv, size: 2, skill: 4, isClan: false)
    }

    private func fullSetup() -> PlaySetup {
        var setup = PlaySetup.pickup()
        setup.forces[.lanceA] = [pick()]
        setup.forces[.lanceB] = [pick()]
        return setup
    }

    @Test("Steps run in order, with titles, ids and no step before the first or after the last")
    func steps() {
        #expect(PlaySetupStep.allCases.count == 6)
        #expect(PlaySetupRules.next(after: .sides) == .size && PlaySetupRules.next(after: .rules) == .review)
        #expect(PlaySetupRules.next(after: .review) == nil && PlaySetupRules.previous(before: .sides) == nil)
        #expect(PlaySetupRules.previous(before: .review) == .rules)
        #expect(Set(PlaySetupStep.allCases.map(\.identifier)).count == 6)
        #expect(PlaySetupStep.allCases.allSatisfy { !$0.title.isEmpty && $0.identifier.hasPrefix("as.play.setup.") })
    }

    @Test("Continue is disabled on Forces until every side has a 'Mech, and on Sides while teams are invalid")
    func continueRules() {
        var setup = PlaySetup.pickup()
        #expect(!PlaySetupRules.isContinueDisabled(step: .sides, setup: setup))
        #expect(PlaySetupRules.isContinueDisabled(step: .forces, setup: setup))
        #expect(!PlaySetupRules.isContinueDisabled(step: .map, setup: setup))
        setup = fullSetup()
        #expect(!PlaySetupRules.isContinueDisabled(step: .forces, setup: setup))
        setup.forces[.lanceB] = []
        #expect(PlaySetupRules.isContinueDisabled(step: .forces, setup: setup))
        setup.sides[0].players = []
        #expect(PlaySetupRules.isContinueDisabled(step: .sides, setup: setup))
    }

    @Test("Start is blocked by team problems first, then an empty side, then too many 'Mechs")
    func startBlocked() {
        var setup = fullSetup()
        #expect(PlaySetupRules.startBlockedReason(for: setup) == nil)
        setup.forces[.lanceB] = []
        #expect(PlaySetupRules.startBlockedReason(for: setup) == "\(setup.sides[1].name) needs at least one ’Mech.")
        setup.forces[.lanceB] = Array(repeating: pick(5), count: PlaySetup.maxUnitsPerGame)
        #expect(PlaySetupRules.startBlockedReason(for: setup) == "Up to \(PlaySetup.maxUnitsPerGame) ’Mechs in one game.")
        setup.sides[0].players = []
        let issue = try! #require(setup.teamIssues.first)
        #expect(PlaySetupRules.startBlockedReason(for: setup) == PlaySidesStep.text(for: issue))
    }

    @Test("Over-budget: the first side over is named, with its words, and none when all are within")
    func overBudget() {
        var setup = fullSetup()
        setup.budget = .pointValue(100)
        #expect(PlaySetupRules.overBudgetSide(in: setup) == nil)
        setup.forces[.lanceB] = [pick(60), pick(60)]
        #expect(PlaySetupRules.overBudgetSide(in: setup) == .lanceB)
        let title = PlaySetupRules.overBudgetTitle(side: .lanceB, in: setup)
        #expect(title == "\(setup.sides[1].name) is \(setup.budgetCheck(.lanceB).text). Play anyway?")
        #expect(title.contains("PV over"))
        #expect(PlaySetupRules.overBudgetTitle(side: nil, in: setup) == "")
    }

    @Test("Starting trims side names and falls back to the default name when blank")
    func readyToStart() {
        var setup = fullSetup()
        setup.sides[0].name = "  Wolves  "
        setup.sides[1].name = "   "
        let ready = PlaySetupRules.readyToStart(setup)
        #expect(ready.sides[0].name == "Wolves" && ready.sides[1].name == "Side B")
        #expect(ready.forces == setup.forces)
    }
}

// MARK: - Rules tab

@MainActor
@Suite("Rules tab grouping")
struct RulesGroupTests {
    private func topic(_ id: String, group: String? = nil, game: RulesGameTag? = nil, summary: String? = nil, body: String = "One. Two.") -> RulesTopicDTO {
        RulesTopicDTO(id: id, title: id, summary: summary, group: group, game: game, sections: [RulesSectionDTO(heading: "h", body: body)])
    }

    @Test("A topic's own group wins; otherwise its id decides, and unknown ids are reference")
    func resolve() {
        #expect(RulesGroup.resolve(topic("x", group: "during")) == .during)
        #expect(RulesGroup.resolve(topic("how-to-play")) == .start && RulesGroup.resolve(topic("turn")) == .start)
        for id in ["movement", "combat", "sator", "damage"] { #expect(RulesGroup.resolve(topic(id)) == .during) }
        #expect(RulesGroup.resolve(topic("heat")) == .reference)
        #expect(RulesGroup.resolve(topic("movement", group: "bogus")) == .during)
        #expect(RulesGroup.allCases.map(\.title) == ["Start here", "During a game", "Quick reference"])
    }

    @Test("Identifiers carry the game key and untagged topics count as Alpha Strike")
    func identifiers() {
        #expect(RulesGroup.identifier(for: topic("turn")) == "rules.as.turn")
        #expect(RulesGroup.identifier(for: topic("turn", game: .classic)) == "rules.classic.turn")
        #expect(RulesGroup.identifier(for: topic("differences", game: .both)) == "rules.both.differences")
    }

    @Test("Symbols ignore the classic- prefix and fall back to a closed book")
    func symbols() {
        #expect(RulesGroup.symbol(for: "movement") == "figure.walk" && RulesGroup.symbol(for: "classic-movement") == "figure.walk")
        #expect(RulesGroup.symbol(for: "how-to-play") == RulesGroup.symbol(for: "about"))
        #expect(RulesGroup.symbol(for: "to-hit") == RulesGroup.symbol(for: "sator"))
        #expect(RulesGroup.symbol(for: "something-new") == "book.closed")
    }

    @Test("The row summary is the topic's own, else the first sentence, else the whole body, else empty")
    func summaries() {
        #expect(RulesGroup.summary(for: topic("a", summary: "  Short and sweet  ")) == "Short and sweet")
        #expect(RulesGroup.summary(for: topic("a", summary: "   ")) == "One.")
        #expect(RulesGroup.summary(for: topic("a", body: "No full stop")) == "No full stop")
        let empty = RulesTopicDTO(id: "e", title: "e", sections: [])
        #expect(RulesGroup.summary(for: empty) == "")
    }

    @Test("Every bundled rules topic lands in a group, has a unique identifier and a non-empty summary")
    func bundledTopics() throws {
        let library = try BundleContentCatalogRepository(bundle: .main).rulesLibrary()
        let ids = library.allTopics.map(RulesGroup.identifier(for:))
        #expect(Set(ids).count == ids.count)
        for topic in library.allTopics {
            #expect(!RulesGroup.summary(for: topic).isEmpty, "\(topic.id)")
        }
    }
}

// MARK: - Release flags

@Suite("Release surface")
struct ReleaseSurfaceTests {
    @Test("The shipping surface has the first missions and Classic teaser only")
    func shipping() {
        let surface = ReleaseSurface(isFullProductSurface: false)
        for flag in [ReleaseFlag.alphaStrikePlay, .ridgeLineMission, .missionLadder, .classicComingSoonEntry] {
            #expect(surface.isEnabled(flag), "\(flag)")
        }
        for flag in [ReleaseFlag.playMode, .playModeMultiSide, .playObjectives, .playBoards, .fullLancesScenario,
                     .physicalOvWithdrawal, .classicPlayTools, .mulNetworkFetch, .matchHistory, .tipJar] {
            #expect(!surface.isEnabled(flag), "\(flag)")
        }
    }

    @Test("The full surface turns everything on except the tip jar")
    func full() {
        let surface = ReleaseSurface(isFullProductSurface: true)
        for flag in ReleaseFlag.allCases {
            #expect(surface.isEnabled(flag) == (flag != .tipJar), "\(flag)")
        }
    }
}

// MARK: - Board builder model

@MainActor
@Suite("Board editor model")
struct BoardEditorModelTests {
    private func model(sides: [MatchSide] = [], onChange: @escaping (BoardLayout) -> Void = { _ in }) throws -> BoardEditorModel {
        let palette = try BundleContentCatalogRepository(bundle: .main).terrainPalette()
        let board = BoardLayout(width: 48, depth: 48, zones: BoardZones.generate(width: 48, depth: 48, sideCount: 2))
        return BoardEditorModel(board: board, sides: sides, palette: palette, onChange: onChange)
    }

    @Test("Turning a selected sheet through the model, as the canvas and inspector do, undoes and writes through")
    func turnSheetThenUndo() throws {
        var written: [BoardLayout] = []
        let palette = try BundleContentCatalogRepository(bundle: .main).terrainPalette()
        let sheet = BoardLayout.Sheet(name: "Grassland #1", area: .init(x: 0, y: 0, width: 22, depth: 17))
        let board = BoardLayout(width: 48, depth: 48, sheets: [sheet], zones: BoardZones.generate(width: 48, depth: 48, sideCount: 2))
        let model = BoardEditorModel(board: board, sides: [], palette: palette) { written.append($0) }
        model.selectSheet(0)
        model.rotateSheet(0)
        #expect(model.board.sheets[0].rotation == 90 && model.canUndo && written.count == 1)
        model.undo()
        #expect(model.board.sheets[0] == sheet)
        #expect(model.sheetSelection == 0, "Undo keeps the sheet selected")
        #expect(written.count == 2 && written.last?.sheets[0] == sheet)
        model.redo()
        #expect(model.board.sheets[0].rotation == 90)
    }

    @Test("Adding a piece selects it, writes the board through, and can be undone and redone")
    func addUndoRedo() throws {
        var written: [BoardLayout] = []
        let model = try model { written.append($0) }
        let woods = try #require(model.palette.item("woods"))
        model.add(woods)
        let id = try #require(model.selection)
        #expect(model.board.features.count == 1 && written.count == 1)
        #expect(model.selected?.id == id && model.selectedIndex == 0)
        #expect(abs(model.board.features[0].area.midX - 24) <= 0.5 && abs(model.board.features[0].area.midY - 24) <= 0.5)
        #expect(model.canUndo && !model.canRedo)
        model.undo()
        #expect(model.board.features.isEmpty && model.selection == nil && written.count == 2)
        #expect(model.canRedo)
        model.redo()
        #expect(model.board.features.count == 1)
        // Nothing to undo or redo: no write.
        let count = written.count
        model.redo()
        #expect(written.count == count)
    }

    @Test("A drag writes once at the end, and a drag that changes nothing leaves no undo step")
    func gestures() throws {
        var writes = 0
        let model = try model { _ in writes += 1 }
        model.add(try #require(model.palette.item("woods")))
        let id = try #require(model.selection)
        writes = 0
        model.beginGesture()
        model.place(id, x: 10, y: 10)
        model.place(id, x: 12, y: 12)
        #expect(writes == 0)
        model.endGesture()
        #expect(writes == 1 && model.hud == nil)
        #expect(model.board.features[0].area.x == 12)
        model.beginGesture()
        model.endGesture()
        // The empty drag left no step: undo goes back past the real drag, not to a no-op.
        model.undo()
        #expect(model.board.features[0].area.x != 12)
    }

    @Test("Nudge steps by the snap step, or one inch with snap off, and stays on the table")
    func nudge() throws {
        let model = try model()
        model.add(try #require(model.palette.item("woods")), centredAt: .init(x: 10, y: 10))
        let id = try #require(model.selection)
        model.snap = .half
        #expect(model.step == 0.5)
        model.snap = .off
        #expect(model.step == 1)
        let x = model.board.features[0].area.x
        model.nudge(id, dx: 1, dy: 0)
        #expect(model.board.features[0].area.x == x + 1)
        model.nudge(id, dx: -500, dy: 500)
        #expect(model.board.features[0].area.x == 0)
        #expect(model.board.features[0].area.maxY == 48)
    }

    @Test("Resizing clamps to the table, bigger and smaller move by one step, and a dragged resize shows a HUD")
    func resize() throws {
        let model = try model()
        model.add(try #require(model.palette.item("woods")))
        let id = try #require(model.selection)
        let w = model.board.features[0].area.width
        model.bigger(id)
        #expect(model.board.features[0].area.width == w + 1)
        model.smaller(id)
        model.smaller(id)
        #expect(model.board.features[0].area.width == w - 1)
        model.beginGesture()
        model.liveResize(id, width: 9, depth: 3)
        #expect(model.hud == "9 × 3″")
        model.liveResize(id, width: 500, depth: 0)
        #expect(model.board.features[0].area.width == 48 && model.board.features[0].area.depth == 0.5)
        model.endGesture()
        #expect(model.hud == nil)
    }

    @Test("Rotation snaps to 15° unless snap is off, and a full turn clears it")
    func rotation() throws {
        let model = try model()
        model.add(try #require(model.palette.item("woods")))
        let id = try #require(model.selection)
        model.setRotation(id, 100)
        #expect(model.board.features[0].rotation == 105 && model.hud == "105°")
        model.snap = .off
        model.setRotation(id, 100)
        #expect(model.board.features[0].rotation == 100)
        model.rotate(id, by: 260)
        #expect(model.board.features[0].rotation == nil)
        model.setRotation(UUID(), 10)
    }

    @Test("Position fields change one axis and clamp to the table")
    func position() throws {
        let model = try model()
        model.add(try #require(model.palette.item("woods")), centredAt: .init(x: 20, y: 20))
        let id = try #require(model.selection)
        let y = model.board.features[0].area.y
        model.setPosition(id, x: 1000)
        #expect(model.board.features[0].area.maxX == 48 && model.board.features[0].area.y == y)
        model.setPosition(id, y: -5)
        #expect(model.board.features[0].area.y == 0)
    }

    @Test("Duplicate selects the copy; delete clears the selection only when it was the deleted piece")
    func duplicateDelete() throws {
        let model = try model()
        model.add(try #require(model.palette.item("woods")))
        let first = try #require(model.selection)
        model.duplicate(first)
        let copy = try #require(model.selection)
        #expect(copy != first && model.board.features.count == 2)
        model.delete(first)
        #expect(model.selection == copy && model.board.features.count == 1)
        model.delete(copy)
        #expect(model.selection == nil && model.board.features.isEmpty)
    }

    @Test("Piece fields: name, level, class; a name or level change is undoable")
    func pieceFields() throws {
        let model = try model()
        model.add(try #require(model.palette.item("building-small")))
        let id = try #require(model.selection)
        model.setName(id, "Depot")
        model.setBuildingClass(id, .heavy)
        #expect(model.board.features[0].name == "Depot" && model.board.features[0].buildingClass == .heavy)
        #expect(model.paletteItem(model.board.features[0])?.kind == .building)
        model.undo()
        #expect(model.board.features[0].buildingClass != .heavy)
    }

    @Test("Zones follow the game's sides; depth changes write through and reset restores the rule")
    func zones() throws {
        let model = try model()
        #expect(model.sideCount == 2 && model.zones.count == 2 && model.zoneDepth == BoardZones.zoneDepth)
        model.setZoneDepth(10)
        #expect(model.zoneDepth == 10)
        model.resetZones()
        #expect(model.zoneDepth == BoardZones.zoneDepth)
        let four = try self.model(sides: SideId.allCases.map { MatchSide(id: $0) })
        #expect(four.sideCount == 4 && four.zones.count == 4)
    }

    @Test("A piece inside a zone is flagged by side; a piece out in the open is not")
    func warnings() throws {
        let model = try model()
        let woods = try #require(model.palette.item("woods"))
        model.add(woods, centredAt: .init(x: 24, y: 24))
        #expect(model.warnings.isEmpty)
        model.add(woods, centredAt: .init(x: 3, y: 24))
        let flagged = try #require(model.selection)
        #expect(model.warnings[flagged]?.contains("A") == true)
    }

    @Test("Measure shows the distance to the nearest half inch and clears")
    func measure() throws {
        let model = try model()
        #expect(model.measureText == nil)
        model.measureA = .init(x: 0, y: 0)
        model.measureB = .init(x: 3, y: 4)
        #expect(model.measureText == "5″")
        model.measureB = .init(x: 1, y: 1)
        #expect(model.measureText == "1.5″")
        model.clearMeasure()
        #expect(model.measureText == nil)
    }

    @Test("Linking to a saved board copies its name and identity into the working board")
    func link() throws {
        var last: BoardLayout?
        let model = try model { last = $0 }
        var stored = BoardLayout(width: 48, depth: 48)
        stored.name = "Ridge"
        model.linkToPreset(stored)
        #expect(model.board.name == "Ridge" && model.board.presetID == stored.id && model.board.presetUpdatedAt == stored.updatedAt)
        #expect(last?.name == "Ridge")
        #expect(model.counterText.hasSuffix("choices placed") && model.summary.hasPrefix("48 by 48 inch table."))
    }
}

// MARK: - Coordinator

@MainActor
@Suite("Play match coordinator")
struct PlayMatchCoordinatorTests {
    private func dependencies(repo: InMemoryMatchSessionRepository = InMemoryMatchSessionRepository()) throws -> AppDependencies {
        let deps = AppDependencies(
            content: BundleContentCatalogRepository(bundle: .main),
            matchSessions: repo,
            modelContainer: try PersistenceController.makeContainer(inMemory: true)
        )
        deps.preferences.reset()
        return deps
    }

    @Test("Starting a mission opens a store with the mission loaded and no error")
    func startMission() throws {
        let deps = try dependencies()
        let coordinator = PlayMatchCoordinator()
        coordinator.requestNew(.ridgeLine, using: deps)
        #expect(coordinator.matchStore?.session?.scenarioId == .ridgeLine && coordinator.lastError == nil)
        #expect(!coordinator.showReplaceConfirm)
        deps.preferences.reset()
    }

    @Test("The default dice mode is applied to a new mission")
    func diceDefault() throws {
        let deps = try dependencies()
        deps.preferences.defaultDiceMode = .auto
        let coordinator = PlayMatchCoordinator()
        coordinator.requestNew(.ridgeLine, using: deps)
        #expect(coordinator.matchStore?.session?.diceMode == .auto)
        deps.preferences.reset()
    }

    @Test("A game in progress asks before it is replaced, and confirming replaces it")
    func replace() throws {
        let repo = InMemoryMatchSessionRepository()
        let deps = try dependencies(repo: repo)
        let coordinator = PlayMatchCoordinator()
        coordinator.requestNew(.ridgeLine, using: deps)
        let first = try #require(coordinator.matchStore?.session?.id)
        coordinator.matchStore = nil

        coordinator.requestNew(.ridgeLine, title: "Ridge Line", using: deps)
        #expect(coordinator.showReplaceConfirm && coordinator.matchStore == nil)
        #expect(coordinator.resumeSession?.id == first)
        coordinator.confirmReplace(using: deps)
        let second = try #require(coordinator.matchStore?.session?.id)
        #expect(second != first)
        deps.preferences.reset()
    }

    @Test("Resume opens the saved game, and with none saved it clears the card")
    func resume() throws {
        let repo = InMemoryMatchSessionRepository()
        let deps = try dependencies(repo: repo)
        let coordinator = PlayMatchCoordinator()
        coordinator.resumeSession = MatchSession(ruleset: .ridgeLine)
        coordinator.resume(using: deps)
        #expect(coordinator.matchStore == nil && coordinator.resumeSession == nil)

        coordinator.requestNew(.ridgeLine, using: deps)
        let id = try #require(coordinator.matchStore?.session?.id)
        coordinator.matchStore = nil
        coordinator.resume(using: deps)
        #expect(coordinator.matchStore?.session?.id == id && coordinator.zoomSource == "resume")
        deps.preferences.reset()
    }

    @Test("Refresh finds the active game, and says once when a saved game could not be opened")
    func refresh() throws {
        let repo = InMemoryMatchSessionRepository()
        let deps = try dependencies(repo: repo)
        let coordinator = PlayMatchCoordinator()
        coordinator.refresh(using: deps)
        #expect(coordinator.resumeSession == nil && coordinator.unreadableNotice == nil)
        try repo.save(MatchSession(ruleset: .ridgeLine, status: .active, tableReady: true, forcesLoaded: true))
        coordinator.refresh(using: deps)
        #expect(coordinator.resumeSession != nil)
        deps.preferences.reset()
    }

    @Test("A Play game starts from its setup and is remembered as the last setup; the draft is cleared")
    func startPlay() throws {
        let deps = try dependencies()
        let library = deps.cardLibrary
        let picks = library.checkedFaces.prefix(2).compactMap(PlayUnits.pick)
        var setup = PlaySetup.pickup()
        setup.forces[.lanceA] = [picks[0]]
        setup.forces[.lanceB] = [picks[1]]
        deps.preferences.playDraft = setup
        let coordinator = PlayMatchCoordinator()
        coordinator.requestPlay(setup, using: deps)
        #expect(coordinator.matchStore?.session?.isPlayGame == true && coordinator.lastError == nil)
        #expect(deps.preferences.playDraft == nil && deps.preferences.playLastSetup != nil)
        #expect(coordinator.pendingPlay == nil && coordinator.zoomSource == "play" && !coordinator.prefersZoom)
        deps.preferences.reset()
    }

    @Test("A Play setup with no 'Mechs reports the store's error and opens nothing")
    func startPlayEmpty() throws {
        let deps = try dependencies()
        let coordinator = PlayMatchCoordinator()
        coordinator.requestPlay(PlaySetup.pickup(), using: deps)
        #expect(coordinator.matchStore == nil && coordinator.lastError == "Add at least one ’Mech to each side.")
        #expect(coordinator.lastErrorTitle == "Couldn’t start the game")
        deps.preferences.reset()
    }
}
