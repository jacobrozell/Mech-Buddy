import Foundation
import Testing
import SwiftData
import MechBuddyData
import MechBuddyDomain

// PM13: board presets, starter boards, fitting a bigger table, `.mechboard` files (PlayModeSpec § 9.10).

private final class PresetBundleToken {}

@MainActor
private func makeStore() throws -> UserContentStore {
    UserContentStore(container: try PersistenceController.makeContainer(inMemory: true))
}

private func sampleBoard(name: String = "Home table", pieces: Int = 3) -> BoardLayout {
    var board = BoardLayout(width: 48, depth: 48)
    for index in 0..<pieces {
        board.features.append(.init(kind: .woods, area: .init(x: 10 + Double(index) * 7, y: 20, width: 5, depth: 5)))
    }
    board.name = name
    return board.assigningIDs()
}

@Suite("PM13 board presets")
@MainActor
struct BoardPresetStoreTests {
    @Test("Save, list, rename, duplicate and delete")
    func lifecycle() throws {
        let store = try makeStore()
        let saved = try store.saveBoard(sampleBoard(), name: "  Home   table ")
        #expect(saved.name == "Home table")
        #expect(store.boardPresets().map(\.name) == ["Home table"])
        let id = try #require(saved.id)

        try store.renameBoard(id: id, to: "Garage")
        #expect(store.boardPreset(id: id)?.name == "Garage")

        let copy = try store.duplicateBoard(id: id)
        #expect(copy.name == "Garage copy")
        #expect(copy.id != id)
        let again = try store.duplicateBoard(id: id)
        #expect(again.name == "Garage copy 2")
        #expect(store.boardPresets().count == 3)
        #expect(store.boardPreset(id: try #require(copy.id))?.features.count == 3)

        try store.deleteBoard(id: id)
        #expect(store.boardPreset(id: id) == nil)
        #expect(store.boardPresets().count == 2)
    }

    @Test("Names: limit, empty refused, rename onto another board refused, same name on save replaces")
    func names() throws {
        let store = try makeStore()
        let long = String(repeating: "x", count: 60)
        let saved = try store.saveBoard(sampleBoard(), name: long)
        #expect(saved.name?.count == BoardPresets.nameLimit)
        #expect(throws: UserContentStore.BoardError.emptyName) { try store.saveBoard(sampleBoard(), name: "   ") }

        let a = try store.saveBoard(sampleBoard(name: "A"), name: "A")
        _ = try store.saveBoard(sampleBoard(name: "B"), name: "B")
        #expect(throws: UserContentStore.BoardError.nameInUse) { try store.renameBoard(id: try #require(a.id), to: "b") }

        var other = sampleBoard(pieces: 1)
        other.id = UUID()
        _ = try store.saveBoard(other, name: "B")
        #expect(store.boardPresets().filter { $0.name == "B" }.count == 1)
    }

    @Test("Boards survive closing and reopening a store, and a V1 store gets the new table")
    func persists() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pm13-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("v1.store")
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let v1 = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            try SwiftDataMatchSessionRepository(container: v1).save(MatchSession(ruleset: .ridgeLine, status: .active))
        }
        let id: UUID
        do {
            let store = UserContentStore(container: try PersistenceController.makeContainer(url: url))
            id = try #require(try store.saveBoard(sampleBoard(), name: "Kept").id)
        }
        let store = UserContentStore(container: try PersistenceController.makeContainer(url: url))
        let board = try #require(store.boardPreset(id: id))
        #expect(board.name == "Kept")
        #expect(board.features.count == 3)
        #expect(board.features.allSatisfy { $0.id != nil })
    }

    @Test("A game keeps its own board copy after the preset changes; the setup can ask for the new version")
    func gameKeepsItsCopy() throws {
        let store = try makeStore()
        let early = Date(timeIntervalSince1970: 1_000)
        let preset = try store.saveBoard(sampleBoard(pieces: 2), name: "Table", now: early)

        var setup = PlaySetup.pickup()
        setup.battlefield.board = BoardPresets.copyForSetup(preset)
        let copy = try #require(setup.battlefield.board)
        #expect(copy.presetID == preset.id)
        #expect(copy.id != preset.id)
        #expect(BoardPresets.newerVersion(of: copy, in: store.boardPresets()) == nil)

        // The preset is edited and saved again.
        var edited = preset
        edited.features.append(.init(id: UUID(), kind: .hill, area: .init(x: 1, y: 1, width: 5, depth: 5)))
        try store.saveBoard(edited, name: "Table", now: early.addingTimeInterval(60))

        #expect(setup.battlefield.board?.features.count == 2)
        let newer = try #require(BoardPresets.newerVersion(of: copy, in: store.boardPresets()))
        #expect(newer.features.count == 3)

        // The copy rides along in a saved setup, which still has its own board.
        let data = try JSONEncoder().encode(setup)
        let restored = try JSONDecoder().decode(PlaySetup.self, from: data)
        #expect(restored.battlefield.board?.features.count == 2)
        #expect(restored.battlefield.board?.presetID == preset.id)
        #expect(BoardPresets.newerVersion(of: try #require(restored.battlefield.board), in: store.boardPresets()) != nil)

        // Using the new version replaces the copy and the note goes away.
        setup.battlefield.board = BoardPresets.copyForSetup(newer)
        #expect(setup.battlefield.board?.features.count == 3)
        #expect(BoardPresets.newerVersion(of: try #require(setup.battlefield.board), in: store.boardPresets()) == nil)
    }

    @Test("A deleted preset leaves the setup's copy alone and says nothing")
    func deletedPreset() throws {
        let store = try makeStore()
        let preset = try store.saveBoard(sampleBoard(), name: "Gone")
        let copy = BoardPresets.copyForSetup(preset)
        try store.deleteBoard(id: try #require(preset.id))
        #expect(BoardPresets.newerVersion(of: copy, in: store.boardPresets()) == nil)
    }

    @Test("List text")
    func summaryText() {
        #expect(BoardPresets.summary(sampleBoard()) == "4′ × 4′ · 2–4 sides · 3 pieces")
        #expect(BoardPresets.tableText(BoardLayout(width: 36, depth: 22)) == "3′ × 22″")
        #expect(BoardPresets.duplicateName(of: "A", among: ["A", "A copy"]) == "A copy 2")
    }
}

@Suite("PM13 starter boards and fitting a table")
struct StarterBoardTests {
    private var content: BundleContentCatalogRepository { BundleContentCatalogRepository(bundle: Bundle(for: PresetBundleToken.self)) }

    @Test("Six mission boards and two open tables, read-only")
    func starters() throws {
        let open = try content.starterBoards()
        let all = StarterBoards.all(content: content, open: open)
        #expect(all.map(\.id) == [
            "starter.ridge-line", "starter.broken-ground", "starter.running-hot", "starter.close-quarters",
            "starter.full-lances", "starter.meet-and-greet", "starter.open-4-4-for-four", "starter.open-3-4"
        ])
        #expect(all.allSatisfy { $0.isStarter && $0.board.isStarter == true })
        let ridge = try #require(all.first)
        #expect(ridge.name == "Ridge Line")
        #expect(ridge.board.width == 36 && ridge.board.depth == 22)
        #expect(ridge.board.features.filter { $0.kind == .woods }.count == 3)
        let meet = try #require(all.first { $0.id == "starter.meet-and-greet" })
        #expect(meet.board.width == 48 && meet.board.depth == 36)
        let four = try #require(all.last { $0.name.hasPrefix("Open 4") })
        #expect(four.board.width == 48 && four.board.depth == 48 && four.board.features.isEmpty)
        #expect(four.board.zones(sideCount: 4).count == 4)
        let three = try #require(all.last)
        #expect(three.board.width == 48 && three.board.depth == 36)
    }

    @Test("Picking a starter gives a copy that isn't linked to a preset")
    func starterCopy() throws {
        let ridge = try #require(StarterBoards.all(content: content, open: []).first)
        let copy = BoardPresets.copyForSetup(ridge.board)
        #expect(copy.presetID == nil && copy.isStarter == nil)
        #expect(copy.features.allSatisfy { $0.id != nil })
    }

    @Test("Stretch keeps piece sizes and spreads centres; centre keeps positions in the middle; zones are redrawn")
    func fitting() {
        var board = BoardLayout(width: 36, depth: 24)
        board.features = [.init(kind: .woods, area: .init(x: 13, y: 9, width: 10, depth: 6))] // centre (18, 12)
        board.zones = BoardZones.generate(width: 36, depth: 24, sideCount: 2)

        let stretched = board.stretched(toWidth: 48, depth: 48)
        #expect(stretched.width == 48 && stretched.depth == 48)
        let s = stretched.features[0].area
        #expect(s.width == 10 && s.depth == 6)
        #expect(s.midX == 24 && s.midY == 24)
        #expect(stretched.zones.isEmpty)
        #expect(stretched.zones(sideCount: 2).first?.area.depth == 48)

        let centred = board.centred(onWidth: 48, depth: 48)
        let c = centred.features[0].area
        #expect(c.x == 25 && c.y == 21 && c.width == 10)
    }
}

@Suite("PM13 .mechboard files")
@MainActor
struct BoardFileTests {
    @Test("A board exports and imports as a new board, without ids or dates")
    func roundTrip() throws {
        var board = sampleBoard(pieces: 2)
        board.id = UUID()
        board.updatedAt = Date()
        board.features[0].name = "North wood"
        let data = try BoardFile.export(board)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("updatedAt") && !text.contains("presetID"))
        #expect(BoardFile.fileName(for: board) == "Home table.mechboard")

        let imported = try BoardFile.importBoard(from: data, existingNames: [])
        #expect(imported.board.name == "Home table")
        #expect(imported.board.id != board.id)
        #expect(imported.board.features.count == 2)
        #expect(imported.board.features[0].name == "North wood")
        #expect(imported.notice == nil)
    }

    @Test("Import never overwrites a saved board; a taken name gets a number")
    func neverOverwrites() throws {
        let store = try makeStore()
        let mine = try store.saveBoard(sampleBoard(pieces: 1), name: "Shared")
        let data = try BoardFile.export(sampleBoard(name: "Shared", pieces: 4))
        let imported = try BoardFile.importBoard(from: data, existingNames: store.boardPresets().compactMap(\.name))
        #expect(imported.board.name == "Shared 2")
        try store.saveBoard(imported.board, name: imported.board.name ?? "")
        #expect(store.boardPresets().count == 2)
        #expect(store.boardPreset(id: try #require(mine.id))?.features.count == 1)
    }

    @Test("Malformed, oversized, newer and bloated files are refused")
    func refusals() throws {
        func refused(_ data: Data, _ expected: BoardFile.ImportError) {
            #expect(throws: expected) { try BoardFile.importBoard(from: data, existingNames: []) }
        }
        refused(Data("not json".utf8), .notABoard)
        refused(Data(#"{"hello":1}"#.utf8), .notABoard)
        refused(Data(#"{"width":-4,"depth":48}"#.utf8), .notABoard)
        refused(Data(repeating: 32, count: BoardFile.maxBytes + 1), .tooLarge)
        refused(Data(#"{"schemaVersion":99,"width":48,"depth":48}"#.utf8), .newerVersion)
        let pieces = (0..<(BoardFile.maxPieces + 1)).map { _ in #"{"kind":"woods","area":{"x":1,"y":1,"width":2,"depth":2}}"# }
        refused(Data(#"{"width":48,"depth":48,"features":[\#(pieces.joined(separator: ","))]}"#.utf8), .tooManyPieces)
        #expect(BoardFile.ImportError.notABoard.message.isEmpty == false)
    }

    @Test("Unknown piece kinds are dropped with a notice, and sizes are clamped")
    func softFailures() throws {
        let json = #"""
        {"width":500,"depth":48,"name":"Odd one","features":[
          {"kind":"woods","area":{"x":1,"y":1,"width":5,"depth":5}},
          {"kind":"lava","area":{"x":1,"y":1,"width":5,"depth":5}},
          {"kind":"hill","area":{"x":40,"y":40,"width":300,"depth":5}}]}
        """#
        let imported = try BoardFile.importBoard(from: Data(json.utf8), existingNames: [])
        #expect(imported.board.features.count == 2)
        #expect(imported.droppedPieces == 1)
        #expect(imported.board.width == 96)
        #expect(imported.wasClamped)
        #expect(imported.board.features.allSatisfy { $0.area.maxX <= 96 })
        #expect(imported.notice?.contains("left out") == true)
    }
}
