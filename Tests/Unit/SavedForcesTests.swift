import Foundation
import Testing
import SwiftData
import MechBuddyData
import MechBuddyDomain

@Suite("PM9 saved forces and hand-entered cards")
@MainActor
struct SavedForcesTests {
    // MARK: Migration

    @Test("A real V1 store file opens under SchemaV2 with its game intact")
    func migratesV1StoreOnDisk() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pm9-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("v1.store")

        // 1. Write a store with the V1 schema only, the way a TestFlight 1.0 build did.
        var saved = MatchSession(ruleset: .ridgeLine, status: .active, tableReady: true, forcesLoaded: true)
        saved.turn = 3
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let v1 = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let repo = SwiftDataMatchSessionRepository(container: v1)
            try repo.save(saved)
            #expect(try repo.loadActive(mode: .alphaStrike)?.id == saved.id)
        }

        // 2. Open the same file with the app's container (V2 + migration plan).
        let v2 = try PersistenceController.makeContainer(url: url)
        let repo = SwiftDataMatchSessionRepository(container: v2)
        let loaded = try #require(try repo.loadActive(mode: .alphaStrike))
        #expect(loaded.id == saved.id)
        #expect(loaded.turn == 3)

        // 3. The new tables work, and the old rows are still there next to them.
        let store = UserContentStore(container: v2)
        try store.save(SavedForce(name: "Strike lance", picks: [Self.pick()]))
        #expect(store.savedForces().count == 1)
        #expect(try ModelContext(v2).fetch(FetchDescriptor<SDMatchSession>()).count == 1)
    }

    @Test("Saved forces and cards survive closing and reopening a V2 store")
    func persistsAcrossOpens() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pm9-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("v2.store")
        let face = try #require(Self.draft().makeFace())
        do {
            let store = UserContentStore(container: try PersistenceController.makeContainer(url: url))
            try store.saveUserCard(face)
            try store.save(SavedForce(name: "A", picks: [Self.pick(cardId: face.id)], cards: [face]))
        }
        let store = UserContentStore(container: try PersistenceController.makeContainer(url: url))
        #expect(store.userCards() == [face])
        #expect(store.savedForces().first?.cards == [face])
    }

    // MARK: Saved forces

    @Test("Saving under an existing name replaces it; rename and delete work")
    func storeBasics() throws {
        let store = UserContentStore(container: try PersistenceController.makeContainer(inMemory: true))
        try store.save(SavedForce(name: "Lance", picks: [Self.pick()]))
        try store.save(SavedForce(name: " lance ", picks: [Self.pick(), Self.pick()]))
        let all = store.savedForces()
        #expect(all.count == 1)
        #expect(all[0].picks.count == 2)
        try store.rename(id: all[0].id, to: "Alpha", now: Date())
        #expect(store.savedForces().first?.name == "Alpha")
        try store.deleteSavedForce(id: all[0].id)
        #expect(store.savedForces().isEmpty)
    }

    @Test("Loading a saved force replaces the side, clamps skill, and skips picks with no card")
    func loadsIntoSide() throws {
        let face = try #require(Self.draft().makeFace())
        let library = CardLibrary(CardLibraryDTO(contentVersion: "t", cards: []), userCards: [face])
        var setup = PlaySetup.pickup()
        setup.allowImprovedSkills = false
        setup.forces[.lanceA] = [Self.pick(cardId: "old")]
        var gone = Self.pick(cardId: "not-in-library")
        gone.name = "Gone"
        var good = Self.pick(cardId: face.id)
        good.skill = 2
        good.controllerIndex = 1
        let force = SavedForce(name: "F", picks: [good, gone], cards: [face])

        let result = SavedForces.load(force, into: &setup, side: .lanceA, library: library)
        #expect(result == .init(added: 1, skipped: 1))
        let loaded = try #require(setup.force(.lanceA).first)
        #expect(setup.force(.lanceA).count == 1)
        #expect(loaded.skill == 4)
        #expect(loaded.controllerIndex == nil)
        #expect(loaded.id != good.id)
    }

    @Test("make() copies the picks and only the hand-entered cards they use")
    func makeCopiesUserCards() throws {
        let face = try #require(Self.draft().makeFace())
        let library = CardLibrary(CardLibraryDTO(contentVersion: "t", cards: []), userCards: [face])
        var setup = PlaySetup.pickup()
        setup.forces[.lanceA] = [Self.pick(cardId: face.id), Self.pick(cardId: face.id)]
        let force = SavedForces.make(name: "  Mine ", setup: setup, side: .lanceA, library: library)
        #expect(force.name == "Mine")
        #expect(force.picks.count == 2)
        #expect(force.cards == [face])
    }

    // MARK: Hand-entered cards

    @Test("A valid draft makes a checked user card that Play can use")
    func draftMakesPlayableCard() throws {
        let face = try #require(Self.draft().makeFace())
        #expect(face.isUserCard && face.isChecked)
        #expect(face.id.hasPrefix("user-"))
        #expect(face.mv == "6\"")
        #expect(face.chassis == "Raven")
        let library = CardLibrary(CardLibraryDTO(contentVersion: "t", cards: []), userCards: [face])
        var setup = PlaySetup.pickup()
        let pick = try #require(PlayUnits.pick(face))
        setup.forces[.lanceA] = [pick]
        let units = PlayUnits.make(setup: setup, library: library)
        #expect(units.count == 1)
        #expect(units[0].name == "Raven RVN-3L")
        #expect(units[0].pv == 28)
    }

    @Test("Move is normalised to the card's form and bad moves are refused")
    func moveParsing() {
        #expect(UserCardDraft.normalizedMove("6") == "6\"")
        #expect(UserCardDraft.normalizedMove("10\"j") == "10\"j")
        #expect(UserCardDraft.normalizedMove("10 / 6j") == "10\"/6\"j")
        #expect(UserCardDraft.normalizedMove("") == nil)
        #expect(UserCardDraft.normalizedMove("fast") == nil)
        #expect(UserCardDraft.normalizedMove("1/2/3") == nil)
        #expect(UserCardDraft.normalizedMove("-4") == nil)
    }

    @Test("Each field is validated; 0* means minimal damage")
    func validation() throws {
        var draft = UserCardDraft()
        #expect(Set(draft.issues().map(\.field)) == [.name, .pv, .move, .tmm, .short, .medium, .long, .armor, .structure])

        draft = Self.draft()
        #expect(draft.issues().isEmpty)
        draft.short = "0*"
        let face = try #require(draft.makeFace())
        #expect(face.s == 0 && face.minimalDamage.short && !face.minimalDamage.medium)
        // Round-trips through the stored JSON.
        let decoded = try JSONDecoder().decode(CardFaceDTO.self, from: JSONEncoder().encode(face))
        #expect(decoded == face)
        #expect(UserCardDraft(face: decoded).short == "0*")

        for (mutate, field) in [
            ({ (d: inout UserCardDraft) in d.pv = "0" }, UserCardDraft.Field.pv),
            ({ $0.pv = "12.5" }, .pv),
            ({ $0.size = 5 }, .size),
            ({ $0.tmm = "9" }, .tmm),
            ({ $0.medium = "31" }, .medium),
            ({ $0.long = "-1" }, .long),
            ({ $0.overheat = "5" }, .overheat),
            ({ $0.armor = "x" }, .armor),
            ({ $0.structure = "0" }, .structure),
            ({ $0.name = "   " }, .name)
        ] {
            var bad = Self.draft()
            mutate(&bad)
            #expect(bad.issues().map(\.field) == [field], "\(field)")
            #expect(bad.makeFace() == nil)
        }
    }

    // MARK: Fixtures

    private static func draft() -> UserCardDraft {
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
        d.specials = "ECM, EW"
        return d
    }

    private static func pick(cardId: String = "locust-lct-7v") -> ForcePick {
        ForcePick(cardId: cardId, name: "Test", basePV: 28, size: 1, skill: 4, isClan: false)
    }
}
