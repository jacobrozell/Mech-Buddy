// Behaviour and error-path tests for the Data and Persistence targets: content loading failures,
// DTO Codable shapes, Rules library filtering, the Play unit picker and the Play table copy.
import Foundation
import Testing
import SwiftData
import MechBuddyData
import MechBuddyDomain

private final class DataGapBundleToken {}

/// A bundle that is just a temporary folder of JSON files, so loading errors can be provoked.
private struct TempBundle {
    let dir: URL
    let bundle: Bundle

    init(files: [String: String]) throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, text) in files {
            try text.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        bundle = try #require(Bundle(path: dir.path))
    }

    func remove() { try? FileManager.default.removeItem(at: dir) }
}

@Suite("Content loading errors")
struct ContentLoadingErrorTests {
    @Test("A missing file is a missing-resource error naming the file")
    func missing() throws {
        let temp = try TempBundle(files: [:])
        defer { temp.remove() }
        let repo = BundleContentCatalogRepository(bundle: temp.bundle)
        #expect(throws: ContentLoadError.missingResource("as-getting-started")) { try repo.gettingStarted() }
    }

    @Test("Broken JSON is a decoding error that names the file")
    func broken() throws {
        let temp = try TempBundle(files: ["as-getting-started.json": "{ not json"])
        defer { temp.remove() }
        let repo = BundleContentCatalogRepository(bundle: temp.bundle)
        do {
            _ = try repo.gettingStarted()
            Issue.record("Expected a decoding error")
        } catch let ContentLoadError.decodingFailed(message) {
            #expect(message.contains("as-getting-started"))
        }
    }

    @Test("A file from a newer schema is refused, an up-to-date one loads")
    func schema() throws {
        let future = #"{"schemaVersion":2,"contentVersion":"x","items":[]}"#
        let current = #"{"schemaVersion":1,"contentVersion":"x","items":[{"id":"a","title":"A"}]}"#
        let newer = try TempBundle(files: ["as-getting-started.json": future])
        defer { newer.remove() }
        #expect(throws: ContentLoadError.unsupportedSchema(2)) {
            try BundleContentCatalogRepository(bundle: newer.bundle).gettingStarted()
        }
        let ok = try TempBundle(files: ["as-getting-started.json": current])
        defer { ok.remove() }
        let items = try BundleContentCatalogRepository(bundle: ok.bundle).gettingStarted().items
        #expect(items.map(\.id) == ["a"] && items[0].detail == nil)
    }

    @Test("Errors read in plain words")
    func descriptions() {
        let errors: [ContentLoadError] = [.missingResource("x"), .unsupportedSchema(3), .decodingFailed("why")]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test("A gated or unlisted mission can't be loaded")
    func gatedScenario() throws {
        let catalog = #"""
        {"schemaVersion":1,"contentVersion":"x","scenarios":[
          {"id":"ridge-line","title":"Ridge","gated":true,"bundle":"x.json"},
          {"id":"broken-ground","title":"Broken","gated":false}
        ]}
        """#
        let temp = try TempBundle(files: ["as-scenarios.json": catalog])
        defer { temp.remove() }
        let repo = BundleContentCatalogRepository(bundle: temp.bundle)
        #expect(throws: ContentLoadError.missingResource("ridge-line")) { try repo.scenario(id: .ridgeLine) }
        #expect(throws: ContentLoadError.missingResource("broken-ground")) { try repo.scenario(id: .brokenGround) }
        #expect(throws: ContentLoadError.missingResource("close-quarters")) { try repo.scenario(id: .closeQuarters) }
    }

    @Test("A mission file whose id doesn't match its catalog entry is refused")
    func scenarioIdMismatch() throws {
        let catalog = #"{"schemaVersion":1,"contentVersion":"x","scenarios":[{"id":"ridge-line","title":"R","gated":false,"bundle":"wrong.json"}]}"#
        let scenario = #"""
        {"schemaVersion":1,"contentVersion":"t","scenarioId":"close-quarters","title":"T","tableSteps":[],
         "ruleset":{"overheatAllowed":false,"physicalAttacksAllowed":false,"forcedWithdrawal":false,"victory":{"type":"destroyAllEnemies"}},
         "sides":{"lanceA":[],"lanceB":[]}}
        """#
        let temp = try TempBundle(files: ["as-scenarios.json": catalog, "wrong.json": scenario])
        defer { temp.remove() }
        do {
            _ = try BundleContentCatalogRepository(bundle: temp.bundle).scenario(id: .ridgeLine)
            Issue.record("Expected a mismatch error")
        } catch let ContentLoadError.decodingFailed(message) {
            #expect(message.contains("does not match"))
        }
    }

    @Test("Mission rules map the victory rule; an unknown or incomplete one falls back to last side standing")
    func mapRuleset() {
        func dto(_ type: String, maxTurn: Int?) -> ScenarioRulesetDTO {
            let victory = maxTurn.map { "{\"type\":\"\(type)\",\"maxTurn\":\($0)}" } ?? "{\"type\":\"\(type)\"}"
            let json = "{\"overheatAllowed\":true,\"physicalAttacksAllowed\":false,\"forcedWithdrawal\":true,\"maxTurns\":8,\"victory\":\(victory)}"
            return try! JSONDecoder().decode(ScenarioRulesetDTO.self, from: Data(json.utf8))
        }
        let timed = GuidedScenarioFactory.mapRuleset(dto("destroyAllEnemiesOrStructureAfterTurn", maxTurn: 6))
        #expect(timed.victory == .destroyAllEnemiesOrStructureAfterTurn(maxTurn: 6))
        #expect(timed.overheatAllowed && !timed.physicalAttacksAllowed && timed.forcedWithdrawal && timed.maxTurns == 8)
        #expect(GuidedScenarioFactory.mapRuleset(dto("destroyAllEnemiesOrStructureAfterTurn", maxTurn: nil)).victory == .destroyAllEnemies)
        #expect(GuidedScenarioFactory.mapRuleset(dto("somethingNew", maxTurn: 3)).victory == .destroyAllEnemies)
    }
}

@Suite("Card DTO Codable")
struct CardDTOCodableTests {
    @Test("A box card with minimal-damage bands writes them back as \"0*\" and reads them again")
    func roundTrip() throws {
        let json = #"{"name":"Locust","sz":1,"defaultSide":"lanceA","pv":10,"mv":"8\"","tmm":2,"s":"0*","m":1,"l":0,"ov":0,"armor":3,"structure":2,"skill":4,"abilities":"x"}"#
        let card = try JSONDecoder().decode(BoxCardDTO.self, from: Data(json.utf8))
        #expect(card.minimalDamage.short && !card.minimalDamage.medium && !card.minimalDamage.long)
        let out = try JSONEncoder().encode(card)
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(text.contains("\"s\":\"0*\""))
        #expect(text.contains("\"m\":1") && text.contains("\"l\":0"))
        let again = try JSONDecoder().decode(BoxCardDTO.self, from: out)
        #expect(again.minimalDamage == card.minimalDamage && again.name == "Locust" && again.pv == 10 && again.cardId == nil)
    }

    @Test("A damage value that is neither a number nor \"0*\" is a decoding error")
    func badDamage() {
        let json = #"{"name":"X","sz":1,"defaultSide":"lanceA","s":"lots"}"#
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(BoxCardDTO.self, from: Data(json.utf8)) }
    }

    @Test("A card with no stats decodes with nils and encodes without them")
    func sparse() throws {
        let card = try JSONDecoder().decode(BoxCardDTO.self, from: Data(#"{"name":"X","sz":2,"defaultSide":"lanceB"}"#.utf8))
        #expect(card.pv == nil && card.s == nil && !card.minimalDamage.short)
        let text = try #require(String(data: JSONEncoder().encode(card), encoding: .utf8))
        #expect(!text.contains("\"pv\"") && !text.contains("\"s\""))
    }
}

@Suite("Rules library")
struct RulesLibraryGapTests {
    private func topic(_ id: String, _ game: RulesGameTag?) -> RulesTopicDTO {
        RulesTopicDTO(id: id, title: id, game: game, sections: [RulesSectionDTO(heading: "h", body: "b")])
    }

    @Test("Game tags have identifier keys and badges, and know which game shows them")
    func tags() {
        #expect(RulesGameTag.allCases.map(\.identifierKey) == ["as", "classic", "both"])
        #expect(RulesGameTag.alphaStrike.badge == "Alpha Strike rules")
        #expect(RulesGameTag.classic.badge == "Classic BattleTech rules")
        #expect(RulesGameTag.both.badge == "Both games")
        #expect(RulesGameTag.both.appears(in: .alphaStrike) && RulesGameTag.both.appears(in: .classic))
        #expect(RulesGameTag.classic.appears(in: .classic) && !RulesGameTag.classic.appears(in: .alphaStrike))
        #expect(RulesGameTag(.classic) == .classic && RulesGameTag(.alphaStrike) == .alphaStrike)
    }

    @Test("Topics are filtered per game, untagged ones count as Alpha Strike, and order is pack order")
    func filtering() {
        let library = RulesLibrary(packs: [
            RulesTopicsDTO(schemaVersion: 1, contentVersion: "1", disclaimer: "AS only", topics: [topic("a1", .alphaStrike), topic("old", nil)]),
            RulesTopicsDTO(schemaVersion: 1, contentVersion: "1", disclaimer: "Classic only", topics: [topic("c1", .classic)]),
            RulesTopicsDTO(schemaVersion: 1, contentVersion: "1", disclaimer: nil, topics: [topic("b1", .both)])
        ])
        #expect(library.allTopics.map(\.id) == ["a1", "old", "c1", "b1"])
        #expect(library.topics(for: .alphaStrike).map(\.id) == ["a1", "old", "b1"])
        #expect(library.topics(for: .classic).map(\.id) == ["c1", "b1"])
        #expect(library.disclaimer(for: .alphaStrike) == "AS only")
        #expect(library.disclaimer(for: .classic) == "Classic only")
        #expect(RulesLibrary(packs: []).disclaimer(for: .classic) == nil)
    }

    @Test("The Rules tab opens on the last game viewed, then the onboarding game, then Alpha Strike")
    func initialGame() {
        #expect(RulesGameChoice.initial(lastViewed: .classic, onboarding: .alphaStrike) == .classic)
        #expect(RulesGameChoice.initial(lastViewed: nil, onboarding: .classic) == .classic)
        #expect(RulesGameChoice.initial(lastViewed: nil, onboarding: nil) == .alphaStrike)
        #expect(RulesGameChoice.shortTitle(.alphaStrike) == "Alpha Strike" && RulesGameChoice.shortTitle(.classic) == "Classic")
    }
}

@Suite("Play unit picker")
struct PlayPickerGapTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: DataGapBundleToken.self))
    }

    @Test("All cards are grouped by box in box order and boxes with no faces are left out")
    func allCards() throws {
        let boxes = try catalog.boxSets().boxes
        let library = CardLibrary(try catalog.cardLibrary())
        let groups = PlayPicker.allCards(boxes: boxes, library: library)
        #expect(!groups.isEmpty)
        #expect(groups.allSatisfy { !$0.faces.isEmpty })
        #expect(groups.map(\.box.id) == boxes.map(\.id).filter { !library.faces(box: $0).isEmpty })
        let empty = BoxSetDTO(id: "no-such-box", title: "None", subtitle: "", game: .alphaStrike, miniCount: 0, units: [], sourceURL: "", contentsConfirmed: false)
        #expect(PlayPicker.allCards(boxes: [empty], library: library).isEmpty)
    }

    @Test("Search matches name or chassis ignoring case and padding; Size and tech base filter first")
    func matches() throws {
        let faces = CardLibrary(try catalog.cardLibrary()).faces
        let face = try #require(faces.first)
        #expect(PlayPicker.matches(face, query: "", size: nil, techBase: nil))
        #expect(PlayPicker.matches(face, query: "  \(face.chassis.uppercased()) ", size: nil, techBase: nil))
        #expect(PlayPicker.matches(face, query: face.name.lowercased(), size: face.sz, techBase: face.techBase))
        #expect(!PlayPicker.matches(face, query: "zzzz-no-such-mech", size: nil, techBase: nil))
        #expect(!PlayPicker.matches(face, query: "", size: face.sz + 1, techBase: nil))
        let other: CardTechBase = face.techBase == .clan ? .innerSphere : .clan
        #expect(!PlayPicker.matches(face, query: "", size: nil, techBase: other))
    }

    @Test("Mini check needs a collection; with one it counts each side's picks")
    func miniCheck() throws {
        let boxes = try catalog.boxSets().boxes
        var setup = PlaySetup.pickup()
        setup.forces[.lanceA] = [ForcePick(cardId: "x", name: "Locust LCT-1V", basePV: 10, size: 1, skill: 4, isClan: false)]
        #expect(PlayPicker.miniCheck(setup: setup, collection: nil, boxes: boxes, standIns: [:]) == nil)
        let check = PlayPicker.miniCheck(setup: setup, collection: OwnedCollection(), boxes: boxes, standIns: [:])
        #expect(check != nil)
    }

    @Test("Minis left after picks: negative once the picks outnumber the minis")
    func left() {
        var setup = PlaySetup.pickup()
        let locust = ForcePick(cardId: "x", name: "Locust LCT-1V", basePV: 10, size: 1, skill: 4, isClan: false)
        setup.forces[.lanceA] = [locust, locust]
        setup.forces[.lanceB] = [locust]
        #expect(PlayPicker.left(of: "Locust", owned: 4, setup: setup) == 1)
        #expect(PlayPicker.left(of: "Locust", owned: 2, setup: setup) == -1)
        #expect(PlayPicker.left(of: "Atlas", owned: 1, setup: setup) == 1)
    }

    @Test("Owned chassis need a collection and appear once each, with their faces")
    func ownedChassis() throws {
        let boxes = try catalog.boxSets().boxes
        let library = CardLibrary(try catalog.cardLibrary())
        #expect(PlayPicker.ownedChassis(collection: nil, boxes: boxes, library: library).isEmpty)
        let box = try #require(boxes.first { !library.faces(box: $0.id).isEmpty })
        let owned = PlayPicker.ownedChassis(collection: OwnedCollection(boxes: [box.id: 1]), boxes: boxes, library: library)
        #expect(!owned.isEmpty)
        #expect(Set(owned.map(\.id)).count == owned.count)
        #expect(owned.allSatisfy { !$0.faces.isEmpty && $0.owned >= 1 })
    }
}

@Suite("Play table copy")
struct PlayLayoutCopyTests {
    @Test("Winning summary: last side standing, one objective, or one each, with a turn limit")
    func winning() {
        var setup = PlaySetup.pickup()
        #expect(PlayLayout.winningSummary(for: setup) == "Destroy every enemy ’Mech")
        setup.objectiveId = .raid
        let shared = PlayLayout.winningSummary(for: setup)
        #expect(shared.hasPrefix("Raid:") && shared.contains("points wins") && !shared.contains("At turn"))
        setup.turnLimit = 8
        #expect(PlayLayout.winningSummary(for: setup).contains("At turn 8, most points wins"))
        setup.setObjective(.raid, for: .lanceA)
        setup.setObjective(.breakthrough, for: .lanceB)
        let each = PlayLayout.winningSummary(for: setup)
        #expect(each.contains("own objective") && each.contains("Raid to") && each.contains("Breakthrough to"))
        #expect(each.contains("At turn 8"))
    }

    @Test("Table steps: objective set-up lines, and 'off the table' when 'Mechs enter on Turn 1")
    func steps() {
        var setup = PlaySetup.pickup()
        setup.objectiveId = .raid
        let withObjective = PlayLayout.tableSteps(for: setup)
        #expect(withObjective.contains { $0.hasPrefix("Objective (p. 7):") })
        setup.sideObjectives = [:]
        setup.setObjective(.raid, for: .lanceA)
        setup.setObjective(.holdTheFort, for: .lanceB)
        let perSide = PlayLayout.tableSteps(for: setup)
        #expect(perSide.contains { $0.contains("objective (p. 7):") })
        setup.rules.startOnTable = false
        #expect(PlayLayout.tableSteps(for: setup).last == "Leave the ’Mechs off the table. On Turn 1 they enter from their home edge")
        setup.rules.startOnTable = true
        #expect(PlayLayout.tableSteps(for: setup).last?.contains("within 6″ of their home edge") == true)
    }

    @Test("A built board replaces the free terrain checklist and counts its pieces")
    func boardSteps() {
        var setup = PlaySetup.pickup()
        var board = BoardLayout(width: 48, depth: 36, zones: BoardZones.generate(width: 48, depth: 36, sideCount: 2))
        board.name = "Hill"
        setup.battlefield.board = board
        let steps = PlayLayout.tableSteps(for: setup)
        #expect(steps[1].contains("0 terrain pieces"))
        #expect(!steps.contains { $0.contains("picks 8 pieces") })
    }
}

@Suite("Persistence housekeeping")
@MainActor
struct PersistenceHousekeepingTests {
    @Test("Delete all clears boards, saved forces and hand-entered cards but nothing else")
    func deleteAll() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let store = UserContentStore(container: container)
        _ = try store.saveBoard(BoardLayout(width: 48, depth: 48), name: "Table")
        try store.save(SavedForce(name: "Lance", picks: [ForcePick(cardId: "x", name: "X", basePV: 10, size: 1, skill: 4, isClan: false)]))
        let repo = SwiftDataMatchSessionRepository(container: container)
        let session = MatchSession(ruleset: .ridgeLine, status: .active, tableReady: true, forcesLoaded: true)
        try repo.save(session)
        #expect(store.savedForces().count == 1 && store.boardPresets().count == 1)

        store.deleteAll()
        #expect(store.savedForces().isEmpty && store.boardPresets().isEmpty && store.userCards().isEmpty)
        #expect(try repo.loadActive(mode: .alphaStrike)?.id == session.id)
    }

    @Test("The in-memory repository deletes one game, clears all, and reports nothing unreadable")
    func inMemoryRepository() throws {
        let repo = InMemoryMatchSessionRepository()
        let one = MatchSession(ruleset: .ridgeLine, status: .active, tableReady: true, forcesLoaded: true)
        let two = MatchSession(ruleset: .ridgeLine, status: .active, tableReady: true, forcesLoaded: true)
        try repo.save(one)
        try repo.save(two)
        #expect(repo.unreadableSessionIDs.isEmpty)
        try repo.delete(id: one.id)
        #expect(try repo.loadActive(mode: .alphaStrike)?.id == two.id)
        try repo.delete(id: UUID())
        try repo.deleteAll()
        #expect(try repo.loadActive(mode: .alphaStrike) == nil)
    }
}
